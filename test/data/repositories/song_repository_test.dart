import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/core/utils/music_paths.dart';
import 'package:music_oasis/data/database/database.dart';
import 'package:music_oasis/data/database/tables/songs_table.dart';
import 'package:music_oasis/data/models/discovered_file.dart';
import 'package:music_oasis/data/models/song.dart';
import 'package:music_oasis/data/repositories/song_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DiscoveredFile _file(
  String path, {
  String format = 'mp3',
  int size = 100,
  int modifiedMs = 1000,
}) => DiscoveredFile(
  path: MusicPaths.normalise(path),
  format: format,
  size: size,
  modifiedMs: modifiedMs,
);

void main() {
  setUpAll(sqfliteFfiInit);

  group('SongRepository', () {
    late AppDatabase appDatabase;
    late Database db;
    late SongRepository repository;

    setUp(() async {
      appDatabase = AppDatabase(
        factoryOverride: databaseFactoryFfi,
        pathResolverOverride: () async => inMemoryDatabasePath,
      );
      db = await appDatabase.open();
      repository = SongRepository(db);
    });

    tearDown(() => appDatabase.close());

    Future<Map<String, Object?>> rowFor(String path) async {
      final List<Map<String, Object?>> rows = await db.query(
        SongsTable.name,
        where: '${SongsTable.path} = ?',
        whereArgs: <Object?>[MusicPaths.normalise(path)],
      );
      return rows.single;
    }

    test('starts empty', () async {
      expect(await repository.count(), 0);
    });

    test('an empty batch writes nothing', () async {
      expect(
        await repository.syncBatch(<DiscoveredFile>[]),
        SongSyncCounts.none,
      );
      expect(await repository.count(), 0);
    });

    test('inserts newly discovered files', () async {
      final SongSyncCounts counts = await repository.syncBatch(<DiscoveredFile>[
        _file('/music/a.mp3'),
        _file('/music/b.flac', format: 'flac'),
      ]);

      expect(counts, const SongSyncCounts(added: 2));
      expect(await repository.count(), 2);
    });

    test('stores path, format, size, mtime and a filename title', () async {
      await repository.syncBatch(<DiscoveredFile>[
        _file('/music/rock/Lose Yourself.mp3', size: 4242, modifiedMs: 99),
      ]);

      final Map<String, Object?> row = await rowFor(
        '/music/rock/Lose Yourself.mp3',
      );
      expect(row[SongsTable.title], 'Lose Yourself');
      expect(row[SongsTable.format], 'mp3');
      expect(row[SongsTable.fileSize], 4242);
      expect(row[SongsTable.modifiedTime], 99);
      expect(row[SongsTable.dateAdded], isA<int>());
    });

    test('a repeated scan of unchanged files changes nothing', () async {
      final List<DiscoveredFile> batch = <DiscoveredFile>[
        _file('/music/a.mp3'),
        _file('/music/b.mp3'),
      ];
      await repository.syncBatch(batch);
      final Object? addedAt = (await rowFor(
        '/music/a.mp3',
      ))[SongsTable.dateAdded];

      final SongSyncCounts second = await repository.syncBatch(batch);

      expect(second, SongSyncCounts.none);
      expect(await repository.count(), 2);
      expect((await rowFor('/music/a.mp3'))[SongsTable.dateAdded], addedAt);
    });

    test('the same file twice in one batch is stored once', () async {
      final SongSyncCounts counts = await repository.syncBatch(<DiscoveredFile>[
        _file('/music/a.mp3'),
        _file('/music/a.mp3'),
      ]);

      expect(await repository.count(), 1);
      // Both were treated as new; the unique index kept one row.
      expect(counts.added, 2);
    });

    test('updates a file whose size changed', () async {
      await repository.syncBatch(<DiscoveredFile>[_file('/music/a.mp3')]);

      final SongSyncCounts counts = await repository.syncBatch(<DiscoveredFile>[
        _file('/music/a.mp3', size: 200),
      ]);

      expect(counts, const SongSyncCounts(updated: 1));
      expect((await rowFor('/music/a.mp3'))[SongsTable.fileSize], 200);
      expect(await repository.count(), 1);
    });

    test('updates a file whose modified time changed', () async {
      await repository.syncBatch(<DiscoveredFile>[_file('/music/a.mp3')]);

      final SongSyncCounts counts = await repository.syncBatch(<DiscoveredFile>[
        _file('/music/a.mp3', modifiedMs: 5000),
      ]);

      expect(counts, const SongSyncCounts(updated: 1));
      expect((await rowFor('/music/a.mp3'))[SongsTable.modifiedTime], 5000);
    });

    test('an update keeps the row and its date_added', () async {
      await repository.syncBatch(<DiscoveredFile>[_file('/music/a.mp3')]);
      final Map<String, Object?> before = await rowFor('/music/a.mp3');

      await repository.syncBatch(<DiscoveredFile>[
        _file('/music/a.mp3', size: 7),
      ]);

      final Map<String, Object?> after = await rowFor('/music/a.mp3');
      expect(after[SongsTable.id], before[SongsTable.id]);
      expect(after[SongsTable.dateAdded], before[SongsTable.dateAdded]);
    });

    test('handles a batch larger than the bound-variable limit', () async {
      final List<DiscoveredFile> batch = List<DiscoveredFile>.generate(
        1200,
        (int index) => _file('/music/song$index.mp3'),
        growable: false,
      );

      expect(
        await repository.syncBatch(batch),
        const SongSyncCounts(added: 1200),
      );
      expect(await repository.count(), 1200);
      // The second pass proves the chunked lookup found every existing row.
      expect(await repository.syncBatch(batch), SongSyncCounts.none);
    });

    group('markMissing', () {
      test('marks songs under a scanned root that were not seen', () async {
        await repository.syncBatch(<DiscoveredFile>[
          _file('/music/kept.mp3'),
          _file('/music/gone.mp3'),
        ]);

        final int marked = await repository.markMissing(
          roots: <String>['/music'],
          seenKeys: <String>{MusicPaths.key('/music/kept.mp3')},
        );

        expect(marked, 1);
        // The row survives — deleting it would take the user's playlist
        // entries, favorites and history with it (`PROJECT.md` §12).
        expect(await repository.count(), 2);
        expect(await repository.availableCount(), 1);
        expect((await rowFor('/music/gone.mp3'))[SongsTable.isAvailable], 0);
        expect((await rowFor('/music/kept.mp3'))[SongsTable.isAvailable], 1);
      });

      test('keeps songs outside the scanned roots available', () async {
        await repository.syncBatch(<DiscoveredFile>[
          _file('/music/a.mp3'),
          _file('/podcasts/b.mp3'),
        ]);

        final int marked = await repository.markMissing(
          roots: <String>['/music'],
          seenKeys: <String>{MusicPaths.key('/music/a.mp3')},
        );

        expect(marked, 0);
        expect(await repository.availableCount(), 2);
      });

      test('keeps songs in a sibling folder with a shared prefix', () async {
        await repository.syncBatch(<DiscoveredFile>[_file('/musicals/b.mp3')]);

        expect(
          await repository.markMissing(
            roots: <String>['/music'],
            seenKeys: <String>{},
          ),
          0,
        );
        expect(await repository.availableCount(), 1);
      });

      test('marks nothing when no root was scanned', () async {
        await repository.syncBatch(<DiscoveredFile>[_file('/music/a.mp3')]);

        expect(
          await repository.markMissing(roots: <String>[], seenKeys: <String>{}),
          0,
        );
        expect(await repository.availableCount(), 1);
      });

      test('marks a scanned root whose files all vanished', () async {
        await repository.syncBatch(<DiscoveredFile>[
          _file('/music/a.mp3'),
          _file('/music/b.mp3'),
        ]);

        expect(
          await repository.markMissing(
            roots: <String>['/music'],
            seenKeys: <String>{},
          ),
          2,
        );
        expect(await repository.count(), 2);
        expect(await repository.availableCount(), 0);
      });

      test('pages through a library larger than one page', () async {
        final List<DiscoveredFile> batch = List<DiscoveredFile>.generate(
          1200,
          (int index) => _file('/music/song$index.mp3'),
          growable: false,
        );
        await repository.syncBatch(batch);

        // Every other file survives, so pages contain a mix of both outcomes.
        final Set<String> seen = <String>{
          for (int index = 0; index < 1200; index += 2)
            MusicPaths.key('/music/song$index.mp3'),
        };

        expect(
          await repository.markMissing(
            roots: <String>['/music'],
            seenKeys: seen,
          ),
          600,
        );
        expect(await repository.count(), 1200);
        expect(await repository.availableCount(), 600);
      });

      test(
        'a second reconciliation with the same input marks nothing',
        () async {
          await repository.syncBatch(<DiscoveredFile>[
            _file('/music/a.mp3'),
            _file('/music/gone.mp3'),
          ]);
          final Set<String> seen = <String>{MusicPaths.key('/music/a.mp3')};

          expect(
            await repository.markMissing(
              roots: <String>['/music'],
              seenKeys: seen,
            ),
            1,
          );
          // Already-unavailable rows are skipped by the page query, so a repeat
          // scan neither counts nor rewrites them.
          expect(
            await repository.markMissing(
              roots: <String>['/music'],
              seenKeys: seen,
            ),
            0,
          );
          expect(await repository.availableCount(), 1);
        },
      );

      test('matches paths by platform case rules', () async {
        await repository.syncBatch(<DiscoveredFile>[_file('/Music/A.mp3')]);

        final int marked = await repository.markMissing(
          roots: <String>['/Music'],
          seenKeys: <String>{MusicPaths.key('/music/a.mp3')},
        );

        // Windows sees one file under two spellings; Linux sees two files.
        expect(marked, p.style == p.Style.windows ? 0 : 1);
      });

      test('a file that comes back becomes available again', () async {
        // The whole point of marking instead of deleting: everything attached to
        // the song is still attached when the file returns.
        await repository.syncBatch(<DiscoveredFile>[_file('/music/a.mp3')]);
        final int id = (await rowFor('/music/a.mp3'))[SongsTable.id]! as int;
        await repository.markMissing(
          roots: <String>['/music'],
          seenKeys: <String>{},
        );

        final SongSyncCounts counts = await repository.syncBatch(
          <DiscoveredFile>[_file('/music/a.mp3')],
        );

        expect(counts, const SongSyncCounts(restored: 1));
        final Map<String, Object?> row = await rowFor('/music/a.mp3');
        expect(row[SongsTable.isAvailable], 1);
        // Same row, so the playlist entries and history pointing at it hold.
        expect(row[SongsTable.id], id);
      });

      test('a changed file that comes back is restored and updated', () async {
        await repository.syncBatch(<DiscoveredFile>[_file('/music/a.mp3')]);
        await repository.markMissing(
          roots: <String>['/music'],
          seenKeys: <String>{},
        );

        final List<String> changed = <String>[];
        final SongSyncCounts counts = await repository.syncBatch(
          <DiscoveredFile>[_file('/music/a.mp3', size: 999)],
          changedPaths: changed,
        );

        expect(counts, const SongSyncCounts(updated: 1, restored: 1));
        expect((await rowFor('/music/a.mp3'))[SongsTable.isAvailable], 1);
        // It changed on disk, so its tags are worth re-reading.
        expect(changed, <String>[MusicPaths.normalise('/music/a.mp3')]);
      });

      test(
        'an unchanged available file is neither written nor re-read',
        () async {
          await repository.syncBatch(<DiscoveredFile>[_file('/music/a.mp3')]);

          final List<String> changed = <String>[];
          final SongSyncCounts counts = await repository.syncBatch(
            <DiscoveredFile>[_file('/music/a.mp3')],
            changedPaths: changed,
          );

          expect(counts, SongSyncCounts.none);
          expect(changed, isEmpty);
        },
      );

      test('a restored file does not have its tags re-read', () async {
        // Byte-for-byte the same file, so the tags already stored are still
        // right: restoring availability must not cost a parse
        // (`REQUIREMENTS.md` §31).
        await repository.syncBatch(<DiscoveredFile>[_file('/music/a.mp3')]);
        await repository.markMissing(
          roots: <String>['/music'],
          seenKeys: <String>{},
        );

        final List<String> changed = <String>[];
        await repository.syncBatch(<DiscoveredFile>[
          _file('/music/a.mp3'),
        ], changedPaths: changed);

        expect(changed, isEmpty);
      });
    });
  });

  group('SongSyncCounts', () {
    test('adds up batch by batch', () {
      expect(
        const SongSyncCounts(added: 1, updated: 2) +
            const SongSyncCounts(added: 3, restored: 4),
        const SongSyncCounts(added: 4, updated: 2, restored: 4),
      );
    });

    test('is a value', () {
      expect(const SongSyncCounts(added: 1), const SongSyncCounts(added: 1));
      expect(
        const SongSyncCounts(added: 1).hashCode,
        const SongSyncCounts(added: 1).hashCode,
      );
      expect(SongSyncCounts.none, const SongSyncCounts());
    });
  });

  group('SongRepository.page (keyset)', () {
    late AppDatabase appDatabase;
    late Database db;
    late SongRepository repository;

    setUp(() async {
      appDatabase = AppDatabase(
        factoryOverride: databaseFactoryFfi,
        pathResolverOverride: () async => inMemoryDatabasePath,
      );
      db = await appDatabase.open();
      repository = SongRepository(db);
    });

    tearDown(() => appDatabase.close());

    Future<void> seed() async {
      await repository.syncBatch(<DiscoveredFile>[
        _file('/music/1.mp3'),
        _file('/music/2.mp3'),
        _file('/music/3.mp3'),
        _file('/music/4.mp3'),
        _file('/music/5.mp3'),
      ]);
      // Titles chosen to exercise ordering: two case-variants of the same
      // name, one plain, one unavailable.
      Future<void> title(String path, String t, {bool available = true}) async {
        final rows = await db.query(
          SongsTable.name,
          columns: <String>[SongsTable.id],
          where: '${SongsTable.path} = ?',
          whereArgs: <Object?>[MusicPaths.normalise(path)],
        );
        await db.update(
          SongsTable.name,
          <String, Object?>{
            SongsTable.title: t,
            SongsTable.isAvailable: available ? 1 : 0,
          },
          where: '${SongsTable.id} = ?',
          whereArgs: <Object?>[rows.single[SongsTable.id]],
        );
      }

      await title('/music/1.mp3', 'alpha');
      await title('/music/2.mp3', 'Alpha'); // same NOCASE key as alpha
      await title('/music/3.mp3', 'bravo');
      await title('/music/4.mp3', 'charlie');
      await title('/music/5.mp3', 'delta', available: false);
    }

    test(
      'pages in browse order with no skips or repeats across cursors',
      () async {
        await seed();

        final List<String> seen = <String>[];
        LibraryCursor? cursor;
        int pages = 0;
        while (pages < 10) {
          final List<Song> page = await repository.page(
            limit: 2,
            after: cursor,
          );
          if (page.isEmpty) break;
          pages++;
          seen.addAll(page.map((Song s) => s.title));
          cursor = LibraryCursor.fromSong(page.last);
        }

        expect(seen, <String>['alpha', 'Alpha', 'bravo', 'charlie', 'delta']);
        expect(cursor!.available, isFalse); // ended on the unavailable tail
        expect(pages, lessThan(10)); // terminated
      },
    );

    test('a short page marks the end without an extra count query', () async {
      await seed();

      final List<Song> only = await repository.page(limit: 100);
      expect(only, hasLength(5));

      final next = await repository.page(
        limit: 100,
        after: LibraryCursor.fromSong(only.last),
      );
      expect(next, isEmpty);
    });

    test('the browse order is served by the composite index', () async {
      final plan = await db.rawQuery(
        'EXPLAIN QUERY PLAN '
        'SELECT id FROM ${SongsTable.name} '
        'ORDER BY is_available DESC, title COLLATE NOCASE ASC, id ASC',
      );
      final String detail = plan
          .map((row) => row['detail'].toString())
          .join(' ');
      expect(detail, contains('idx_songs_library_order'));
    });
  });
}
