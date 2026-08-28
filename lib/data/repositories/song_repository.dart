import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart'
    show Batch, ConflictAlgorithm, Database, DatabaseExecutor, Transaction;

import '../../core/utils/music_paths.dart';
import '../database/tables/albums_table.dart';
import '../database/tables/artists_table.dart';
import '../database/tables/songs_table.dart';
import '../models/discovered_file.dart';
import '../models/song.dart';

/// Where one library page ended: the sort key of its last row. Immutable and
/// cheap to hold, so the UI never keeps a parallel offset counter.
@immutable
class LibraryCursor {
  const LibraryCursor({
    required this.available,
    required this.title,
    required this.id,
  });

  factory LibraryCursor.fromSong(Song song) => LibraryCursor(
    available: song.isAvailable,
    title: song.title,
    id: song.id,
  );

  final bool available;
  final String title;
  final int id;

  @override
  bool operator ==(Object other) =>
      other is LibraryCursor &&
      other.available == available &&
      other.title == title &&
      other.id == id;

  @override
  int get hashCode => Object.hash(available, title, id);
}

/// What the database already knows about one file, for the incremental compare.
@immutable
class SongFileState {
  const SongFileState({
    required this.id,
    required this.size,
    required this.modifiedMs,
    required this.isAvailable,
  });

  final int id;

  /// Nullable because the columns are: a row written before the scanner existed
  /// would not carry them.
  final int? size;
  final int? modifiedMs;

  /// Whether the row is currently marked available. A file that comes back must
  /// be flipped back even when nothing else about it changed.
  final bool isAvailable;
}

/// How much a scan changed. Added up batch by batch.
@immutable
class SongSyncCounts {
  const SongSyncCounts({this.added = 0, this.updated = 0, this.restored = 0});

  static const SongSyncCounts none = SongSyncCounts();

  final int added;
  final int updated;

  /// Songs that were marked unavailable and whose file the scan found again.
  final int restored;

  SongSyncCounts operator +(SongSyncCounts other) => SongSyncCounts(
    added: added + other.added,
    updated: updated + other.updated,
    restored: restored + other.restored,
  );

  @override
  bool operator ==(Object other) =>
      other is SongSyncCounts &&
      other.added == added &&
      other.updated == updated &&
      other.restored == restored;

  @override
  int get hashCode => Object.hash(added, updated, restored);

  @override
  String toString() =>
      'SongSyncCounts(added: $added, updated: $updated, restored: $restored)';
}

/// Reads and writes the `songs` table.
///
/// Owns the scan-to-database contract: `path` is a song's identity, and
/// `file_size`/`modified_time` decide whether a known file changed
/// (`PROJECT.md` §08). Never reads the filesystem — the scanner service brings
/// it what it found.
class SongRepository {
  const SongRepository(this._db);

  final Database _db;

  /// SQLite allows 999 bound variables per statement; this stays well under it
  /// while keeping the number of round trips low.
  static const int _maxVariables = 500;

  /// Rows read per page during reconciliation.
  static const int _pageSize = 500;

