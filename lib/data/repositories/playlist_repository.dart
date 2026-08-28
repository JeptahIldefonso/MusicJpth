import 'dart:math' as math;

import 'package:sqflite/sqflite.dart'
    show ConflictAlgorithm, Database, Transaction;

import '../database/tables/albums_table.dart';
import '../database/tables/artists_table.dart';
import '../database/tables/playlists_table.dart';
import '../database/tables/playlist_songs_table.dart';
import '../database/tables/songs_table.dart';
import '../models/playlist.dart';
import '../models/song.dart';

/// Thrown when a name collides with the unique playlist-name index; the UI
/// turns it into copy, the database stays the referee.
class PlaylistNameTaken implements Exception {
  const PlaylistNameTaken(this.name);

  final String name;

  @override
  String toString() => 'Playlist name taken: $name';
}

/// Reads and writes `playlists` and `playlist_songs`.
///
/// Ordering lives in [PlaylistSongsTable.position]; every mutation rewrites
/// positions and bumps `date_modified` inside one transaction, so a playlist
/// is never left half-ordered (`REQUIREMENTS.md` §43). Membership rows
/// reference songs by id and cascade on song deletion — an unavailable file
/// keeps its membership until its row actually goes away, which the scanner
/// never does (it only marks `is_available`).
class PlaylistRepository {
  const PlaylistRepository(this._db);

  final Database _db;

  /// SQLite allows 999 bound variables per statement; keep a safe ceiling.
  static const int _maxVariables = 500;

