import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart'
    show ConflictAlgorithm, Database, Transaction;

import '../../core/utils/music_paths.dart';
import '../database/tables/music_folders_table.dart';
import '../models/music_folder.dart';

/// Result of [MusicFolderRepository.add].
///
/// A duplicate is not an error: the user re-picked a folder Music Oasis already
/// watches, so the UI reports it rather than failing.
@immutable
class AddFolderResult {
  const AddFolderResult.added(this.folder) : isDuplicate = false;

  const AddFolderResult.duplicate(this.folder) : isDuplicate = true;

  /// The stored folder — newly inserted, or the existing one that covers it.
  final MusicFolder folder;

  final bool isDuplicate;
}

/// Reads and writes the `music_folders` table.
///
/// The only place folder paths enter the database, so it is also the only place
/// that normalises them. Owns no picker and no permission logic.
class MusicFolderRepository {
  const MusicFolderRepository(this._db);

  final Database _db;

  /// Every watched folder, ordered by path so the UI list is stable.
  Future<List<MusicFolder>> list() async {
    final List<Map<String, Object?>> rows = await _db.query(
      MusicFoldersTable.name,
      orderBy: '${MusicFoldersTable.path} COLLATE NOCASE ASC',
    );
    return rows.map(MusicFolder.fromRow).toList(growable: false);
  }

  /// The watched folder that already covers [path] — the same folder, or an
  /// ancestor of it — or `null` when [path] is new.
  ///
  /// Comparison happens in Dart rather than SQL because it must follow platform
  /// path semantics (case-insensitive on Windows) and honour nesting. The table
  /// holds a handful of rows, so reading them is cheaper than it looks.
  Future<MusicFolder?> coveringFolder(String path) async {
    final String candidate = normalisePath(path);
    for (final MusicFolder folder in await list()) {
      if (p.equals(folder.path, candidate) ||
          p.isWithin(folder.path, candidate)) {
        return folder;
      }
    }
    return null;
  }

  /// Adds [path], or reports the folder that already covers it.
  ///
  /// The check and the insert share one transaction, and the table's unique
  /// index on `path` is the final guard, so two rapid picks cannot both land.
  Future<AddFolderResult> add(String path) async {
    final String normalised = normalisePath(path);
    final int addedAt = DateTime.now().millisecondsSinceEpoch;

    return _db.transaction<AddFolderResult>((Transaction txn) async {
      final List<Map<String, Object?>> rows = await txn.query(
        MusicFoldersTable.name,
      );
      for (final Map<String, Object?> row in rows) {
        final MusicFolder folder = MusicFolder.fromRow(row);
        if (p.equals(folder.path, normalised) ||
            p.isWithin(folder.path, normalised)) {
          return AddFolderResult.duplicate(folder);
        }
      }

      final int id = await txn.insert(MusicFoldersTable.name, <String, Object?>{
        MusicFoldersTable.path: normalised,
        MusicFoldersTable.dateAdded: addedAt,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
      return AddFolderResult.added(
        MusicFolder(
          id: id,
          path: normalised,
          dateAdded: DateTime.fromMillisecondsSinceEpoch(addedAt),
        ),
      );
    });
  }

  /// Stops watching a folder. The user's files are never touched.
  Future<void> remove(int id) async {
    await _db.delete(
      MusicFoldersTable.name,
      where: '${MusicFoldersTable.id} = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Records that a scan finished for this folder, so a later scan can tell how
  /// stale the folder is (`REQUIREMENTS.md` §05).
  Future<void> markScanned(int id, DateTime at) async {
    await _db.update(
      MusicFoldersTable.name,
      <String, Object?>{
        MusicFoldersTable.lastScanned: at.millisecondsSinceEpoch,
      },
      where: '${MusicFoldersTable.id} = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Stored form of a picked path: no trailing separator, no `.`/`..` segments,
  /// platform separators. Keeps one folder from being stored twice under two
  /// spellings.
  @visibleForTesting
  static String normalisePath(String path) => MusicPaths.normalise(path);
}
