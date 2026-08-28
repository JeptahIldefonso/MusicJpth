import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/services/scanner/audio_formats.dart';

void main() {
  group('AudioFormats.supported', () {
    test('is exactly the initial target list', () {
      expect(AudioFormats.supported, <String>{
        'mp3',
        'flac',
        'wav',
        'm4a',
        'aac',
        'ogg',
        'opus',
      });
    });
  });

  group('AudioFormats.extensionOf', () {
    test('lower-cases the extension', () {
      expect(AudioFormats.extensionOf('/music/Song.MP3'), 'mp3');
      expect(AudioFormats.extensionOf('/music/Song.FlAc'), 'flac');
    });

    test('reads the last extension only', () {
      expect(AudioFormats.extensionOf('/music/Song.tar.mp3'), 'mp3');
    });

    test('is null when there is no extension', () {
      expect(AudioFormats.extensionOf('/music/Song'), isNull);
      expect(AudioFormats.extensionOf('/music/Song.'), isNull);
    });

    test('treats a dotfile as having no extension', () {
      expect(AudioFormats.extensionOf('/music/.hidden'), isNull);
    });
  });

  group('AudioFormats.isSupported', () {
    test('accepts every supported container, in any case', () {
      for (final String format in AudioFormats.supported) {
        expect(AudioFormats.isSupported('/music/song.$format'), isTrue);
        expect(
          AudioFormats.isSupported('/music/song.${format.toUpperCase()}'),
          isTrue,
        );
      }
    });

    test('rejects everything else the scanner will meet', () {
      const List<String> ignored = <String>[
        '/music/cover.jpg',
        '/music/album.png',
        '/music/notes.txt',
        '/music/playlist.m3u',
        '/music/song.mp4',
        '/music/song.mp3.part',
        '/music/song.wma',
        '/music/folder',
        '/music/.hidden',
      ];
      for (final String path in ignored) {
        expect(AudioFormats.isSupported(path), isFalse, reason: path);
      }
    });
  });
}