  /// All playlists, most recently touched first, with membership counts.
  Future<List<Playlist>> list() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT p.${PlaylistsTable.id}, p.${PlaylistsTable.playlistName}, '
      'p.${PlaylistsTable.dateModified}, '
      'COUNT(ps.${PlaylistSongsTable.id}) AS song_count '
      'FROM ${PlaylistsTable.name} AS p '
      'LEFT JOIN ${PlaylistSongsTable.name} AS ps '
      'ON ps.${PlaylistSongsTable.playlistId} = p.${PlaylistsTable.id} '
      'GROUP BY p.${PlaylistsTable.id} '
      'ORDER BY p.${PlaylistsTable.dateModified} DESC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  /// Creates a playlist. Throws [PlaylistNameTaken] on a name collision.
  Future<Playlist> create(String name) async {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final int id = await _db.insert(PlaylistsTable.name, <String, Object?>{
        PlaylistsTable.playlistName: name,
        PlaylistsTable.dateCreated: nowMs,
        PlaylistsTable.dateModified: nowMs,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
      return Playlist(id: id, name: name, songCount: 0, dateModified: nowMs);
    } on Object {
      if (await _nameExists(name)) throw PlaylistNameTaken(name);
      rethrow;
    }
  }

  /// Renames. Throws [PlaylistNameTaken] on any other playlist's name.
  Future<void> rename(int id, String name) async {
    try {
      final int updated = await _db.update(
        PlaylistsTable.name,
        <String, Object?>{
          PlaylistsTable.playlistName: name,
          PlaylistsTable.dateModified: DateTime.now().millisecondsSinceEpoch,
        },
        where: '${PlaylistsTable.id} = ?',
        whereArgs: <Object?>[id],
      );
      if (updated == 0) throw StateError('Playlist $id not found');
    } on Object {
      if (await _nameExists(name, exceptId: id)) {
        throw PlaylistNameTaken(name);
      }
      rethrow;
    }
  }

  /// Deletes the playlist; membership rows go with it via cascade. Songs are
  /// untouched — playlists hold references, never ownership.
  Future<void> delete(int id) => _db.delete(
    PlaylistsTable.name,
    where: '${PlaylistsTable.id} = ?',
    whereArgs: <Object?>[id],
  );

  /// One page of a playlist's songs in play order, tags resolved by join —
  /// the same read model the library uses, so rows render identically.
  Future<List<Song>> songs(
    int playlistId, {
    int limit = 200,
    int offset = 0,
  }) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT s.${SongsTable.id}, s.${SongsTable.path}, s.${SongsTable.title}, '
      's.${SongsTable.duration}, s.${SongsTable.trackNumber}, '
      's.${SongsTable.artworkPath}, '
      's.${SongsTable.isAvailable}, '
      'a.${ArtistsTable.artistName} AS artist_name, '
      'al.${AlbumsTable.title} AS album_title, '
      'ps.${PlaylistSongsTable.position} AS position '
      'FROM ${PlaylistSongsTable.name} AS ps '
      'JOIN ${SongsTable.name} AS s ON s.${SongsTable.id} = ps.${PlaylistSongsTable.songId} '
      'LEFT JOIN ${ArtistsTable.name} AS a ON a.${ArtistsTable.id} = s.${SongsTable.artistId} '
      'LEFT JOIN ${AlbumsTable.name} AS al ON al.${AlbumsTable.id} = s.${SongsTable.albumId} '
      'WHERE ps.${PlaylistSongsTable.playlistId} = ? '
      'ORDER BY ps.${PlaylistSongsTable.position} ASC '
      'LIMIT ? OFFSET ?',
      <Object?>[playlistId, limit, offset],
    );
    return rows.map(Song.fromRow).toList(growable: false);
  }

  /// Whether [songId] already has a membership row in [playlistId] — the
  /// app-level duplicate guard the picker uses. The table itself keeps a
  /// surrogate key so duplicates stay possible for callers who want them.
  Future<bool> containsSong(int playlistId, int songId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      PlaylistSongsTable.name,
      columns: <String>[PlaylistSongsTable.id],
      where:
          '${PlaylistSongsTable.playlistId} = ? '
          'AND ${PlaylistSongsTable.songId} = ?',
      whereArgs: <Object?>[playlistId, songId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Appends one song at the end. The same song may appear twice — the table
  /// is deliberately keyed by surrogate id, not (playlist, song).
  Future<void> addSong(int playlistId, int songId) async {
    await _db.transaction<void>((Transaction txn) async {
      final List<Map<String, Object?>> maxRows = await txn.rawQuery(
        'SELECT COALESCE(MAX(${PlaylistSongsTable.position}), -1) AS max_pos '
        'FROM ${PlaylistSongsTable.name} '
        'WHERE ${PlaylistSongsTable.playlistId} = ?',
        <Object?>[playlistId],
      );
      final int nextPosition = (maxRows.single['max_pos']! as int) + 1;
      await txn.insert(PlaylistSongsTable.name, <String, Object?>{
        PlaylistSongsTable.playlistId: playlistId,
        PlaylistSongsTable.songId: songId,
        PlaylistSongsTable.position: nextPosition,
      });
      await _touch(txn, playlistId);
    });
  }

  /// Appends a batch of songs, skipping songs already in the playlist.
  ///
  /// One transaction — either every new membership lands with consecutive
  /// positions and a single `date_modified` bump, or none does. Returns how
  /// many were newly added and how many were already members.
  Future<({int added, int duplicates})> addSongs(
    int playlistId,
    List<int> songIds,
  ) async {
    if (songIds.isEmpty) return (added: 0, duplicates: 0);
    return _db.transaction<({int added, int duplicates})>(
      (Transaction txn) async {
        final Set<int> existing = <int>{};
        for (int start = 0; start < songIds.length; start += _maxVariables) {
          final int end = math.min(start + _maxVariables, songIds.length);
          final List<int> slice = songIds.sublist(start, end);
          final List<Map<String, Object?>> rows = await txn.query(
            PlaylistSongsTable.name,
            columns: <String>[PlaylistSongsTable.songId],
            where:
                '${PlaylistSongsTable.playlistId} = ? '
                'AND ${PlaylistSongsTable.songId} IN '
                '(${_placeholders(slice.length)})',
            whereArgs: <Object?>[playlistId, ...slice],
          );
          for (final Map<String, Object?> row in rows) {
            existing.add(row[PlaylistSongsTable.songId]! as int);
          }
        }

        final List<Map<String, Object?>> maxRows = await txn.rawQuery(
          'SELECT COALESCE(MAX(${PlaylistSongsTable.position}), -1) AS max_pos '
          'FROM ${PlaylistSongsTable.name} '
          'WHERE ${PlaylistSongsTable.playlistId} = ?',
          <Object?>[playlistId],
        );
        int nextPosition = (maxRows.single['max_pos']! as int) + 1;

        int added = 0;
        for (final int songId in songIds) {
          if (existing.contains(songId)) continue;
          await txn.insert(PlaylistSongsTable.name, <String, Object?>{
            PlaylistSongsTable.playlistId: playlistId,
            PlaylistSongsTable.songId: songId,
            PlaylistSongsTable.position: nextPosition++,
          });
          added++;
        }
        if (added > 0) await _touch(txn, playlistId);
        return (
          added: added,
          duplicates: songIds.length - added,
        );
      },
    );
  }

  /// Up to [limit] distinct artwork paths in play order, for playlists that
  /// have covers; an empty list means the playlist is art-less.
  Future<List<String?>> coverPaths(int playlistId, {int limit = 4}) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT s.${SongsTable.artworkPath} AS artwork_path '
      'FROM ${PlaylistSongsTable.name} AS ps '
      'JOIN ${SongsTable.name} AS s ON s.${SongsTable.id} = ps.${PlaylistSongsTable.songId} '
      'WHERE ps.${PlaylistSongsTable.playlistId} = ? '
      'AND s.${SongsTable.artworkPath} IS NOT NULL '
      'GROUP BY s.${SongsTable.artworkPath} '
      'ORDER BY ps.${PlaylistSongsTable.position} ASC '
      'LIMIT ?',
      <Object?>[playlistId, limit],
    );
    return rows
        .map((Map<String, Object?> row) => row['artwork_path'] as String?)
        .toList(growable: false);
  }

  /// Covers for every playlist in one query, up to four distinct artworks per
  /// playlist, ordered by each playlist's play order. Playlist counts are
  /// small, so an unbounded grouping stays cheap — but each list is capped.
  Future<Map<int, List<String?>>> covers() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT ps.${PlaylistSongsTable.playlistId} AS playlist_id, '
      's.${SongsTable.artworkPath} AS artwork_path, '
      'MIN(ps.${PlaylistSongsTable.position}) AS first_pos '
      'FROM ${PlaylistSongsTable.name} AS ps '
      'JOIN ${SongsTable.name} AS s ON s.${SongsTable.id} = ps.${PlaylistSongsTable.songId} '
      'WHERE s.${SongsTable.artworkPath} IS NOT NULL '
      'GROUP BY ps.${PlaylistSongsTable.playlistId}, s.${SongsTable.artworkPath} '
      'ORDER BY ps.${PlaylistSongsTable.playlistId} ASC, first_pos ASC',
    );
    final Map<int, List<String?>> covers = <int, List<String?>>{};
    for (final Map<String, Object?> row in rows) {
      final int id = row['playlist_id']! as int;
      final List<String?> list = covers.putIfAbsent(id, () => <String?>[]);
      if (list.length < 4) list.add(row['artwork_path'] as String?);
    }
    return covers;
  }

  /// Removes the entry at [position] and closes the gap in one transaction.
  Future<void> removeAt(int playlistId, int position) async {
    await _db.transaction<void>((Transaction txn) async {
      await txn.delete(
        PlaylistSongsTable.name,
        where:
            '${PlaylistSongsTable.playlistId} = ? AND ${PlaylistSongsTable.position} = ?',
        whereArgs: <Object?>[playlistId, position],
      );
      // Every later entry slides down one; single indexed UPDATE.
      await txn.execute(
        'UPDATE ${PlaylistSongsTable.name} '
        'SET ${PlaylistSongsTable.position} = ${PlaylistSongsTable.position} - 1 '
        'WHERE ${PlaylistSongsTable.playlistId} = ? '
        'AND ${PlaylistSongsTable.position} > ?',
        <Object?>[playlistId, position],
      );
      await _touch(txn, playlistId);
    });
  }

  /// Moves an entry from [from] to [to]; both are current positions.
  ///
  /// Reads only the membership ids (cheap even for thousands), computes the
  /// new order, then writes back just the segment that changed.
  Future<void> move(
    int playlistId, {
    required int from,
    required int to,
  }) async {
    if (from == to || from < 0 || to < 0) return;
    await _db.transaction<void>((Transaction txn) async {
      final List<Map<String, Object?>> rows = await txn.query(
        PlaylistSongsTable.name,
        columns: <String>[PlaylistSongsTable.id],
        where: '${PlaylistSongsTable.playlistId} = ?',
        whereArgs: <Object?>[playlistId],
        orderBy: '${PlaylistSongsTable.position} ASC',
      );
      if (from >= rows.length || to >= rows.length) return;

      final List<int> ids = rows
          .map((Map<String, Object?> row) => row[PlaylistSongsTable.id]! as int)
          .toList();
      ids.insert(to, ids.removeAt(from));

      final int lowerBound = from < to ? from : to;
      final int upperBound = from < to ? to : from;
      for (int position = lowerBound; position <= upperBound; position++) {
        await txn.update(
          PlaylistSongsTable.name,
          <String, Object?>{PlaylistSongsTable.position: position},
          where: '${PlaylistSongsTable.id} = ?',
          whereArgs: <Object?>[ids[position]],
        );
      }
      await _touch(txn, playlistId);
    });
  }

  Playlist _fromRow(Map<String, Object?> row) => Playlist(
    id: row[PlaylistsTable.id]! as int,
    name: row[PlaylistsTable.playlistName]! as String,
    songCount: row['song_count']! as int,
    dateModified: row[PlaylistsTable.dateModified]! as int,
  );

  Future<bool> _nameExists(String name, {int? exceptId}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      PlaylistsTable.name,
      columns: <String>[PlaylistsTable.id],
      where: exceptId == null
          ? '${PlaylistsTable.playlistName} = ?'
          : '${PlaylistsTable.playlistName} = ? AND ${PlaylistsTable.id} != ?',
      whereArgs: exceptId == null ? <Object?>[name] : <Object?>[name, exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> _touch(Transaction txn, int playlistId) => txn.update(
    PlaylistsTable.name,
    <String, Object?>{
      PlaylistsTable.dateModified: DateTime.now().millisecondsSinceEpoch,
    },
    where: '${PlaylistsTable.id} = ?',
    whereArgs: <Object?>[playlistId],
  );

  static String _placeholders(int count) =>
      List<String>.filled(count, '?').join(', ');
}
