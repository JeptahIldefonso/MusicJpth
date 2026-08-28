import 'package:flutter/foundation.dart';

/// One audio file the scanner found on disk, described by what a directory
/// listing already knows: no file is opened during discovery.
///
/// [size] and [modifiedMs] are the incremental-scan identity from
/// `PROJECT.md` §08 — cheap to read, enough to tell "changed" from "unchanged"
/// without hashing the file.
@immutable
class DiscoveredFile {
  const DiscoveredFile({
    required this.path,
    required this.format,
    required this.size,
    required this.modifiedMs,
  });

  /// Normalised absolute path — the stable identity of a song.
  final String path;

  /// Lower-case extension without the dot, e.g. `mp3`.
  final String format;

  final int size;

  /// Last-modified time, epoch milliseconds.
  final int modifiedMs;

  @override
  bool operator ==(Object other) =>
      other is DiscoveredFile &&
      other.path == path &&
      other.format == format &&
      other.size == size &&
      other.modifiedMs == modifiedMs;

  @override
  int get hashCode => Object.hash(path, format, size, modifiedMs);

  @override
  String toString() => 'DiscoveredFile($path, $size bytes)';
}
