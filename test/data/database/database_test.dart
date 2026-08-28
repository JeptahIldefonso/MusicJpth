import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/data/database/database.dart';
import 'package:music_oasis/data/database/migrations/migrations.dart';
import 'package:music_oasis/data/database/tables/albums_table.dart';
import 'package:music_oasis/data/database/tables/artists_table.dart';
import 'package:music_oasis/data/database/tables/favorites_table.dart';
import 'package:music_oasis/data/database/tables/music_folders_table.dart';
import 'package:music_oasis/data/database/tables/playback_history_table.dart';
import 'package:music_oasis/data/database/tables/playlist_songs_table.dart';
import 'package:music_oasis/data/database/tables/playlists_table.dart';
import 'package:music_oasis/data/database/tables/songs_table.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// In-memory database on the FFI factory — the same engine Windows uses.
AppDatabase _inMemoryDatabase() => AppDatabase(
  factoryOverride: databaseFactoryFfi,
  pathResolverOverride: () async => inMemoryDatabasePath,
);

Future<Set<String>> _names(Database db, String type) async {
  final List<Map<String, Object?>> rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = ? AND name NOT LIKE 'sqlite_%'",
    <Object?>[type],
  );
  return rows.map((Map<String, Object?> row) => row['name']! as String).toSet();
}

Future<int> _insertSong(Database db, String path) =>
    db.insert(SongsTable.name, <String, Object?>{
      SongsTable.path: path,
      SongsTable.title: 'Title',
      SongsTable.dateAdded: 0,
    });

