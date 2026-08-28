import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/data/database/database.dart';
import 'package:music_oasis/data/database/tables/favorites_table.dart';
import 'package:music_oasis/data/database/tables/songs_table.dart';
import 'package:music_oasis/data/repositories/favorites_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  group('FavoritesRepository', () {
    late AppDatabase appDatabase;
    late Database db;
    late FavoritesRepository repository;

    setUp(() async {
      appDatabase = AppDatabase(
        factoryOverride: databaseFactoryFfi,
        pathResolverOverride: () async => inMemoryDatabasePath,
      );
      db = await appDatabase.open();
      repository = FavoritesRepository(db);
    });

    tearDown(() => appDatabase.close());

    Future<int> song(String title, {bool available = true}) =>
        db.insert(SongsTable.name, <String, Object?>{
          SongsTable.path: '/music/$title.mp3',
          SongsTable.title: title,
          SongsTable.dateAdded: 1,
          SongsTable.isAvailable: available ? 1 : 0,
        });

    test('starts empty and toggles idempotently', () async {
      expect(await repository.ids(), isEmpty);
      expect(await repository.isFavorite(1), isFalse);

      final int s = await song('Alpha');
      expect(await repository.toggle(s), isTrue);
      expect(await repository.isFavorite(s), isTrue);
      expect(await repository.toggle(s), isFalse);
      expect(await repository.isFavorite(s), isFalse);

      // A redundant set to the same state stays consistent, not duplicated.
      await repository.setFavorite(s, favorite: true);
      await repository.setFavorite(s, favorite: true);
      expect(await repository.ids(), <int>{s});
    });

    test('page lists favourites newest first with resolved tags', () async {
      final int a = await song('Alpha');
      final int b = await song('Beta');
      await db.insert(FavoritesTable.name, <String, Object?>{
        FavoritesTable.songId: a,
        FavoritesTable.dateAdded: 10,
      });
      // Inserted later in the table but older by date_added: sorts second.
      await db.insert(FavoritesTable.name, <String, Object?>{
        FavoritesTable.songId: b,
        FavoritesTable.dateAdded: 5,
      });

      final page = await repository.page();
      expect(page.map((s) => s.title), <String>['Alpha', 'Beta']);
      expect(page, hasLength(2));

      final limited = await repository.page(limit: 1);
      expect(limited.single.title, 'Alpha');
    });

    test('unavailable songs keep their favourite and metadata', () async {
      final int gone = await song('Vanished', available: false);
      await repository.setFavorite(gone, favorite: true);

      // The scanner only marks availability; nothing deletes the song row or
      // its favourite.
      final page = await repository.page();
      expect(page.single.title, 'Vanished');
      expect(page.single.isAvailable, isFalse);
      expect(await repository.isFavorite(gone), isTrue);
    });
  });
}
