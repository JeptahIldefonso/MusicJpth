import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/core/utils/music_paths.dart';
import 'package:path/path.dart' as p;

void main() {
  group('MusicPaths.normalise', () {
    test('trims and drops a trailing separator', () {
      expect(
        p.equals(MusicPaths.normalise('  /music/rock/  '), '/music/rock'),
        isTrue,
      );
      expect(
        MusicPaths.normalise('/music/rock/'),
        isNot(endsWith(p.separator)),
      );
    });

    test('resolves traversal segments', () {
      expect(
        p.equals(
          MusicPaths.normalise('/music/jazz/../rock/./1990'),
          '/music/rock/1990',
        ),
        isTrue,
      );
    });

    test('is idempotent, so a stored path never drifts', () {
      final String once = MusicPaths.normalise('/music/rock/');
      expect(MusicPaths.normalise(once), once);
    });
  });

  group('MusicPaths.key', () {
    test('gives one key to one file, whatever the spelling', () {
      expect(
        MusicPaths.key('/music/rock/../rock/song.mp3'),
        MusicPaths.key('/music/rock/song.mp3'),
      );
    });

    test(
      'is absolute, so a relative path cannot masquerade as another file',
      () {
        expect(p.isAbsolute(MusicPaths.key('music/song.mp3')), isTrue);
      },
    );

    test('follows the platform case rules', () {
      final bool sameKey =
          MusicPaths.key('/Music/Song.mp3') ==
          MusicPaths.key('/music/song.mp3');
      // Windows and macOS treat those as one file; Linux as two.
      expect(sameKey, p.style == p.Style.windows);
    });
  });

  group('MusicPaths.isUnder', () {
    test('accepts the folder itself and anything inside it', () {
      expect(MusicPaths.isUnder('/music', '/music'), isTrue);
      expect(MusicPaths.isUnder('/music', '/music/rock/song.mp3'), isTrue);
    });

    test('rejects a sibling with a shared prefix', () {
      expect(MusicPaths.isUnder('/music', '/musicals/song.mp3'), isFalse);
      expect(MusicPaths.isUnder('/music', '/podcasts/song.mp3'), isFalse);
    });
  });

  group('MusicPaths.basenameWithoutExtension', () {
    test('is the filename a user would recognise', () {
      expect(
        MusicPaths.basenameWithoutExtension('/music/rock/Lose Yourself.mp3'),
        'Lose Yourself',
      );
    });

    test('keeps interior dots', () {
      expect(
        MusicPaths.basenameWithoutExtension('/music/01. Intro.flac'),
        '01. Intro',
      );
    });
  });
}
