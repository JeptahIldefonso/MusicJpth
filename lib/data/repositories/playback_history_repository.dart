import 'package:sqflite/sqflite.dart' show Database;

import '../database/tables/albums_table.dart';
import '../database/tables/artists_table.dart';
import '../database/tables/playback_history_table.dart';
import '../database/tables/songs_table.dart';
import '../models/song.dart';

/// Reads and writes `playback_history`: one row per qualifying play.
///
/// Writes are append-only; reads resolve the song join so history renders
/// exactly like library rows. Availability never affects history — a missing
/// file keeps its past (`REQUIREMENTS.md`: preserve records).
class PlaybackHistoryRepository {
  const PlaybackHistoryRepository(this._db);

  final Database _db;

  /// Records one play of [songId] at the current time.
  Future<void> add(int songId) async {
    await _db.insert(PlaybackHistoryTable.name, <String, Object?>{
      PlaybackHistoryTable.songId: songId,
      PlaybackHistoryTable.playedAt: DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Newest-first page of plays, tags resolved like library rows.
  Future<List<Song>> recent({int limit = 50, int offset = 0}) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT s.${SongsTable.id}, s.${SongsTable.path}, s.${SongsTable.title}, '
      's.${SongsTable.duration}, s.${SongsTable.trackNumber}, '
      's.${SongsTable.artworkPath}, '
      's.${SongsTable.isAvailable}, '
      'a.${ArtistsTable.artistName} AS artist_name, '
      'al.${AlbumsTable.title} AS album_title, '
      'h.${PlaybackHistoryTable.playedAt} AS played_at '
      'FROM ${PlaybackHistoryTable.name} AS h '
      'JOIN ${SongsTable.name} AS s ON s.${SongsTable.id} = h.${PlaybackHistoryTable.songId} '
      'LEFT JOIN ${ArtistsTable.name} AS a ON a.${ArtistsTable.id} = s.${SongsTable.artistId} '
      'LEFT JOIN ${AlbumsTable.name} AS al ON al.${AlbumsTable.id} = s.${SongsTable.albumId} '
      'ORDER BY h.${PlaybackHistoryTable.playedAt} DESC, h.${PlaybackHistoryTable.id} DESC '
      'LIMIT ? OFFSET ?',
      <Object?>[limit, offset],
    );
    return rows.map(Song.fromRow).toList(growable: false);
  }
}
