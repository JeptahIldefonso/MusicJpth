import 'dart:io'
    show
        Directory,
        File,
        FileStat,
        FileSystemEntity,
        FileSystemEntityType,
        FileSystemException;
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../core/utils/music_paths.dart';
import '../../data/models/discovered_file.dart';
import 'audio_formats.dart';

/// Runs a discovery request. Overridden in tests so no isolate is spawned.
typedef DiscoveryRunner = Stream<List<DiscoveredFile>> Function(
  DiscoveryRequest request,
);

/// What a discovery pass needs. Values only, so it can cross an isolate port.
@immutable
class DiscoveryRequest {
  const DiscoveryRequest({
    required this.roots,
    this.chunkSize = defaultChunkSize,
  });

  /// Batch size for results.
  ///
  /// Large enough that a 10,000-file library costs ~40 database transactions
  /// and ~40 UI rebuilds instead of 10,000 of each; small enough that progress
  /// still moves and an interrupted scan loses little (`PROJECT.md` §09, §30).
  static const int defaultChunkSize = 256;

  /// Folder roots to walk, normalised. Overlapping roots are safe: a file is
  /// reported once.
  final List<String> roots;

  final int chunkSize;
}

/// Walks [request]'s roots and yields batches of supported audio files.
///
/// Deliberately synchronous: it is meant to run inside a spawned isolate, where
/// blocking is free, and `listSync`/`statSync` avoid the per-entry Future that
/// dominates the cost of walking thousands of files. Never call this on the UI
/// isolate — use [FileDiscoveryService].
///
/// An unreadable or vanished folder is skipped, not fatal: a single bad entry
/// must not end the scan (`PROJECT.md` §29).
Iterable<List<DiscoveredFile>> discoverAudioFilesSync(
  DiscoveryRequest request,
) sync* {
  final Set<String> seen = <String>{};
  List<DiscoveredFile> chunk = <DiscoveredFile>[];

  for (final String root in request.roots) {
    // Explicit stack rather than `listSync(recursive: true)`: recursive listing
    // aborts the whole walk on the first unreadable subfolder.
    final List<Directory> pending = <Directory>[Directory(root)];

    while (pending.isNotEmpty) {
      final List<FileSystemEntity> entries;
      try {
        entries = pending.removeLast().listSync(followLinks: false);
      } on FileSystemException {
        continue;
      }

      for (final FileSystemEntity entry in entries) {
        if (entry is Directory) {
          pending.add(entry);
          continue;
        }
        if (entry is! File) continue;

        final String? format = AudioFormats.extensionOf(entry.path);
        if (format == null || !AudioFormats.supported.contains(format)) {
          continue;
        }

        final String path = MusicPaths.normalise(entry.path);
        if (!seen.add(MusicPaths.key(path))) continue;

        final FileStat stat;
        try {
          stat = entry.statSync();
        } on FileSystemException {
          continue;
        }
        if (stat.type == FileSystemEntityType.notFound) continue;

        chunk.add(
          DiscoveredFile(
            path: path,
            format: format,
            size: stat.size,
            modifiedMs: stat.modified.millisecondsSinceEpoch,
          ),
        );

        if (chunk.length >= request.chunkSize) {
          yield chunk;
          chunk = <DiscoveredFile>[];
        }
      }
    }
  }

  if (chunk.isNotEmpty) yield chunk;
}

/// Discovers audio files without occupying the UI isolate.
///
/// The walk runs in a spawned isolate and streams batches back, so the UI keeps
/// rendering while a large library is indexed (`PROJECT.md` §09). Cancelling the
/// subscription kills the isolate — that is the scanner's cancel.
class FileDiscoveryService {
  const FileDiscoveryService({DiscoveryRunner? runnerOverride})
    : _runner = runnerOverride;

  final DiscoveryRunner? _runner;

  Stream<List<DiscoveredFile>> discover(DiscoveryRequest request) =>
      (_runner ?? _runInIsolate)(request);

  static Stream<List<DiscoveredFile>> _runInIsolate(
    DiscoveryRequest request,
  ) async* {
    final ReceivePort port = ReceivePort();
    final Isolate isolate = await Isolate.spawn<_DiscoveryHandshake>(
      _discoverInIsolate,
      _DiscoveryHandshake(port.sendPort, request),
      // Both are reported on the same port, so ordering with the batches holds.
      onExit: port.sendPort,
      onError: port.sendPort,
      debugName: 'music-oasis-discovery',
    );

    try {
      await for (final Object? message in port) {
        if (message == null) return; // onExit: the walk finished.
        if (message is List<DiscoveredFile>) {
          yield message;
          continue;
        }
        if (message is List<Object?>) {
          // onError: [error, stackTrace], both already strings.
          throw FileDiscoveryException(message.first?.toString() ?? 'unknown');
        }
      }
    } finally {
      // Also the cancellation path: the consumer stopped listening.
      isolate.kill(priority: Isolate.immediate);
      port.close();
    }
  }
}

/// The walk itself failed — not a single unreadable file, which is skipped.
class FileDiscoveryException implements Exception {
  const FileDiscoveryException(this.message);

  final String message;

  @override
  String toString() => 'FileDiscoveryException: $message';
}

@immutable
class _DiscoveryHandshake {
  const _DiscoveryHandshake(this.sender, this.request);

  final SendPort sender;
  final DiscoveryRequest request;
}

/// Isolate entry point: must be top-level.
void _discoverInIsolate(_DiscoveryHandshake handshake) {
  for (final List<DiscoveredFile> chunk in discoverAudioFilesSync(
    handshake.request,
  )) {
    handshake.sender.send(chunk);
  }
}
