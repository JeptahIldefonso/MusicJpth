import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/data/database/database.dart';
import 'package:music_oasis/data/database/tables/albums_table.dart';
import 'package:music_oasis/data/database/tables/songs_table.dart';
import 'package:music_oasis/data/models/discovered_file.dart';
import 'package:music_oasis/data/models/track_metadata.dart';
import 'package:music_oasis/data/repositories/metadata_repository.dart';
import 'package:music_oasis/data/repositories/song_repository.dart';
import 'package:music_oasis/services/artwork/artwork_cache_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// In-memory cache double recording saves; no filesystem involved.
class FakeArtworkCache implements ArtworkCacheService {
  final List<Uint8List> saved = <Uint8List>[];

  @override
  Directory? get baseDirOverride => null;

  @override
  Future<String?> save(Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    saved.add(bytes);
    return 'artwork/hash${saved.length}.jpg';
  }

  @override
  Future<File?> resolve(String? relativePath) async => null;
}

void main() {
  setUpAll(sqfliteFfiInit);

  group('MetadataRepository artwork persistence', () {
    late AppDatabase appDatabase;
    late Database db;
    late SongRepository songs;
    late MetadataRepository metadata;

    setUp(() async {
      appDatabase = AppDatabase(
        factoryOverride: databaseFactoryFfi,
        pathResolverOverride: () async => inMemoryDatabasePath,
      );
      db = await appDatabase.open();
      songs = SongRepository(db);
      metadata = MetadataRepository(db);
    });

    tearDown(() => appDatabase.close());

    Future<void> index(List<String> paths) => songs.syncBatch(
      paths
          .map(
            (String p) => DiscoveredFile(
              path: p,
              format: '.mp3',
              size: 100,
              modifiedMs: 1000,
            ),
          )
          .toList(growable: false),
    );

    test('cover bytes are stored and pointed at by the song row', () async {
      await index(<String>['/music/a.mp3']);
      final cache = FakeArtworkCache();
      const coverBytes = <int>[0xFF, 0xD8, 1, 2, 3];

      await metadata.apply(<TrackMetadata>[
        TrackMetadata(
          path: '/music/a.mp3',
          title: 'A',
          album: 'Album',
          coverBytes: Uint8List.fromList(coverBytes),
        ),
      ], artwork: cache);

      final row = (await db.query(
        SongsTable.name,
        where: '${SongsTable.path} = ?',
        whereArgs: <Object?>['/music/a.mp3'],
      )).single;
      expect(row[SongsTable.artworkPath], 'artwork/hash1.jpg');
      expect(cache.saved.single, hasLength(5));
    });

    test('the album row is backfilled once and only once', () async {
      await index(<String>['/music/a.mp3', '/music/b.mp3']);
      final cache = FakeArtworkCache();

      await metadata.apply(<TrackMetadata>[
        TrackMetadata(
          path: '/music/a.mp3',
          title: 'A',
          album: 'Album',
          coverBytes: Uint8List.fromList(<int>[0xFF, 0xD8, 1]),
        ),
        TrackMetadata(
          path: '/music/b.mp3',
          title: 'B',
          album: 'Album',
          coverBytes: Uint8List.fromList(<int>[0xFF, 0xD8, 2]),
        ),
      ], artwork: cache);

      final albums = await db.query(AlbumsTable.name);
      expect(albums.single[AlbumsTable.artworkPath], isNotNull);
    });

    test('no cache wired, or no cover in tags: nothing happens', () async {
      await index(<String>['/music/a.mp3']);

      await metadata.apply(<TrackMetadata>[
        TrackMetadata(path: '/music/a.mp3', title: 'A'),
      ]);
      final row = (await db.query(
        SongsTable.name,
        where: '${SongsTable.path} = ?',
        whereArgs: <Object?>['/music/a.mp3'],
      )).single;
      expect(row[SongsTable.artworkPath], isNull);
    });
  });
}
