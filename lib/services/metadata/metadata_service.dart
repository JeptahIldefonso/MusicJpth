import 'dart:io' show File;
import 'dart:isolate' show Isolate;

import 'package:audio_metadata_reader/audio_metadata_reader.dart'
    show AudioMetadata, readMetadata;

import '../../data/models/track_metadata.dart';

/// Reads tags for a batch of paths. Overridden in tests so no isolate is
/// spawned and no real audio file is needed.
typedef MetadataRunner = Future<List<TrackMetadata>> Function(
  List<String> paths,
);

/// Reads tags for [paths] and returns one result per path, in order.
///
/// Deliberately synchronous: it is meant to run inside an isolate, where
/// blocking is free and the parser's own `openSync`/`readSync` calls cost no
/// event-loop latency. Never call this on the UI isolate — use
/// [MetadataService].
///
/// A file that cannot be parsed yields [TrackMetadata.unknown] instead of
/// throwing: `PROJECT.md` §29 requires one unreadable file out of a thousand to
/// leave the other 999 indexed.
List<TrackMetadata> readTrackMetadataSync(List<String> paths) {
  final List<TrackMetadata> results = <TrackMetadata>[];
  for (final String path in paths) {
    results.add(_readOne(path));
  }
  return results;
}

TrackMetadata _readOne(String path) {
  try {
    // `getImage: true` — this is the artwork-cache step. Reading the embedded
    // picture's *bytes* here costs a copy inside the isolate; decoding never
    // happens in the pipeline, and only files whose tags changed are re-read
    // at all (`REQUIREMENTS.md` §31).
    final AudioMetadata tags = readMetadata(File(path), getImage: true);
    return TrackMetadata(
      path: path,
      title: _text(tags.title),
      artist: _text(tags.artist),
      album: _text(tags.album),
      genre: _firstText(tags.genres),
      year: _positive(tags.year?.year),
      trackNumber: _positive(tags.trackNumber),
      discNumber: _positive(tags.discNumber),
      durationMs: _positive(tags.duration?.inMilliseconds),
      coverBytes: tags.pictures.isEmpty ? null : tags.pictures.first.bytes,
    );
    // Anything at all: a corrupt frame, a container with no parser, a truncated
    // file, a permission failure on open. Every one of them is "no tags", not a
    // failed scan.
  } on Object {
    return TrackMetadata.unknown(path);
  }
}

/// Trimmed, or `null` when the tag is absent or blank — a blank title must fall
/// back to the filename rather than render as an empty row.
String? _text(String? value) {
  if (value == null) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _firstText(List<String> values) {
  for (final String value in values) {
    final String? text = _text(value);
    if (text != null) return text;
  }
  return null;
}

/// `null` for absent and for the zeroes parsers emit as "unset" — a year of 0 or
/// track number 0 is missing data, not data.
int? _positive(int? value) => (value == null || value <= 0) ? null : value;

/// Reads tags without occupying the UI isolate.
///
/// Tag parsing is the CPU-heavy half of a scan, so each batch is parsed in a
/// short-lived isolate via [Isolate.run] (`PROJECT.md` §06: isolate processing
/// where appropriate). One isolate per batch, not per file — spawning is not
/// free, and a batch is already the scanner's unit of work.
class MetadataService {
  const MetadataService({MetadataRunner? runnerOverride})
    : _runner = runnerOverride;

  final MetadataRunner? _runner;

  /// Tags for [paths], one result per path, in order.
  ///
  /// Returns immediately for an empty batch, so no isolate is spawned for
  /// nothing.
  Future<List<TrackMetadata>> read(List<String> paths) async {
    if (paths.isEmpty) return const <TrackMetadata>[];
    return (_runner ?? _runInIsolate)(paths);
  }

  static Future<List<TrackMetadata>> _runInIsolate(List<String> paths) =>
      Isolate.run<List<TrackMetadata>>(
        () => readTrackMetadataSync(paths),
        debugName: 'music-oasis-metadata',
      );
}
