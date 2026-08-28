import 'package:flutter/foundation.dart';

/// Tags read from one audio file, normalised for the `songs` table.
///
/// Every field except [path] is nullable on purpose: `REQUIREMENTS.md` §16 and
/// `PROJECT.md` §10 both require the app to work with incomplete or corrupt
/// tags, so "absent" is a first-class value here rather than an error. A file
/// whose tags could not be read at all comes back as [TrackMetadata.unknown] —
/// still a result, never an exception that ends the scan.
///
/// Values only, so a batch can cross an isolate port.
@immutable
class TrackMetadata {
  const TrackMetadata({
    required this.path,
    this.title,
    this.artist,
    this.album,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.durationMs,
    this.coverBytes,
  });

  /// Nothing could be read for [path] — unreadable, corrupt, or a container the
  /// parser does not know. The song still gets indexed, with its filename.
  const TrackMetadata.unknown(this.path)
    : title = null,
      artist = null,
      album = null,
      genre = null,
      year = null,
      trackNumber = null,
      discNumber = null,
      durationMs = null,
      coverBytes = null;

  /// Normalised absolute path — matches [DiscoveredFile.path], the identity the
  /// repository writes against.
  final String path;

  /// Trimmed and non-empty, or `null`. A blank tag is treated as absent so the
  /// filename fallback wins instead of an empty title reaching the UI.
  final String? title;
  final String? artist;
  final String? album;
  final String? genre;

  /// Release year, always positive. Parsers report `0` for "no year"; that is
  /// normalised away here.
  final int? year;

  /// Always positive. `0` means "not numbered", which is not a track number.
  final int? trackNumber;
  final int? discNumber;

  /// Track length in milliseconds, always positive.
  final int? durationMs;

  /// Raw embedded cover bytes, when the file carries one. Values only, so a
  /// batch can cross an isolate port; hashing and storage happen in the
  /// artwork cache, never here.
  final Uint8List? coverBytes;

  /// Whether any tag was recovered. `false` for [TrackMetadata.unknown] and for
  /// a file whose tags were all blank.
  bool get hasTags =>
      title != null ||
      artist != null ||
      album != null ||
      genre != null ||
      year != null ||
      trackNumber != null ||
      discNumber != null ||
      durationMs != null;

  @override
  bool operator ==(Object other) =>
      other is TrackMetadata &&
      other.path == path &&
      other.title == title &&
      other.artist == artist &&
      other.album == album &&
      other.genre == genre &&
      other.year == year &&
      other.trackNumber == trackNumber &&
      other.discNumber == discNumber &&
      other.durationMs == durationMs;

  @override
  int get hashCode => Object.hash(
    path,
    title,
    artist,
    album,
    genre,
    year,
    trackNumber,
    discNumber,
    durationMs,
  );

  @override
  String toString() =>
      'TrackMetadata($path, title: $title, artist: $artist, album: $album)';
}
