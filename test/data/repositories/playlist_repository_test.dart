import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/data/database/database.dart';
import 'package:music_oasis/data/database/tables/playlist_songs_table.dart';
import 'package:music_oasis/data/database/tables/songs_table.dart';
import 'package:music_oasis/data/repositories/playlist_repository.dart';
import 'package:music_oasis/data/models/playlist.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  group('PlaylistRepository', () {
    late AppDatabase appDatabase;
    late Database db;
    late PlaylistRepository repository;

    setUp(() async {
      appDatabase = AppDatabase(
        factoryOverride: databaseFactoryFfi,
        pathResolverOverride: () async => inMemoryDatabasePath,
      );
      db = await appDatabase.open();
      repository = PlaylistRepository(db);
    });

    tearDown(() => appDatabase.close());

    Future<int> song(String title, {bool available = true, String? artwork}) =>
        db.insert(SongsTable.name, <String, Object?>{
          SongsTable.path: '/music/$title.mp3',
          SongsTable.title: title,
          SongsTable.dateAdded: 1,
          SongsTable.isAvailable: available ? 1 : 0,
          SongsTable.artworkPath: ?artwork,
        });

    test('create, list with counts, most recent first', () async {
      final a = await repository.create('Night Drive');
      final b = await repository.create('Rainy Day');

      final List<Playlist> playlists = await repository.list();
      expect(playlists.map((p) => p.id), <int>[b.id, a.id]);
      expect(playlists.first.songCount, 0);
    });

    test('duplicate names are rejected', () async {
      await repository.create('Focus');
      expect(
        () => repository.create('Focus'),
        throwsA(isA<PlaylistNameTaken>()),
      );
    });

    test('rename updates and rejects collisions', () async {
      final p = await repository.create('Focus');
      final other = await repository.create('Other');

      await repository.rename(p.id, 'Deep Focus');
      expect(
        (await repository.list()).map((x) => x.name),
        containsAll(<String>['Deep Focus', 'Other']),
      );

      expect(
        () => repository.rename(other.id, 'Deep Focus'),
        throwsA(isA<PlaylistNameTaken>()),
      );
    });

    test('add keeps order and allows duplicates', () async {
      final p = await repository.create('Mix');
      final s1 = await song('Alpha');
      final s2 = await song('Beta');

      await repository.addSong(p.id, s1);
      await repository.addSong(p.id, s2);
      await repository.addSong(p.id, s1); // same song twice is legitimate

      final songs = await repository.songs(p.id);
      expect(songs.map((s) => s.title), <String>['Alpha', 'Beta', 'Alpha']);
    });

    test('removeAt closes the gap', () async {
      final p = await repository.create('Mix');
      final s1 = await song('Alpha');
      final s2 = await song('Beta');
      final s3 = await song('Gamma');
      for (final int id in <int>[s1, s2, s3]) {
        await repository.addSong(p.id, id);
      }

      await repository.removeAt(p.id, 1);

      final songs = await repository.songs(p.id);
      expect(songs.map((s) => s.title), <String>['Alpha', 'Gamma']);
    });

    test('move reorders within bounds', () async {
      final p = await repository.create('Order');
      final ids = <int>[
        await song('One'),
        await song('Two'),
        await song('Three'),
      ];
      for (final int id in ids) {
        await repository.addSong(p.id, id);
      }

      await repository.move(p.id, from: 0, to: 2);

      final songs = await repository.songs(p.id);
      expect(songs.map((s) => s.title), <String>['Two', 'Three', 'One']);
    });

    test('unavailable files stay listed, marked by the join', () async {
      final p = await repository.create('Kept');
      final gone = await song('Vanished', available: false);
      await repository.addSong(p.id, gone);

      // The scanner marks availability; it never deletes rows, so membership
      // and metadata survive.
      final songs = await repository.songs(p.id);
      expect(songs, hasLength(1));
      expect(songs.single.title, 'Vanished');
      expect(songs.single.isAvailable, isFalse);
    });

    test('delete leaves the song itself untouched', () async {
      final p = await repository.create('Doomed');
      final s = await song('Survivor');
      await repository.addSong(p.id, s);

      await repository.delete(p.id);

      expect(await repository.list(), isEmpty);
      final rows = await db.query(
        PlaylistSongsTable.name,
        where: '${PlaylistSongsTable.songId} = ?',
        whereArgs: <Object?>[s],
      );
      expect(rows, isEmpty); // cascade

      final survivors = await db.query(SongsTable.name);
      expect(survivors, hasLength(1)); // the song itself is untouched
    });

    test('addSongs appends new memberships, skips members, reports counts',
        () async {
      final p = await repository.create('Mix');
      final kept = await song('Kept');
      await repository.addSong(p.id, kept);

      final s1 = await song('Alpha');
      final s2 = await song('Beta');
      // Adding a song twice within one batch is as legitimate as two manual
      // addSong calls (matches the single-add contract).
      final outcome = await repository.addSongs(p.id, <int>[s1, kept, s2, s1]);

      expect(outcome.added, 3);
      expect(outcome.duplicates, 1);

      final songs = await repository.songs(p.id);
      expect(songs.map((x) => x.title), <String>['Kept', 'Alpha', 'Beta', 'Alpha']);
    });

    test('addSongs with an empty batch changes nothing', () async {
      final p = await repository.create('Mix');
      final outcome = await repository.addSongs(p.id, <int>[]);
      expect(outcome.added, 0);
      expect(outcome.duplicates, 0);
      expect(await repository.songs(p.id), isEmpty);
    });

    test('coverPaths returns distinct artworks in play order, capped at four',
        () async {
      final p = await repository.create('Art');
      final a1 = await song('One', artwork: '/art/a.jpg');
      final a2 = await song('Two', artwork: '/art/b.jpg');
      final none = await song('None');
      // Same artwork twice in the playlist; dedupe by path.
      final a3 = await song('Three', artwork: '/art/a.jpg');

      await repository.addSongs(p.id, <int>[a1, a2, none, a3]);

      expect(
        await repository.coverPaths(p.id),
        <String?>['/art/a.jpg', '/art/b.jpg'],
      );
    });

    test('coverPaths is empty for art-less playlists', () async {
      final p = await repository.create('Plain');
      final s = await song('No Art');
      await repository.addSong(p.id, s);

      expect(await repository.coverPaths(p.id), isEmpty);
    });

    test('covers() aggregates for all playlists in one query', () async {
      final p1 = await repository.create('One');
      final p2 = await repository.create('Two');
      final s1 = await song('A', artwork: '/art/a.jpg');
      final s2 = await song('B', artwork: '/art/b.jpg');
      await repository.addSongs(p1.id, <int>[s1, s2]);
      await repository.addSong(p2.id, s1);

      final covers = await repository.covers();

      expect(covers, hasLength(2));
      expect(covers[p1.id], <String?>['/art/a.jpg', '/art/b.jpg']);
      expect(covers[p2.id], <String?>['/art/a.jpg']);
    });
  });
}
