import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/data/database/database.dart';
import 'package:music_oasis/data/database/tables/songs_table.dart';
import 'package:music_oasis/data/models/discovered_file.dart';
import 'package:music_oasis/data/models/music_folder.dart';
import 'package:music_oasis/data/models/track_metadata.dart';
import 'package:music_oasis/data/repositories/metadata_repository.dart';
import 'package:music_oasis/data/repositories/music_folder_repository.dart';
import 'package:music_oasis/data/repositories/song_repository.dart';
import 'package:music_oasis/services/artwork/artwork_cache_service.dart';
import 'package:music_oasis/services/metadata/metadata_service.dart';
import 'package:music_oasis/services/permissions/media_permission_service.dart';
import 'package:music_oasis/services/permissions/storage_access_service.dart';
import 'package:music_oasis/services/scanner/file_discovery.dart';
import 'package:music_oasis/services/scanner/music_scanner_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeGate implements MediaPermissionGate {
  _FakeGate(this.access);

  final MediaAccess access;
  int calls = 0;
  int settingsOpened = 0;

  @override
  Future<MediaAccess> ensureAudioAccess() async {
    calls++;
    return access;
  }

  @override
  Future<bool> openSystemSettings() async {
    settingsOpened++;
    return true;
  }
}

/// Reports [result] for every folder except those listed in [readable].
class _FakeAccess implements StorageAccessService {
  const _FakeAccess({
    this.result = FolderAccess.readable,
    this.readable = const <String>{},
  });

  final FolderAccess result;
  final Set<String> readable;

  @override
  Future<FolderAccess> check(String path) async =>
      readable.contains(path) ? FolderAccess.readable : result;
}

/// Stands in for the isolate-backed tag reader: records what it was asked to
/// parse and answers from [tags], so no test needs a real encoded audio file.
class _RecordingReader {
  final Map<String, TrackMetadata> tags = <String, TrackMetadata>{};
  final List<String> requested = <String>[];

  MetadataService get service => MetadataService(runnerOverride: _read);

  Future<List<TrackMetadata>> _read(List<String> paths) async {
    requested.addAll(paths);
    return paths
        .map((String path) => tags[path] ?? TrackMetadata.unknown(path))
        .toList(growable: false);
  }
}

File _write(Directory root, String relative, {int bytes = 3}) {
  final File file = File(p.join(root.path, relative));
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(List<int>.filled(bytes, 0));
  return file;
}

Directory _tempDir() {
  final Directory directory = Directory.systemTemp.createTempSync(
    'music_oasis_scanner',
  );
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return directory;
}

