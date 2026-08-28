import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/data/database/database.dart';
import 'package:music_oasis/data/database/tables/songs_table.dart';
import 'package:music_oasis/data/repositories/playback_history_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  group('PlaybackHistoryRepository', () {
    late AppDatabase appDatabase;
    late Database db;
    late PlaybackHistoryRepository repository;

    setUp(() async {
      appDatabase = AppDatabase(
        factoryOverride: databaseFactoryFfi,
        pathResolverOverride: () async => inMemoryDatabasePath,
      );
      db = await appDatabase.open();
      repository = PlaybackHistoryRepository(db);
    });

    tearDown(() => appDatabase.close());

    Future<int> song(String title, {bool available = true}) =>
        db.insert(SongsTable.name, <String, Object?>{
          SongsTable.path: '/music/$title.mp3',
          SongsTable.title: title,
          SongsTable.dateAdded: 1,
          SongsTable.isAvailable: available ? 1 : 0,
        });

    test(
      'starts empty; add then read newest first with resolved tags',
      () async {
        expect(await repository.recent(), isEmpty);

        final int a = await song('Alpha');
        final int b = await song('Beta');
        await repository.add(a);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await repository.add(b);

        final page = await repository.recent();
        expect(page.map((s) => s.title), <String>['Beta', 'Alpha']);
      },
    );

    test('replays create separate entries — repeats are history too', () async {
      final int a = await song('Alpha');
      await repository.add(a);
      await repository.add(a);

      expect(await repository.recent(), hasLength(2));
    });

    test('pagination bounds the read', () async {
      final int a = await song('Looped');
      for (int i = 0; i < 5; i++) {
        await repository.add(a);
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }

      final firstPage = await repository.recent(limit: 2);
      expect(firstPage, hasLength(2));

      final secondPage = await repository.recent(limit: 2, offset: 2);
      expect(secondPage, hasLength(2));
      expect(
        secondPage
            .map((s) => s.playedAtMs)
            .every((int? ms) => (ms ?? 0) <= firstPage.last.playedAtMs!),
        isTrue,
      );
    });

    test('unavailable songs keep their history rows', () async {
      final int gone = await song('Vanished', available: false);
      await repository.add(gone);
      await db.update(
        SongsTable.name,
        <String, Object?>{SongsTable.isAvailable: 0},
        where: '${SongsTable.id} = ?',
        whereArgs: <Object?>[gone],
      );

      final page = await repository.recent();
      expect(page.single.title, 'Vanished');
      expect(page.single.isAvailable, isFalse);
    });
  });
}
