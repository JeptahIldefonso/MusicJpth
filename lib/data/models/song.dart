import 'package:flutter/foundation.dart';

/// One song row as the library UI shows it.
///
/// A read model, not the full table: it carries what a list row needs plus
/// `path`, which playback will use later (`PROJECT.md` §09). Artist and album
/// arrive resolved by the query's joins; an untagged song has `null` for them,
/// and the "Unknown" wording stays the UI's decision.
@immutable
class Song {
  const Song({
    required this.id,
    required this.path,
    required this.title,
    required this.isAvailable,
    this.artistName,
    this.albumTitle,
    this.durationMs,
    this.trackNumber,
    this.playedAtMs,
    this.artworkPath,
  });

  factory Song.fromRow(Map<String, Object?> row) => Song(
    id: row['id']! as int,
    path: row['path']! as String,
    title: row['title']! as String,
    isAvailable: (row['is_available'] as int? ?? 1) != 0,
    artistName: row['artist_name'] as String?,
    albumTitle: row['album_title'] as String?,
    durationMs: row['duration'] as int?,
    trackNumber: row['track_number'] as int?,
    playedAtMs: row['played_at'] as int?,
    artworkPath: row['artwork_path'] as String?,
  );

  final int id;
  final String path;
  final String title;

  /// Whether the file was on disk at the last completed scan. A `false` row is
  /// shown but marked, never hidden — nothing is deleted.
  final bool isAvailable;
  final String? artistName;
  final String? albumTitle;
  final int? durationMs;
  final int? trackNumber;

  /// Epoch ms of the last play — present only on history rows.
  final int? playedAtMs;

  /// Content-addressed cover in the artwork cache, when extracted.
  final String? artworkPath;

  @override
  bool operator ==(Object other) =>
      other is Song &&
      other.id == id &&
      other.path == path &&
      other.title == title &&
      other.isAvailable == isAvailable &&
      other.artistName == artistName &&
      other.albumTitle == albumTitle &&
      other.durationMs == durationMs &&
      other.trackNumber == trackNumber &&
      other.playedAtMs == playedAtMs &&
      other.artworkPath == artworkPath;

  @override
  int get hashCode => Object.hash(
    id,
    path,
    title,
    isAvailable,
    artistName,
    albumTitle,
    durationMs,
    trackNumber,
    playedAtMs,
    artworkPath,
  );
}
