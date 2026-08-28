import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/data/database/database.dart';
import 'package:music_oasis/data/models/music_folder.dart';
import 'package:music_oasis/data/repositories/music_folder_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  group('MusicFolderRepository', () {
    late AppDatabase appDatabase;
    late MusicFolderRepository repository;

    setUp(() async {
      appDatabase = AppDatabase(
        factoryOverride: databaseFactoryFfi,
        pathResolverOverride: () async => inMemoryDatabasePath,
      );
      repository = MusicFolderRepository(await appDatabase.open());
    });

    tearDown(() => appDatabase.close());

    test('starts empty', () async {
      expect(await repository.list(), isEmpty);
    });

    test('stores a picked folder with a normalised path', () async {
      final AddFolderResult result = await repository.add('/music/rock/');

      expect(result.isDuplicate, isFalse);
      expect(result.folder.id, greaterThan(0));
      expect(p.equals(result.folder.path, '/music/rock'), isTrue);
      expect(result.folder.path, isNot(endsWith(p.separator)));
      expect(result.folder.lastScanned, isNull);
      expect(await repository.list(), hasLength(1));
    });

    test('reports the same folder picked twice as a duplicate', () async {
      final AddFolderResult first = await repository.add('/music');
      final AddFolderResult second = await repository.add('/music/');

      expect(second.isDuplicate, isTrue);
      expect(second.folder.id, first.folder.id);
      expect(await repository.list(), hasLength(1));
    });

    test('reports a folder inside a watched folder as a duplicate', () async {
      final AddFolderResult parent = await repository.add('/music');
      final AddFolderResult child = await repository.add('/music/rock/1990');

      expect(child.isDuplicate, isTrue);
      expect(child.folder.id, parent.folder.id);
      expect(await repository.list(), hasLength(1));
    });

    test('accepts unrelated folders', () async {
      await repository.add('/music');
      final AddFolderResult other = await repository.add('/podcasts');

      expect(other.isDuplicate, isFalse);
      expect(await repository.list(), hasLength(2));
    });

    test('lists folders in path order', () async {
      await repository.add('/music/rock');
      await repository.add('/audio/live');

      final List<MusicFolder> folders = await repository.list();

      expect(p.equals(folders.first.path, '/audio/live'), isTrue);
      expect(p.equals(folders.last.path, '/music/rock'), isTrue);
    });

    test('coveringFolder answers the duplicate question directly', () async {
      final AddFolderResult added = await repository.add('/music');

      expect((await repository.coveringFolder('/music'))?.id, added.folder.id);
      expect(
        (await repository.coveringFolder('/music/rock'))?.id,
        added.folder.id,
      );
      expect(await repository.coveringFolder('/musicals'), isNull);
      expect(await repository.coveringFolder('/podcasts'), isNull);
    });

    test('removes only the requested folder', () async {
      final AddFolderResult kept = await repository.add('/music');
      final AddFolderResult dropped = await repository.add('/podcasts');

      await repository.remove(dropped.folder.id);

      final List<MusicFolder> folders = await repository.list();
      expect(folders, hasLength(1));
      expect(folders.single.id, kept.folder.id);
    });

    test('removing an unknown id is a no-op', () async {
      await repository.add('/music');

      await repository.remove(9999);

      expect(await repository.list(), hasLength(1));
    });

    test('a removed folder can be added again', () async {
      final AddFolderResult first = await repository.add('/music');
      await repository.remove(first.folder.id);

      expect((await repository.add('/music')).isDuplicate, isFalse);
    });
  });

  group('MusicFolderRepository.normalisePath', () {
    test('trims, resolves traversal and drops a trailing separator', () {
      expect(
        p.equals(
          MusicFolderRepository.normalisePath('  /music/rock/  '),
          '/music/rock',
        ),
        isTrue,
      );
      expect(
        p.equals(
          MusicFolderRepository.normalisePath('/music/jazz/../rock'),
          '/music/rock',
        ),
        isTrue,
      );
    });
  });
}