void main() {
  setUpAll(sqfliteFfiInit);

  group('AppDatabase', () {
    late AppDatabase appDatabase;

    setUp(() => appDatabase = _inMemoryDatabase());
    tearDown(() => appDatabase.close());

    test(
      'creates every documented table at the current schema version',
      () async {
        final Database db = await appDatabase.open();

        expect(await db.getVersion(), schemaVersion);
        expect(await _names(db, 'table'), <String>{
          ArtistsTable.name,
          AlbumsTable.name,
          SongsTable.name,
          PlaylistsTable.name,
          PlaylistSongsTable.name,
          FavoritesTable.name,
          PlaybackHistoryTable.name,
          MusicFoldersTable.name,
        });
      },
    );

    test('creates the indexes the library queries rely on', () async {
      final Database db = await appDatabase.open();
      final Set<String> indexes = await _names(db, 'index');

      expect(
        indexes,
        containsAll(<String>[
          'idx_${SongsTable.name}_${SongsTable.path}',
          'idx_${SongsTable.name}_${SongsTable.title}',
          'idx_${SongsTable.name}_${SongsTable.artistId}',
          'idx_${SongsTable.name}_${SongsTable.albumId}',
          'idx_${SongsTable.name}_${SongsTable.dateAdded}',
          'idx_${SongsTable.name}_${SongsTable.lastPlayed}',
        ]),
      );
    });

    test(
      'returns one managed instance for concurrent and repeated opens',
      () async {
        final List<Database> opened = await Future.wait<Database>(
          <Future<Database>>[appDatabase.open(), appDatabase.open()],
        );

        expect(identical(opened.first, opened.last), isTrue);
        expect(identical(await appDatabase.open(), opened.first), isTrue);
        expect(identical(appDatabase.databaseOrNull, opened.first), isTrue);
      },
    );

    test('reopens after close', () async {
      await appDatabase.open();
      await appDatabase.close();

      expect(appDatabase.databaseOrNull, isNull);
      expect(await (await appDatabase.open()).getVersion(), schemaVersion);
    });

    test('enforces foreign keys', () async {
      final Database db = await appDatabase.open();

      await expectLater(
        db.insert(PlaylistSongsTable.name, <String, Object?>{
          PlaylistSongsTable.playlistId: 404,
          PlaylistSongsTable.songId: 404,
          PlaylistSongsTable.position: 0,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('cascades playlist membership when a song is deleted', () async {
      final Database db = await appDatabase.open();
      final int songId = await _insertSong(db, '/music/song.mp3');
      final int playlistId = await db.insert(
        PlaylistsTable.name,
        <String, Object?>{
          PlaylistsTable.playlistName: 'Nights',
          PlaylistsTable.dateCreated: 0,
          PlaylistsTable.dateModified: 0,
        },
      );
      await db.insert(PlaylistSongsTable.name, <String, Object?>{
        PlaylistSongsTable.playlistId: playlistId,
        PlaylistSongsTable.songId: songId,
        PlaylistSongsTable.position: 0,
      });

      await db.delete(
        SongsTable.name,
        where: '${SongsTable.id} = ?',
        whereArgs: <Object?>[songId],
      );

      expect(await db.query(PlaylistSongsTable.name), isEmpty);
    });

    test(
      'rejects a duplicate song path so scans cannot double-index',
      () async {
        final Database db = await appDatabase.open();
        await _insertSong(db, '/music/song.mp3');

        await expectLater(
          _insertSong(db, '/music/song.mp3'),
          throwsA(isA<DatabaseException>()),
        );
      },
    );
  });

  group('migrations', () {
    test('schemaVersion matches the last migration', () {
      expect(migrations.last.version, schemaVersion);
    });

    test('a fresh database applies every migration', () {
      expect(
        statementsBetween(from: 0, to: schemaVersion),
        hasLength(
          migrations.fold<int>(
            0,
            (int total, Migration m) => total + m.statements.length,
          ),
        ),
      );
    });

    test('an up-to-date database applies nothing', () {
      expect(
        statementsBetween(from: schemaVersion, to: schemaVersion),
        isEmpty,
      );
    });

    test('an install at version 1 upgrades to the current schema', () {
      expect(statementsBetween(from: 1, to: schemaVersion), <String>[
        SongsTable.addIsAvailable,
        SongsTable.createLibraryOrderIndex,
        SongsTable.addArtworkChecked,
        SongsTable.createArtworkPendingIndex,
      ]);
    });

    test('a version 1 install keeps its songs, all available', () async {
      // The real upgrade path, not a fresh create: a file-backed database built
      // at version 1 with rows in it, then reopened by AppDatabase at the
      // current version so `onUpgrade` runs.
      final Directory dir = Directory.systemTemp.createTempSync(
        'music_oasis_migration',
      );
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final String path = p.join(dir.path, 'music.db');

      final Database v1 = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (Database db, int version) async {
            for (final String statement in statementsBetween(from: 0, to: 1)) {
              await db.execute(statement);
            }
          },
        ),
      );
      await _insertSong(v1, '/music/existing.mp3');
      await v1.close();

      final AppDatabase upgraded = AppDatabase(
        factoryOverride: databaseFactoryFfi,
        pathResolverOverride: () async => path,
      );
      addTearDown(upgraded.close);
      final Database db = await upgraded.open();

      expect(await db.getVersion(), schemaVersion);
      // A row written before the column existed must come out available, or the
      // upgrade would hide a library that is still on disk. And it must still be
      // there at all — `REQUIREMENTS.md` §43.
      final List<Map<String, Object?>> rows = await db.query(
        SongsTable.name,
        columns: <String>[
          SongsTable.path,
          SongsTable.isAvailable,
          SongsTable.artworkChecked,
        ],
      );
      expect(rows.single[SongsTable.path], '/music/existing.mp3');
      expect(rows.single[SongsTable.isAvailable], 1);
      // Nobody has looked at this row for embedded artwork, so the next scan
      // must consider it. This is what makes a library indexed before cover
      // extraction worked — or one whose cover cache was lost — recoverable
      // at all, since the file itself is unchanged and the incremental
      // comparison alone would skip it forever.
      expect(rows.single[SongsTable.artworkChecked], 0);
    });
  });
}
