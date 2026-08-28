import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/core/utils/music_paths.dart';
import 'package:music_oasis/data/models/discovered_file.dart';
import 'package:music_oasis/services/scanner/file_discovery.dart';
import 'package:path/path.dart' as p;

/// Creates a file (and its folders) inside [root] with deterministic bytes.
File _write(Directory root, String relative, {int bytes = 3}) {
  final File file = File(p.join(root.path, relative));
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(List<int>.filled(bytes, 0));
  return file;
}

Directory _tempDir() {
  final Directory directory = Directory.systemTemp.createTempSync(
    'music_oasis_discovery',
  );
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return directory;
}

List<DiscoveredFile> _walk(DiscoveryRequest request) =>
    discoverAudioFilesSync(request)
        .expand((List<DiscoveredFile> chunk) => chunk)
        .toList();

Set<String> _keys(Iterable<DiscoveredFile> files) =>
    files.map((DiscoveredFile file) => MusicPaths.key(file.path)).toSet();

void main() {
  group('discoverAudioFilesSync', () {
    test('yields nothing for an empty folder', () {
      final Directory root = _tempDir();

      expect(
        discoverAudioFilesSync(DiscoveryRequest(roots: <String>[root.path])),
        isEmpty,
      );
    });

    test('yields nothing for a folder that does not exist', () {
      final Directory root = _tempDir();

      expect(
        discoverAudioFilesSync(
          DiscoveryRequest(roots: <String>[p.join(root.path, 'gone')]),
        ),
        isEmpty,
      );
    });

    test('skips a missing root and still walks the readable one', () {
      final Directory root = _tempDir();
      _write(root, 'song.mp3');

      final List<DiscoveredFile> found = _walk(
        DiscoveryRequest(roots: <String>[p.join(root.path, 'gone'), root.path]),
      );

      expect(found, hasLength(1));
    });

    test('finds supported files at any depth', () {
      final Directory root = _tempDir();
      _write(root, 'top.mp3');
      _write(root, p.join('album', 'track.flac'));
      _write(root, p.join('album', 'disc 2', 'deep.opus'));

      final List<DiscoveredFile> found = _walk(
        DiscoveryRequest(roots: <String>[root.path]),
      );

      expect(
        found.map((DiscoveredFile file) => p.basename(file.path)).toSet(),
        <String>{'top.mp3', 'track.flac', 'deep.opus'},
      );
    });

    test('filters unsupported files out', () {
      final Directory root = _tempDir();
      _write(root, 'song.mp3');
      _write(root, 'cover.jpg');
      _write(root, 'notes.txt');
      _write(root, 'song.mp3.part');
      _write(root, 'extensionless');

      final List<DiscoveredFile> found = _walk(
        DiscoveryRequest(roots: <String>[root.path]),
      );

      expect(found, hasLength(1));
      expect(p.basename(found.single.path), 'song.mp3');
    });

    test('records format, size and modified time from the listing', () {
      final Directory root = _tempDir();
      final File file = _write(root, 'song.FLAC', bytes: 17);

      final DiscoveredFile found = _walk(
        DiscoveryRequest(roots: <String>[root.path]),
      ).single;

      expect(found.format, 'flac');
      expect(found.size, 17);
      expect(found.modifiedMs, file.statSync().modified.millisecondsSinceEpoch);
    });

    test('normalises the reported path', () {
      final Directory root = _tempDir();
      _write(root, p.join('album', 'track.mp3'));

      final DiscoveredFile found = _walk(
        DiscoveryRequest(
          roots: <String>[p.join(root.path, 'album', '..', 'album')],
        ),
      ).single;

      expect(found.path, MusicPaths.normalise(found.path));
      expect(found.path, isNot(contains('..')));
    });

    test('walks several unrelated roots', () {
      final Directory first = _tempDir();
      final Directory second = _tempDir();
      _write(first, 'a.mp3');
      _write(second, p.join('nested', 'b.wav'));

      final List<DiscoveredFile> found = _walk(
        DiscoveryRequest(roots: <String>[first.path, second.path]),
      );

      expect(found, hasLength(2));
    });

    test('reports a file once when roots overlap', () {
      final Directory root = _tempDir();
      _write(root, p.join('album', 'track.mp3'));

      final List<DiscoveredFile> found = _walk(
        DiscoveryRequest(
          roots: <String>[root.path, p.join(root.path, 'album')],
        ),
      );

      expect(found, hasLength(1));
      expect(_keys(found), hasLength(1));
    });

    test('chunks results at the requested size', () {
      final Directory root = _tempDir();
      for (int index = 0; index < 5; index++) {
        _write(root, 'song$index.mp3');
      }

      final List<List<DiscoveredFile>> chunks = discoverAudioFilesSync(
        DiscoveryRequest(roots: <String>[root.path], chunkSize: 2),
      ).toList();

      expect(chunks.map((List<DiscoveredFile> chunk) => chunk.length), <int>[
        2,
        2,
        1,
      ]);
      expect(
        _keys(chunks.expand((List<DiscoveredFile> chunk) => chunk)),
        hasLength(5),
      );
    });

    test('walks lazily, one chunk at a time', () {
      final Directory root = _tempDir();
      _write(root, 'one.mp3');

      final Iterator<List<DiscoveredFile>> chunks = discoverAudioFilesSync(
        DiscoveryRequest(roots: <String>[root.path], chunkSize: 8),
      ).iterator;

      expect(chunks.moveNext(), isTrue);
      expect(chunks.current, hasLength(1));
      expect(chunks.moveNext(), isFalse);
    });
  });

  group('FileDiscoveryService', () {
    test('streams batches from a real isolate', () async {
      final Directory root = _tempDir();
      _write(root, 'a.mp3');
      _write(root, p.join('album', 'b.flac'));
      _write(root, 'cover.jpg');

      final List<List<DiscoveredFile>> batches =
          await const FileDiscoveryService()
              .discover(
                DiscoveryRequest(roots: <String>[root.path], chunkSize: 1),
              )
              .toList();

      expect(batches, hasLength(2));
      expect(
        _keys(batches.expand((List<DiscoveredFile> batch) => batch)),
        hasLength(2),
      );
    });

    test('completes for an empty folder without emitting', () async {
      final Directory root = _tempDir();

      expect(
        await const FileDiscoveryService()
            .discover(DiscoveryRequest(roots: <String>[root.path]))
            .toList(),
        isEmpty,
      );
    });

    test('cancelling the subscription stops the walk', () async {
      final Directory root = _tempDir();
      for (int index = 0; index < 60; index++) {
        _write(root, 'song$index.mp3');
      }

      int batches = 0;
      final StreamSubscription<List<DiscoveredFile>> subscription =
          const FileDiscoveryService()
              .discover(
                DiscoveryRequest(roots: <String>[root.path], chunkSize: 1),
              )
              .listen((List<DiscoveredFile> _) => batches++);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await subscription.cancel();
      final int seenAtCancel = batches;

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(batches, seenAtCancel, reason: 'no batches after cancel');
      expect(seenAtCancel, lessThan(60), reason: 'the walk was cut short');
    });

    test('an injected runner replaces the isolate', () async {
      const DiscoveredFile file = DiscoveredFile(
        path: '/music/song.mp3',
        format: 'mp3',
        size: 1,
        modifiedMs: 2,
      );
      final FileDiscoveryService service = FileDiscoveryService(
        runnerOverride: (DiscoveryRequest request) =>
            Stream<List<DiscoveredFile>>.value(<DiscoveredFile>[file]),
      );

      expect(
        await service
            .discover(const DiscoveryRequest(roots: <String>['/music']))
            .toList(),
        <List<DiscoveredFile>>[
          <DiscoveredFile>[file],
        ],
      );
    });
  });
}