void main() {
  setUpAll(sqfliteFfiInit);

  group('MusicScannerService', () {
    late AppDatabase appDatabase;
    late Database db;
    late MusicFolderRepository folders;
    late SongRepository songs;
    late MetadataRepository metadata;
    late _RecordingReader reader;

    setUp(() async {
      appDatabase = AppDatabase(
        factoryOverride: databaseFactoryFfi,
        pathResolverOverride: () async => inMemoryDatabasePath,
      );
      db = await appDatabase.open();
      folders = MusicFolderRepository(db);
      songs = SongRepository(db);
      metadata = MetadataRepository(db);
      reader = _RecordingReader();
    });

    tearDown(() => appDatabase.close());

    MusicScannerService scanner({
      MediaPermissionGate? permissions,
      StorageAccessService access = const _FakeAccess(),
      int chunkSize = 2,
      ArtworkCacheService? artwork,
    }) => MusicScannerService(
      folders: folders,
      songs: songs,
      metadata: metadata,
      permissions: permissions ?? _FakeGate(MediaAccess.granted),
      access: access,
      reader: reader.service,
      chunkSize: chunkSize,
      artwork: artwork,
    );

    test(
      'is blocked, and asks for nothing, when no folder is watched',
      () async {
        final _FakeGate gate = _FakeGate(MediaAccess.granted);

        final List<ScanUpdate> updates = await scanner(permissions: gate)
            .scan()
            .toList();

        expect(updates, hasLength(1));
        expect(
          (updates.single as ScanBlocked).reason,
          ScanBlockReason.noFolders,
        );
        // Nothing to scan means nothing to ask for (`REQUIREMENTS.md` §36).
        expect(gate.calls, 0);
      },
    );

    test('is blocked when permission is denied, and writes nothing', () async {
      final Directory root = _tempDir();
      _write(root, 'song.mp3');
      await folders.add(root.path);

      final List<ScanUpdate> updates = await scanner(
        permissions: _FakeGate(MediaAccess.denied),
      ).scan().toList();

      expect(
        (updates.single as ScanBlocked).reason,
        ScanBlockReason.permissionDenied,
      );
      expect(await songs.count(), 0);
    });

    test('distinguishes a permanent denial', () async {
      final Directory root = _tempDir();
      await folders.add(root.path);

      final List<ScanUpdate> updates = await scanner(
        permissions: _FakeGate(MediaAccess.permanentlyDenied),
      ).scan().toList();

      expect(
        (updates.single as ScanBlocked).reason,
        ScanBlockReason.permissionPermanentlyDenied,
      );
    });

    test('is blocked when every watched folder is unreadable', () async {
      final Directory root = _tempDir();
      _write(root, 'song.mp3');
      await folders.add(root.path);

      final List<ScanUpdate> updates = await scanner(
        access: const _FakeAccess(result: FolderAccess.missing),
      ).scan().toList();

      expect(
        (updates.single as ScanBlocked).reason,
        ScanBlockReason.foldersUnreadable,
      );
      expect(await songs.count(), 0);
    });

    test(
      'indexes an empty folder as a finished scan with nothing found',
      () async {
        final Directory root = _tempDir();
        await folders.add(root.path);

        final ScanUpdate last = (await scanner().scan().toList()).last;

        expect(last, isA<ScanFinished>());
        expect((last as ScanFinished).found, 0);
        expect(last.added, 0);
        expect(await songs.count(), 0);
      },
    );

    test('indexes nested folders and skips unsupported files', () async {
      final Directory root = _tempDir();
      _write(root, 'top.mp3');
      _write(root, p.join('album', 'track.flac'));
      _write(root, p.join('album', 'disc 2', 'deep.opus'));
      _write(root, p.join('album', 'cover.jpg'));
      await folders.add(root.path);

      final ScanFinished finished =
          (await scanner().scan().toList()).last as ScanFinished;

      expect(finished.found, 3);
      expect(finished.added, 3);
      expect(finished.missing, 0);
      expect(await songs.count(), 3);
    });

    test('reports progress per batch, not per file', () async {
      final Directory root = _tempDir();
      for (int index = 0; index < 6; index++) {
        _write(root, 'song$index.mp3');
      }
      await folders.add(root.path);

      final List<ScanUpdate> updates = await scanner(chunkSize: 2)
          .scan()
          .toList();
      final List<ScanProgress> progress = updates
          .whereType<ScanProgress>()
          .toList();

      expect(progress, hasLength(3));
      expect(progress.map((ScanProgress p) => p.found), <int>[2, 4, 6]);
      expect(progress.last.added, 6);
    });

    test('scans every watched folder', () async {
      final Directory first = _tempDir();
      final Directory second = _tempDir();
      _write(first, 'a.mp3');
      _write(second, p.join('nested', 'b.wav'));
      await folders.add(first.path);
      await folders.add(second.path);

      final ScanFinished finished =
          (await scanner().scan().toList()).last as ScanFinished;

      expect(finished.found, 2);
      expect(await songs.count(), 2);
    });

    test('a repeated scan of an unchanged folder changes nothing', () async {
      final Directory root = _tempDir();
      _write(root, 'a.mp3');
      _write(root, 'b.mp3');
      await folders.add(root.path);
      await scanner().scan().toList();

      final ScanFinished second =
          (await scanner().scan().toList()).last as ScanFinished;

      expect(second.found, 2);
      expect(second.added, 0);
      expect(second.updated, 0);
      expect(second.missing, 0);
      expect(await songs.count(), 2);
    });

    test('reads tags for what changed, and for nothing else', () async {
      final Directory root = _tempDir();
      final File a = _write(root, 'a.mp3');
      final File b = _write(root, 'b.mp3');
      await folders.add(root.path);

      final ScanFinished first =
          (await scanner().scan().toList()).last as ScanFinished;

      expect(reader.requested, unorderedEquals(<String>[a.path, b.path]));
      expect(first.tagged, 2);

      // Nothing changed on disk, so a repeat scan must open no audio file at
      // all (`REQUIREMENTS.md` §31: no repeated metadata parsing).
      reader.requested.clear();
      final ScanFinished second =
          (await scanner().scan().toList()).last as ScanFinished;

      expect(reader.requested, isEmpty);
      expect(second.tagged, 0);

      // A file that changed is worth re-reading; its unchanged neighbour is not.
      b.writeAsBytesSync(List<int>.filled(500, 1));
      final ScanFinished third =
          (await scanner().scan().toList()).last as ScanFinished;

      expect(reader.requested, <String>[b.path]);
      expect(third.tagged, 1);
    });

    test('stores the tags it read, with their artist and album', () async {
      final Directory root = _tempDir();
      final File file = _write(root, 'a.mp3');
      reader.tags[file.path] = TrackMetadata(
        path: file.path,
        title: 'Lose Yourself',
        artist: 'Eminem',
        album: '8 Mile',
        genre: 'Hip-Hop',
        year: 2002,
        trackNumber: 1,
        discNumber: 1,
        durationMs: 326000,
      );
      await folders.add(root.path);

      await scanner().scan().toList();

      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT s.title, s.duration, s.track_number, s.disc_number, s.genre, '
        's.year, ar.name AS artist, al.title AS album '
        'FROM songs s '
        'LEFT JOIN artists ar ON ar.id = s.artist_id '
        'LEFT JOIN albums al ON al.id = s.album_id',
      );

      expect(rows, hasLength(1));
      expect(rows.single['title'], 'Lose Yourself');
      expect(rows.single['artist'], 'Eminem');
      expect(rows.single['album'], '8 Mile');
      expect(rows.single['genre'], 'Hip-Hop');
      expect(rows.single['year'], 2002);
      expect(rows.single['track_number'], 1);
      expect(rows.single['disc_number'], 1);
      expect(rows.single['duration'], 326000);
    });

    test('falls back to the filename when a file carries no tags', () async {
      final Directory root = _tempDir();
      _write(root, 'Untagged Song.mp3');
      await folders.add(root.path);

      await scanner().scan().toList();

      final List<Map<String, Object?>> rows = await db.query(
        'songs',
        columns: <String>['title', 'artist_id', 'album_id'],
      );

      expect(rows.single['title'], 'Untagged Song');
      // No invented "Unknown Artist" row: the wording belongs to the UI.
      expect(rows.single['artist_id'], isNull);
      expect(rows.single['album_id'], isNull);
    });

    test('picks up a new file on the next scan', () async {
      final Directory root = _tempDir();
      _write(root, 'a.mp3');
      await folders.add(root.path);
      await scanner().scan().toList();

      _write(root, 'b.mp3');
      final ScanFinished second =
          (await scanner().scan().toList()).last as ScanFinished;

      expect(second.added, 1);
      expect(await songs.count(), 2);
    });

    test('updates a file that changed on disk', () async {
      final Directory root = _tempDir();
      final File file = _write(root, 'a.mp3');
      await folders.add(root.path);
      await scanner().scan().toList();

      file.writeAsBytesSync(List<int>.filled(500, 1));
      final ScanFinished second =
          (await scanner().scan().toList()).last as ScanFinished;

      expect(second.updated, 1);
      expect(second.added, 0);
      expect(await songs.count(), 1);
    });

    test('marks a file that disappeared from a scanned folder', () async {
      final Directory root = _tempDir();
      _write(root, 'a.mp3');
      final File gone = _write(root, 'b.mp3');
      await folders.add(root.path);
      await scanner().scan().toList();

      gone.deleteSync();
      final ScanFinished second =
          (await scanner().scan().toList()).last as ScanFinished;

      expect(second.missing, 1);
      expect(second.found, 1);
      // Marked, not deleted: the row stays so playlists, favorites and history
      // that reference it survive (`PROJECT.md` §12).
      expect(await songs.count(), 2);
      expect(await songs.availableCount(), 1);
    });

    test('a file that comes back becomes available again', () async {
      final Directory root = _tempDir();
      final File file = _write(root, 'a.mp3');
      await folders.add(root.path);
      await scanner().scan().toList();
      final List<int> bytes = file.readAsBytesSync();

      file.deleteSync();
      expect(
        ((await scanner().scan().toList()).last as ScanFinished).missing,
        1,
      );

      file.writeAsBytesSync(bytes);
      final ScanFinished third =
          (await scanner().scan().toList()).last as ScanFinished;

      expect(third.missing, 0);
      expect(await songs.availableCount(), 1);
    });

    test('an unreadable folder changes no availability', () async {
      final Directory kept = _tempDir();
      final Directory unplugged = _tempDir();
      _write(kept, 'a.mp3');
      _write(unplugged, 'b.mp3');
      await folders.add(kept.path);
      await folders.add(unplugged.path);
      await scanner().scan().toList();
      expect(await songs.count(), 2);

      final ScanFinished second =
          (await scanner(
                access: _FakeAccess(
                  result: FolderAccess.missing,
                  readable: <String>{kept.path},
                ),
              ).scan().toList()).last
              as ScanFinished;

      expect(second.missing, 0);
      expect(second.found, 1);
      // The vanished drive's songs are still indexed and still available: the
      // scan never looked, so it proved nothing about them.
      expect(await songs.count(), 2);
      expect(await songs.availableCount(), 2);
    });

    test('records when each scanned folder was last scanned', () async {
      final Directory root = _tempDir();
      await folders.add(root.path);
      expect((await folders.list()).single.lastScanned, isNull);

      await scanner().scan().toList();

      expect((await folders.list()).single.lastScanned, isNotNull);
    });

    test('does not mark an unreadable folder as scanned', () async {
      final Directory kept = _tempDir();
      final Directory unplugged = _tempDir();
      await folders.add(kept.path);
      await folders.add(unplugged.path);

      await scanner(
        access: _FakeAccess(
          result: FolderAccess.missing,
          readable: <String>{kept.path},
        ),
      ).scan().toList();

      final List<MusicFolder> watched = await folders.list();
      expect(
        watched
            .firstWhere((MusicFolder f) => p.equals(f.path, kept.path))
            .lastScanned,
        isNotNull,
      );
      expect(
        watched
            .firstWhere((MusicFolder f) => p.equals(f.path, unplugged.path))
            .lastScanned,
        isNull,
      );
    });

    test('abandoning the scan early changes no availability', () async {
      final Directory root = _tempDir();
      for (int index = 0; index < 6; index++) {
        _write(root, 'song$index.mp3');
      }
      await folders.add(root.path);
      await scanner().scan().toList();

      // Take one batch and stop: the reconciliation pass never runs, so the
      // four files the scan did not reach stay available. A cancelled scan has
      // not proved that anything is missing.
      final ScanUpdate first = await scanner(chunkSize: 2).scan().first;

      expect(first, isA<ScanProgress>());
      expect(await songs.count(), 6);
      expect(await songs.availableCount(), 6);
    });

    test('a failing discovery surfaces as a stream error', () async {
      final Directory root = _tempDir();
      await folders.add(root.path);
      final MusicScannerService service = MusicScannerService(
        folders: folders,
        songs: songs,
        metadata: metadata,
        permissions: _FakeGate(MediaAccess.granted),
        access: const _FakeAccess(),
        reader: reader.service,
        discovery: FileDiscoveryService(
          runnerOverride: (DiscoveryRequest request) =>
              Stream<List<DiscoveredFile>>.error(
                const FileDiscoveryException('boom'),
              ),
        ),
      );

      expect(service.scan().toList(), throwsA(isA<FileDiscoveryException>()));
    });

    test('backfills artwork for a file the tag pass skips', () async {
      final Directory root = _tempDir();
      final File song = _write(root, 'song.mp3');
      await folders.add(root.path);

      // A first scan with no cache wired leaves the row with no cover — the
      // state a library indexed before cover extraction worked is in.
      await scanner().scan().toList();
      expect(await _artworkPath(db), isNull);

      // The file is now byte-for-byte what the index already holds, so the
      // incremental comparison excludes it from the tag pass. That is exactly
      // why artwork could never come back on its own.
      reader.requested.clear();
      reader.tags[song.path] = TrackMetadata(
        path: song.path,
        title: 'A',
        coverBytes: Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 1, 2, 3]),
      );

      await scanner(
        artwork: ArtworkCacheService(baseDirOverride: _tempDir()),
      ).scan().toList();

      // Opened anyway by the backfill, through the same reader and cache.
      expect(reader.requested, contains(song.path));
      expect(await _artworkPath(db), isNotNull);
    });

    test('the artwork backfill looks at a file once, not every scan', () async {
      final Directory root = _tempDir();
      _write(root, 'song.mp3');
      await folders.add(root.path);
      final ArtworkCacheService cache = ArtworkCacheService(
        baseDirOverride: _tempDir(),
      );

      // No tags registered, so the reader answers "unknown" and no cover is
      // found. The row must still be recorded as examined — otherwise the
      // backfill reopens it on every scan (`REQUIREMENTS.md` §31) and, because
      // it loops until nothing is pending, would never terminate at all.
      await scanner(artwork: cache).scan().toList();

      reader.requested.clear();
      await scanner(artwork: cache).scan().toList();

      expect(reader.requested, isEmpty);
    });
  });
}

/// The single indexed song's stored cover path.
Future<String?> _artworkPath(Database db) async {
  final List<Map<String, Object?>> rows = await db.query(
    SongsTable.name,
    columns: <String>[SongsTable.artworkPath],
  );
  return rows.single[SongsTable.artworkPath] as String?;
}