  /// Inserts what is new and updates what changed, for one discovery batch.
  ///
  /// One transaction per batch, so an interrupted scan leaves whole batches
  /// applied and never a half-written row (`PROJECT.md` §30). A file that did
  /// not change costs one indexed lookup and no write at all — the point of an
  /// incremental scan (`REQUIREMENTS.md` §19).
  ///
  /// When [changedPaths] is given, the path of every inserted or updated file is
  /// added to it. That is exactly the set whose tags are worth re-reading, so a
  /// caller can parse only those and never re-parse an unchanged file
  /// (`REQUIREMENTS.md` §31: no repeated metadata parsing). Appended only after
  /// the batch commits, because a rolled-back batch changed nothing.
  Future<SongSyncCounts> syncBatch(
    List<DiscoveredFile> files, {
    List<String>? changedPaths,
  }) async {
    if (files.isEmpty) return SongSyncCounts.none;

    return _db.transaction<SongSyncCounts>((Transaction txn) async {
      final Map<String, SongFileState> known = await _statesFor(
        txn,
        files.map((DiscoveredFile file) => file.path).toList(growable: false),
      );

      final int now = DateTime.now().millisecondsSinceEpoch;
      final Batch batch = txn.batch();
      final List<String> changed = <String>[];
      int added = 0;
      int updated = 0;
      int restored = 0;

      for (final DiscoveredFile file in files) {
        final SongFileState? state = known[file.path];

        if (state == null) {
          batch.insert(
            SongsTable.name,
            <String, Object?>{
              SongsTable.path: file.path,
              // Placeholder identity taken from the filename: tags are read in
              // the metadata step, the column is NOT NULL, and a filename is
              // what the user already sees in their file manager.
              SongsTable.title: MusicPaths.fallbackTitle(file.path),
              SongsTable.format: file.format,
              SongsTable.fileSize: file.size,
              SongsTable.modifiedTime: file.modifiedMs,
              SongsTable.dateAdded: now,
              SongsTable.isAvailable: 1,
            },
            // The unique index on `path` is the last guard against a double
            // insert; losing that race is not an error, the row is already
            // there.
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          added++;
          changed.add(file.path);
          continue;
        }

        if (state.size == file.size && state.modifiedMs == file.modifiedMs) {
          // The file is byte-for-byte what the index already holds, so its tags
          // are still valid and it stays out of [changedPaths]. But a file that
          // had been marked unavailable is back, and that is worth one write.
          if (!state.isAvailable) {
            batch.update(
              SongsTable.name,
              <String, Object?>{SongsTable.isAvailable: 1},
              where: '${SongsTable.id} = ?',
              whereArgs: <Object?>[state.id],
            );
            restored++;
          }
          continue;
        }

        batch.update(
          SongsTable.name,
          <String, Object?>{
            SongsTable.format: file.format,
            SongsTable.fileSize: file.size,
            SongsTable.modifiedTime: file.modifiedMs,
            // Seeing the file at all makes it available again, whether it was
            // marked unavailable or never stopped being there.
            SongsTable.isAvailable: 1,
          },
          where: '${SongsTable.id} = ?',
          whereArgs: <Object?>[state.id],
        );
        updated++;
        changed.add(file.path);
        if (!state.isAvailable) restored++;
      }

      await batch.commit(noResult: true);
      changedPaths?.addAll(changed);
      return SongSyncCounts(added: added, updated: updated, restored: restored);
    });
  }

  /// Marks songs that live under [roots] but were not seen by the scan as
  /// unavailable — files moved or deleted outside the app (`PROJECT.md` §12).
  ///
  /// Nothing is deleted. The row keeps its id, so the user's playlist entries,
  /// favorites and playback history survive a file going missing, and the song
  /// comes back with all of it intact if the file returns. `path` stays the
  /// identity throughout.
  ///
  /// Only call this after a scan that ran to completion: a cancelled or partial
  /// scan has not proved that the files it never reached are gone.
  ///
  /// [seenKeys] holds [MusicPaths.key] of every discovered file. Rows outside
  /// [roots] are never touched, so a folder that was not scanned — an unplugged
  /// drive, a folder the user stopped watching — keeps its songs available.
  ///
  /// Pages through the table by id, so reconciliation holds one page of paths at
  /// a time rather than the library. Returns how many songs this call newly
  /// marked unavailable; already-unavailable rows are not counted or rewritten,
  /// so a repeated scan reports zero.
  Future<int> markMissing({
    required List<String> roots,
    required Set<String> seenKeys,
  }) async {
    if (roots.isEmpty) return 0;

    int marked = 0;
    int afterId = 0;

    while (true) {
      final List<Map<String, Object?>> page = await _db.query(
        SongsTable.name,
        columns: <String>[SongsTable.id, SongsTable.path],
        where: '${SongsTable.id} > ? AND ${SongsTable.isAvailable} = 1',
        whereArgs: <Object?>[afterId],
        orderBy: '${SongsTable.id} ASC',
        limit: _pageSize,
      );
      if (page.isEmpty) break;

      final List<Object?> gone = <Object?>[];
      for (final Map<String, Object?> row in page) {
        afterId = row[SongsTable.id]! as int;
        final String path = row[SongsTable.path]! as String;
        final bool scanned = roots.any(
          (String root) => MusicPaths.isUnder(root, path),
        );
        if (scanned && !seenKeys.contains(MusicPaths.key(path))) {
          gone.add(afterId);
        }
      }

      if (gone.isNotEmpty) {
        marked += await _db.update(
          SongsTable.name,
          <String, Object?>{SongsTable.isAvailable: 0},
          where: '${SongsTable.id} IN (${_placeholders(gone.length)})',
          whereArgs: gone,
        );
      }

      if (page.length < _pageSize) break;
    }

    return marked;
  }

  /// How many songs are indexed, available or not. The database counts; nothing
  /// is loaded.
  Future<int> count() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${SongsTable.name}',
    );
    return rows.first['total']! as int;
  }

  /// How many indexed songs are currently available.
  Future<int> availableCount() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${SongsTable.name} '
      'WHERE ${SongsTable.isAvailable} = 1',
    );
    return rows.first['total']! as int;
  }

  /// All songs in the library, available first, for the add-to-playlist
  /// picker. Lighter than paginated browsing — the picker needs the full list
  /// for search filtering.
  Future<List<Song>> all() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT s.${SongsTable.id}, s.${SongsTable.path}, s.${SongsTable.title}, '
      's.${SongsTable.duration}, s.${SongsTable.trackNumber}, '
      's.${SongsTable.artworkPath}, '
      's.${SongsTable.isAvailable}, '
      'a.${ArtistsTable.artistName} AS artist_name, '
      'al.${AlbumsTable.title} AS album_title '
      'FROM ${SongsTable.name} AS s '
      'LEFT JOIN ${ArtistsTable.name} AS a ON a.${ArtistsTable.id} = s.${SongsTable.artistId} '
      'LEFT JOIN ${AlbumsTable.name} AS al ON al.${AlbumsTable.id} = s.${SongsTable.albumId} '
      'WHERE s.${SongsTable.isAvailable} = 1 '
      'ORDER BY s.${SongsTable.title} COLLATE NOCASE ASC',
    );
    return List<Song>.unmodifiable(rows.map(Song.fromRow));
  }

  /// Paths of up to [limit] available songs whose tags have never been examined
  /// for embedded cover art.
  ///
  /// This is what makes lost artwork recoverable. An unchanged file is excluded
  /// from the tag pass by design, and cover extraction rides along with that
  /// pass — so a row indexed before extraction worked, or one whose cached
  /// cover file vanished with the app's support directory, is byte-for-byte
  /// unchanged and would never be looked at again.
  Future<List<String>> pathsAwaitingArtwork({required int limit}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      SongsTable.name,
      columns: <String>[SongsTable.path],
      where:
          '${SongsTable.artworkChecked} = 0 '
          'AND ${SongsTable.isAvailable} = 1',
      limit: limit,
    );
    return rows
        .map((Map<String, Object?> row) => row[SongsTable.path]! as String)
        .toList(growable: false);
  }

  /// Records that [paths] have been examined for embedded artwork, whether or
  /// not one was found.
  ///
  /// Driven by the caller's own list rather than by what the tag reader
  /// returned: a file that fails to parse, or whose row went away mid-scan,
  /// must still be marked or [pathsAwaitingArtwork] would hand it back forever.
  Future<void> markArtworkChecked(List<String> paths) async {
    if (paths.isEmpty) return;
    final Batch batch = _db.batch();
    for (int start = 0; start < paths.length; start += _maxVariables) {
      final int end = start + _maxVariables;
      final List<String> slice = paths.sublist(
        start,
        end > paths.length ? paths.length : end,
      );
      batch.rawUpdate(
        'UPDATE ${SongsTable.name} '
        'SET ${SongsTable.artworkChecked} = 1 '
        'WHERE ${SongsTable.path} IN (${_placeholders(slice.length)})',
        slice,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Returns the absolute file path for [songId], or `null` if the row
  /// does not exist.
  Future<String?> pathFor(int songId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      SongsTable.name,
      columns: <String>[SongsTable.path],
      where: '${SongsTable.id} = ?',
      whereArgs: <Object?>[songId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first[SongsTable.path] as String;
  }

  /// Removes the database record for [songId]. Cascades handle
  /// playlist_songs, favourites, playback_history.
  ///
  /// This is DB-only — it does NOT touch the filesystem. The caller must
  /// ensure the physical file has already been deleted (or marked
  /// unavailable) before calling this.
  Future<bool> removeFromDatabase(int songId) async {
    final int deleted = await _db.delete(
      SongsTable.name,
      where: '${SongsTable.id} = ?',
      whereArgs: <Object?>[songId],
    );
    return deleted > 0;
  }

  /// One page of the library, artist and album names resolved by join.
  ///
  /// Available songs first, then unavailable ones; within each group by title,
  /// case-insensitively. Keyset pagination: pass the last row of the previous
  /// page as [after] and this page starts strictly after it — each read costs
  /// one index range scan on `idx_songs_library_order` regardless of how deep
  /// into a 10,000-song library the user has scrolled, with no skipped or
  /// repeated rows (`REQUIREMENTS.md` §21). Rows are read per page only; the
  /// whole library is never loaded into memory.
  Future<List<Song>> page({required int limit, LibraryCursor? after}) async {
    final String where;
    final List<Object?> args;
    if (after == null) {
      where = '1 = 1';
      args = <Object?>[];
    } else if (after.available) {
      // Later in (is_available DESC, …) order: remaining available rows by
      // title/id, then every unavailable row.
      where =
          '(s.${SongsTable.isAvailable} = 1 AND '
          '(s.${SongsTable.title} COLLATE NOCASE > ? OR '
          '(s.${SongsTable.title} COLLATE NOCASE = ? AND s.${SongsTable.id} > ?))) '
          'OR s.${SongsTable.isAvailable} = 0';
      args = <Object?>[after.title, after.title, after.id];
    } else {
      where =
          's.${SongsTable.isAvailable} = 0 AND '
          '(s.${SongsTable.title} COLLATE NOCASE > ? OR '
          '(s.${SongsTable.title} COLLATE NOCASE = ? AND s.${SongsTable.id} > ?))';
      args = <Object?>[after.title, after.title, after.id];
    }

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT s.${SongsTable.id}, s.${SongsTable.path}, s.${SongsTable.title}, '
      's.${SongsTable.duration}, s.${SongsTable.trackNumber}, '
      's.${SongsTable.artworkPath}, '
      's.${SongsTable.isAvailable}, '
      'a.${ArtistsTable.artistName} AS artist_name, '
      'al.${AlbumsTable.title} AS album_title '
      'FROM ${SongsTable.name} AS s '
      'LEFT JOIN ${ArtistsTable.name} AS a ON a.${ArtistsTable.id} = s.${SongsTable.artistId} '
      'LEFT JOIN ${AlbumsTable.name} AS al ON al.${AlbumsTable.id} = s.${SongsTable.albumId} '
      'WHERE $where '
      'ORDER BY s.${SongsTable.isAvailable} DESC, '
      's.${SongsTable.title} COLLATE NOCASE ASC, s.${SongsTable.id} ASC '
      'LIMIT ?',
      <Object?>[...args, limit],
    );
    return List<Song>.unmodifiable(rows.map(Song.fromRow));
  }

  /// Existing rows for [paths], keyed by stored path.
  ///
  /// Split into bounded `IN (...)` lookups so the whole library is never read to
  /// find out what a batch already contains.
  static Future<Map<String, SongFileState>> _statesFor(
    DatabaseExecutor db,
    List<String> paths,
  ) async {
    final Map<String, SongFileState> states = <String, SongFileState>{};

    for (int start = 0; start < paths.length; start += _maxVariables) {
      final int end = start + _maxVariables;
      final List<String> slice = paths.sublist(
        start,
        end > paths.length ? paths.length : end,
      );
      final List<Map<String, Object?>> rows = await db.query(
        SongsTable.name,
        columns: <String>[
          SongsTable.id,
          SongsTable.path,
          SongsTable.fileSize,
          SongsTable.modifiedTime,
          SongsTable.isAvailable,
        ],
        where: '${SongsTable.path} IN (${_placeholders(slice.length)})',
        whereArgs: slice,
      );
      for (final Map<String, Object?> row in rows) {
        states[row[SongsTable.path]! as String] = SongFileState(
          id: row[SongsTable.id]! as int,
          size: row[SongsTable.fileSize] as int?,
          modifiedMs: row[SongsTable.modifiedTime] as int?,
          // SQLite has no boolean type; the column is NOT NULL DEFAULT 1.
          isAvailable: (row[SongsTable.isAvailable] as int? ?? 1) != 0,
        );
      }
    }

    return states;
  }

  static String _placeholders(int count) =>
      List<String>.filled(count, '?').join(', ');
}
