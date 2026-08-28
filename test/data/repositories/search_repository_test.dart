import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/data/database/database.dart';
import 'package:music_oasis/data/database/tables/albums_table.dart';
import 'package:music_oasis/data/database/tables/artists_table.dart';
import 'package:music_oasis/data/database/tables/playlists_table.dart';
import 'package:music_oasis/data/database/tables/songs_table.dart';
import 'package:music_oasis/data/repositories/search_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  group('SearchRepository', () {
    late AppDatabase appDatabase;
    late Database db;
    late SearchRepository repository;

    setUp(() async {
      appDatabase = AppDatabase(
        factoryOverride: databaseFactoryFfi,
        pathResolverOverride: () async => inMemoryDatabasePath,
      );
      db = await appDatabase.open();
      repository = SearchRepository(db);

      final int artistId = await db.insert(ArtistsTable.name, <String, Object?>{
        ArtistsTable.artistName: 'Vera Mono',
      });
      final int otherArtistId = await db.insert(
        ArtistsTable.name,
        <String, Object?>{ArtistsTable.artistName: 'North Garden'},
      );
      final int albumId = await db.insert(AlbumsTable.name, <String, Object?>{
        AlbumsTable.title: 'Signal Forms',
        AlbumsTable.artistId: artistId,
      });
      await db.insert(SongsTable.name, <String, Object?>{
        SongsTable.path: '/music/northern.mp3',
        SongsTable.title: 'Northern Line',
        SongsTable.artistId: artistId,
        SongsTable.albumId: albumId,
        SongsTable.duration: 214000,
        SongsTable.genre: 'Ambient',
        SongsTable.dateAdded: 1,
      });
      await db.insert(SongsTable.name, <String, Object?>{
        SongsTable.path: '/music/garden.mp3',
        SongsTable.title: 'Garden Walls',
        SongsTable.artistId: otherArtistId,
        SongsTable.dateAdded: 2,
      });
      await db.insert(PlaylistsTable.name, <String, Object?>{
        PlaylistsTable.playlistName: 'Night Drive',
        PlaylistsTable.dateCreated: 3,
        PlaylistsTable.dateModified: 3,
      });
    });

    tearDown(() => appDatabase.close());

    test('finds matches across all groups', () async {
      // "north" hits a song title, an artist name and the playlist name.
      final results = await repository.search('north');

      expect(results.songs.map((s) => s.title), <String>['Northern Line']);
      expect(results.artists.map((a) => a.label), <String>['North Garden']);
      expect(results.albums, isEmpty);
    });

    test('playlist matches', () async {
      final results = await repository.search('drive');
      expect(results.playlists.map((p) => p.label), <String>['Night Drive']);
    });

    test('song rows carry resolved artist and album', () async {
      final results = await repository.search('Northern Line');

      expect(results.songs.single.artistName, 'Vera Mono');
      expect(results.songs.single.albumTitle, 'Signal Forms');
    });

    test('is case-insensitive', () async {
      final results = await repository.search('SIGNAL');
      expect(results.albums.single.label, 'Signal Forms');
    });

    test('treats LIKE wildcards as literal text', () async {
      // A bare wildcard matches nothing while no title contains one.
      final wildcardBefore = await repository.search('%');
      expect(wildcardBefore.songs, isEmpty);

      await db.insert(SongsTable.name, <String, Object?>{
        SongsTable.path: '/music/lit.mp3',
        SongsTable.title: '100% Sure',
        SongsTable.dateAdded: 4,
      });

      // …and once one does, only that row matches.
      final wildcardAfter = await repository.search('%');
      expect(wildcardAfter.songs.map((s) => s.title), <String>['100% Sure']);

      final literal = await repository.search('100% Sure');
      expect(literal.songs.map((s) => s.title), <String>['100% Sure']);
    });

    test('caps each group and marks it honestly', () async {
      for (int i = 0; i <= 30; i++) {
        await db.insert(SongsTable.name, <String, Object?>{
          SongsTable.path: '/music/bulk$i.mp3',
          SongsTable.title: 'Bulk ${i.toString().padLeft(2, '0')}',
          SongsTable.dateAdded: 100 + i,
        });
      }

      final results = await repository.search('bulk');
      expect(results.songs, hasLength(25));
      expect(results.capped['songs'], isTrue);
    });

    test('no match yields an empty result set', () async {
      final results = await repository.search('zzzz');
      expect(results.isEmpty, isTrue);
    });
  });
}
