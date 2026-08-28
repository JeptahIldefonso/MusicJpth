import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/data/models/track_metadata.dart';
import 'package:music_oasis/services/metadata/metadata_service.dart';
import 'package:path/path.dart' as p;

Directory _tempDir() {
  final Directory directory = Directory.systemTemp.createTempSync(
    'music_oasis_metadata',
  );
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return directory;
}

/// A structurally valid, tagless 16-bit mono PCM WAV of [milliseconds].
///
/// Built here rather than checked in as a fixture: what the test needs is a file
/// the parser can genuinely open, and 8 kHz silence is the smallest one there is.
File _wav(Directory root, String name, {int milliseconds = 1000}) {
  const int sampleRate = 8000;
  const int byteRate = sampleRate * 2; // mono, 16-bit
  final int dataBytes = byteRate * milliseconds ~/ 1000;
  final ByteData header = ByteData(44);

  void ascii(int offset, String value) {
    for (int i = 0; i < value.length; i++) {
      header.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // PCM chunk size
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, 2, Endian.little); // block align
  header.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  header.setUint32(40, dataBytes, Endian.little);

  final File file = File(p.join(root.path, name));
  file.writeAsBytesSync(<int>[
    ...header.buffer.asUint8List(),
    ...List<int>.filled(dataBytes, 0),
  ]);
  return file;
}

/// A file with an audio extension and no audio in it.
File _garbage(Directory root, String name) {
  final File file = File(p.join(root.path, name));
  file.writeAsBytesSync(List<int>.filled(64, 7));
  return file;
}

void main() {
  group('readTrackMetadataSync', () {
    test('reads what a real file carries', () async {
      final Directory root = _tempDir();
      final File file = _wav(root, 'silence.wav', milliseconds: 2500);

      final TrackMetadata track = readTrackMetadataSync(<String>[file.path])
          .single;

      expect(track.path, file.path);
      expect(track.durationMs, 2500);
      expect(track.hasTags, isTrue);
      // A tagless file has no tags to report, and no empty strings either — the
      // title fallback is the repository's job (`REQUIREMENTS.md` §16).
      expect(track.title, isNull);
      expect(track.artist, isNull);
      expect(track.album, isNull);
      expect(track.genre, isNull);
      // Parsers emit 0 for "unset"; that is missing data, not data.
      expect(track.year, isNull);
      expect(track.trackNumber, isNull);
      expect(track.discNumber, isNull);
    });

    test('degrades an unparsable file instead of throwing', () async {
      final Directory root = _tempDir();
      final File file = _garbage(root, 'broken.mp3');

      final TrackMetadata track = readTrackMetadataSync(<String>[file.path])
          .single;

      expect(track, TrackMetadata.unknown(file.path));
      expect(track.hasTags, isFalse);
    });

    test('degrades a file that is not there', () async {
      final String missing = p.join(_tempDir().path, 'gone.mp3');

      expect(
        readTrackMetadataSync(<String>[missing]).single,
        TrackMetadata.unknown(missing),
      );
    });

    test('one unreadable file does not cost the readable ones', () async {
      // `PROJECT.md` §29: one corrupt file out of a thousand must leave the
      // other 999 indexed.
      final Directory root = _tempDir();
      final File good = _wav(root, 'good.wav');
      final File bad = _garbage(root, 'bad.mp3');
      final File alsoGood = _wav(root, 'also-good.wav', milliseconds: 500);

      final List<TrackMetadata> tracks = readTrackMetadataSync(<String>[
        good.path,
        bad.path,
        alsoGood.path,
      ]);

      // One result per path, in the order asked for.
      expect(tracks.map((TrackMetadata t) => t.path), <String>[
        good.path,
        bad.path,
        alsoGood.path,
      ]);
      expect(tracks[0].durationMs, 1000);
      expect(tracks[1].hasTags, isFalse);
      expect(tracks[2].durationMs, 500);
    });

    test('an empty batch reads nothing', () {
      expect(readTrackMetadataSync(const <String>[]), isEmpty);
    });
  });

  group('MetadataService', () {
    test('reads off this isolate and returns the same results', () async {
      final Directory root = _tempDir();
      final File good = _wav(root, 'good.wav', milliseconds: 1500);
      final File bad = _garbage(root, 'bad.mp3');

      final List<TrackMetadata> tracks = await const MetadataService().read(
        <String>[good.path, bad.path],
      );

      expect(tracks, hasLength(2));
      expect(tracks.first.durationMs, 1500);
      expect(tracks.last, TrackMetadata.unknown(bad.path));
    });

    test('spawns nothing for an empty batch', () async {
      expect(await const MetadataService().read(const <String>[]), isEmpty);
    });

    test('uses an injected runner instead of an isolate', () async {
      final List<List<String>> calls = <List<String>>[];
      final MetadataService service = MetadataService(
        runnerOverride: (List<String> paths) async {
          calls.add(paths);
          return <TrackMetadata>[
            const TrackMetadata(path: '/m/a.mp3', title: 'Injected'),
          ];
        },
      );

      final List<TrackMetadata> tracks = await service.read(<String>[
        '/m/a.mp3',
      ]);

      expect(calls, <List<String>>[
        <String>['/m/a.mp3'],
      ]);
      expect(tracks.single.title, 'Injected');
    });
  });
}
