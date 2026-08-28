import 'package:flutter/foundation.dart';

import '../database/tables/music_folders_table.dart';

/// A folder the user chose for Music Oasis to index.
///
/// The folder is read-only to the app: it is a place to look for music, never
/// a place the app writes to (`REQUIREMENTS.md` §18).
@immutable
class MusicFolder {
  const MusicFolder({
    required this.id,
    required this.path,
    required this.dateAdded,
    this.lastScanned,
  });

  /// Reads a row from [MusicFoldersTable].
  factory MusicFolder.fromRow(Map<String, Object?> row) {
    final int? lastScanned = row[MusicFoldersTable.lastScanned] as int?;
    return MusicFolder(
      id: row[MusicFoldersTable.id]! as int,
      path: row[MusicFoldersTable.path]! as String,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(
        row[MusicFoldersTable.dateAdded]! as int,
      ),
      lastScanned: lastScanned == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastScanned),
    );
  }

  final int id;

  /// Absolute, normalised filesystem path.
  final String path;

  final DateTime dateAdded;

  /// When a scan last completed for this folder; `null` until first scanned.
  final DateTime? lastScanned;

  @override
  bool operator ==(Object other) =>
      other is MusicFolder &&
      other.id == id &&
      other.path == path &&
      other.dateAdded == dateAdded &&
      other.lastScanned == lastScanned;

  @override
  int get hashCode => Object.hash(id, path, dateAdded, lastScanned);

  @override
  String toString() => 'MusicFolder(id: $id, path: $path)';
}
