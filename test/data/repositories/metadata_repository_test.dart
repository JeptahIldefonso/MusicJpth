import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/data/database/database.dart';
import 'package:music_oasis/data/models/discovered_file.dart';
import 'package:music_oasis/data/models/track_metadata.dart';
import 'package:music_oasis/data/repositories/metadata_repository.dart';
import 'package:music_oasis/data/repositories/song_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DiscoveredFile _file(String path) =>
    DiscoveredFile(path: path, format: '.mp3', size: 100, modifiedMs: 1000);

void main() {
  setUpAll(sqfliteFfiInit);

  group('MetadataRepository', () {
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

    /// Indexes [paths] the way a scan would, so there is a row to tag.
    Future<void> index(List<String> paths) =>
        songs.syncBatch(paths.map(_file).toList(growable: false));

    Future<List<Map<String, Object?>>> songRows() => db.rawQuery(
      'SELECT s.path, s.title, s.duration, s.track_number, s.disc_number, '
      's.genre, s.year, s.artist_id, s.album_id, ar.name AS artist, '
      'al.title AS album, al.year AS album_year '
      'FROM songs s '
      'LEFT JOIN artists ar ON ar.id = s.artist_id '
      'LEFT JOIN albums al ON al.id = s.album_id '
      'ORDER BY s.path',
    );

    Future<int> countOf(String table) async =>
        (await db.rawQuery('SELECT COUNT(*) AS n FROM $table')).first['n']!
            as int;

    test('an empty batch touches nothing', () async {
      expect(
        await metadata.apply(const <TrackMetadata>[]),
        MetadataSyncCounts.none,
      );
      expect(await countOf('artists'), 0);
    });

    test('writes every tag, creating the artist and album', () async {
      await index(<String>['/m/a.mp3']);

      final MetadataSyncCounts counts = await metadata.apply(<TrackMetadata>[
        const TrackMetadata(
          path: '/m/a.mp3',
          title: 'Stan',
          artist: 'Eminem',
          album: 'The Marshall Mathers LP',
          genre: 'Hip-Hop',
          year: 2000,
          trackNumber: 3,
          discNumber: 1,
          durationMs: 404000,
        ),
      ]);

      expect(counts.tagged, 1);
      expect(counts.artistsCreated, 1);
      expect(counts.albumsCreated, 1);

      final Map<String, Object?> row = (await songRows()).single;
      expect(row['title'], 'Stan');
      expect(row['artist'], 'Eminem');
      expect(row['album'], 'The Marshall Mathers LP');
      expect(row['genre'], 'Hip-Hop');
      expect(row['year'], 2000);
      expect(row['track_number'], 3);
      expect(row['disc_number'], 1);
      expect(row['duration'], 404000);
      expect(row['album_year'], 2000);
    });

    test('an album shares one artist row and one album row', () async {
      await index(<String>['/m/1.mp3', '/m/2.mp3', '/m/3.mp3']);

      final MetadataSyncCounts counts = await metadata.apply(<TrackMetadata>[
        const TrackMetadata(
          path: '/m/1.mp3',
          artist: 'Portishead',
          album: 'Dummy',
          trackNumber: 1,
        ),
        const TrackMetadata(
          path: '/m/2.mp3',
          artist: 'Portishead',
          album: 'Dummy',
          trackNumber: 2,
        ),
        const TrackMetadata(
          path: '/m/3.mp3',
          artist: 'Portishead',
          album: 'Dummy',
          trackNumber: 3,
        ),
      ]);

      expect(counts.tagged, 3);
      expect(counts.artistsCreated, 1);
      expect(counts.albumsCreated, 1);
      expect(await countOf('artists'), 1);
      expect(await countOf('albums'), 1);
    });

    test('the same album title by two artists stays two albums', () async {
      await index(<String>['/m/a.mp3', '/m/b.mp3']);

      final MetadataSyncCounts counts = await metadata.apply(<TrackMetadata>[
        const TrackMetadata(
          path: '/m/a.mp3',
          artist: 'Queen',
          album: 'Greatest Hits',
        ),
        const TrackMetadata(
          path: '/m/b.mp3',
          artist: 'ABBA',
          album: 'Greatest Hits',
        ),
      ]);

      expect(counts.albumsCreated, 2);
      expect(await countOf('albums'), 2);
    });

    test('an album with no artist is found again, not re-inserted', () async {
      await index(<String>['/m/a.mp3', '/m/b.mp3']);

      // SQLite treats NULLs in a unique index as distinct, so a null artist has
      // to be matched with an explicit `IS NULL` or every scan inserts the album
      // again.
      await metadata.apply(<TrackMetadata>[
        const TrackMetadata(path: '/m/a.mp3', album: 'Field Recordings'),
      ]);
      final MetadataSyncCounts second = await metadata.apply(<TrackMetadata>[
        const TrackMetadata(path: '/m/b.mp3', album: 'Field Recordings'),
      ]);

      expect(second.albumsCreated, 0);
      expect(await countOf('albums'), 1);
      expect(await countOf('artists'), 0);
    });

    test('an album year is filled in once and never overwritten', () async {
      await index(<String>['/m/a.mp3', '/m/b.mp3', '/m/c.mp3']);

      // Track one carries no year, track two supplies it, track three disagrees:
      // a compilation must not have its year rewritten track by track.
      await metadata.apply(<TrackMetadata>[
        const TrackMetadata(path: '/m/a.mp3', artist: 'V/A', album: 'Now 12'),
      ]);
      expect((await songRows()).first['album_year'], isNull);

      await metadata.apply(<TrackMetadata>[
        const TrackMetadata(
          path: '/m/b.mp3',
          artist: 'V/A',
          album: 'Now 12',
          year: 1988,
        ),
      ]);
      await metadata.apply(<TrackMetadata>[
        const TrackMetadata(
          path: '/m/c.mp3',
          artist: 'V/A',
          album: 'Now 12',
          year: 1975,
        ),
      ]);

      final List<Map<String, Object?>> rows = await songRows();
      expect(rows.map((Map<String, Object?> r) => r['album_year']), <int>[
        1988,
        1988,
        1988,
      ]);
      // The song keeps its own year even where it differs from the album's.
      expect(rows.last['year'], 1975);
    });

    test('an untagged track keeps its filename and no lookup rows', () async {
      await index(<String>['/m/Some Track.mp3']);

      final MetadataSyncCounts counts = await metadata.apply(<TrackMetadata>[
        const TrackMetadata.unknown('/m/Some Track.mp3'),
      ]);

      expect(counts.tagged, 1);
      final Map<String, Object?> row = (await songRows()).single;
      expect(row['title'], 'Some Track');
      // No invented "Unknown Artist": that would merge unrelated songs, and the
      // wording belongs to the UI.
      expect(row['artist_id'], isNull);
      expect(row['album_id'], isNull);
      expect(await countOf('artists'), 0);
      expect(await countOf('albums'), 0);
    });

    test('a blank title falls back to the filename', () async {
      await index(<String>['/m/Fallback.mp3']);

      await metadata.apply(<TrackMetadata>[
        const TrackMetadata(path: '/m/Fallback.mp3', artist: 'Someone'),
      ]);

      expect((await songRows()).single['title'], 'Fallback');
    });

    test('applying the same tags twice changes nothing further', () async {
      await index(<String>['/m/a.mp3']);
      const List<TrackMetadata> tags = <TrackMetadata>[
        TrackMetadata(
          path: '/m/a.mp3',
          title: 'Teardrop',
          artist: 'Massive Attack',
          album: 'Mezzanine',
          year: 1998,
        ),
      ];

      await metadata.apply(tags);
      final List<Map<String, Object?>> first = await songRows();
      final MetadataSyncCounts second = await metadata.apply(tags);

      expect(second.artistsCreated, 0);
      expect(second.albumsCreated, 0);
      expect(await countOf('artists'), 1);
      expect(await countOf('albums'), 1);
      expect(await songRows(), first);
    });

    test('a tag removed from a file clears the stored value', () async {
      await index(<String>['/m/a.mp3']);
      await metadata.apply(<TrackMetadata>[
        const TrackMetadata(
          path: '/m/a.mp3',
          title: 'Old',
          genre: 'Rock',
          year: 1990,
        ),
      ]);

      await metadata.apply(<TrackMetadata>[
        const TrackMetadata(path: '/m/a.mp3', title: 'New'),
      ]);

      final Map<String, Object?> row = (await songRows()).single;
      expect(row['title'], 'New');
      expect(row['genre'], isNull);
      expect(row['year'], isNull);
    });

    test('a song that is no longer indexed is skipped, not inserted', () async {
      await index(<String>['/m/a.mp3']);

      final MetadataSyncCounts counts = await metadata.apply(<TrackMetadata>[
        const TrackMetadata(path: '/m/a.mp3', title: 'Here'),
        const TrackMetadata(path: '/m/gone.mp3', title: 'Vanished'),
      ]);

      expect(counts.tagged, 1);
      expect(await countOf('songs'), 1);
    });

    test('counts add up across batches', () async {
      const MetadataSyncCounts a = MetadataSyncCounts(
        tagged: 2,
        artistsCreated: 1,
        albumsCreated: 1,
      );
      const MetadataSyncCounts b = MetadataSyncCounts(tagged: 3);

      expect(
        a + b,
        const MetadataSyncCounts(
          tagged: 5,
          artistsCreated: 1,
          albumsCreated: 1,
        ),
      );
    });
  });
}
