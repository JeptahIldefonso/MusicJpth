import 'package:sqflite/sqflite.dart' show ConflictAlgorithm, Database;

import '../database/tables/albums_table.dart';
import '../database/tables/artists_table.dart';
import '../database/tables/favorites_table.dart';
import '../database/tables/songs_table.dart';
import '../models/song.dart';

/// Reads and writes the `favorites` table.
///
/// One row per song at most ([FavoritesTable] keys on song id), so a toggle
/// is one insert or one delete — no read-modify-write races. Rows reference
/// songs and cascade on deletion; availability never affects favouriting,
/// which is metadata about the user's intent, not the file's presence.
class FavoritesRepository {
  const FavoritesRepository(this._db);

  final Database _db;

  /// Every favourited song id, for UI state in one query.
  Future<Set<int>> ids() async {
    final List<Map<String, Object?>> rows = await _db.query(
      FavoritesTable.name,
      columns: <String>[FavoritesTable.songId],
    );
    return rows
        .map((Map<String, Object?> row) => row[FavoritesTable.songId]! as int)
        .toSet();
  }

  Future<bool> isFavorite(int songId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      FavoritesTable.name,
      columns: <String>[FavoritesTable.songId],
      where: '${FavoritesTable.songId} = ?',
      whereArgs: <Object?>[songId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Applies the user's intent; returns the resulting state.
  Future<bool> setFavorite(int songId, {required bool favorite}) async {
    if (favorite) {
      await _db.insert(FavoritesTable.name, <String, Object?>{
        FavoritesTable.songId: songId,
        FavoritesTable.dateAdded: DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await _db.delete(
        FavoritesTable.name,
        where: '${FavoritesTable.songId} = ?',
        whereArgs: <Object?>[songId],
      );
    }
    return favorite;
  }

  /// Toggles; returns the new state.
  Future<bool> toggle(int songId) => isFavorite(songId)
      .then<bool>((bool favorite) => setFavorite(songId, favorite: !favorite));

  /// One page of favourites, newest first, resolved like library rows.
  Future<List<Song>> page({int limit = 200, int offset = 0}) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT s.${SongsTable.id}, s.${SongsTable.path}, s.${SongsTable.title}, '
      's.${SongsTable.duration}, s.${SongsTable.trackNumber}, '
      's.${SongsTable.artworkPath}, '
      's.${SongsTable.isAvailable}, '
      'a.${ArtistsTable.artistName} AS artist_name, '
      'al.${AlbumsTable.title} AS album_title '
      'FROM ${FavoritesTable.name} AS f '
      'JOIN ${SongsTable.name} AS s ON s.${SongsTable.id} = f.${FavoritesTable.songId} '
      'LEFT JOIN ${ArtistsTable.name} AS a ON a.${ArtistsTable.id} = s.${SongsTable.artistId} '
      'LEFT JOIN ${AlbumsTable.name} AS al ON al.${AlbumsTable.id} = s.${SongsTable.albumId} '
      'ORDER BY f.${FavoritesTable.dateAdded} DESC, s.${SongsTable.id} DESC '
      'LIMIT ? OFFSET ?',
      <Object?>[limit, offset],
    );
    return rows.map(Song.fromRow).toList(growable: false);
  }
}
