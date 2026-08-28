import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/data/models/track_metadata.dart';

void main() {
  group('TrackMetadata', () {
    test('is unknown when nothing could be read', () {
      const TrackMetadata track = TrackMetadata.unknown('/m/a.mp3');

      expect(track.path, '/m/a.mp3');
      expect(track.hasTags, isFalse);
      expect(track.title, isNull);
      expect(track.artist, isNull);
      expect(track.album, isNull);
      expect(track.genre, isNull);
      expect(track.year, isNull);
      expect(track.trackNumber, isNull);
      expect(track.discNumber, isNull);
      expect(track.durationMs, isNull);
    });

    test('a single tag is enough to count as read', () {
      // Duration alone still tells the library something, so it must not be
      // treated as "no metadata".
      expect(
        const TrackMetadata(path: '/m/a.mp3', durationMs: 1000).hasTags,
        isTrue,
      );
      expect(const TrackMetadata(path: '/m/a.mp3', year: 1998).hasTags, isTrue);
      expect(const TrackMetadata(path: '/m/a.mp3', title: 'A').hasTags, isTrue);
    });

    test('compares by value, so an unchanged read is recognisable', () {
      const TrackMetadata a = TrackMetadata(
        path: '/m/a.mp3',
        title: 'Teardrop',
        artist: 'Massive Attack',
        durationMs: 330000,
      );
      const TrackMetadata b = TrackMetadata(
        path: '/m/a.mp3',
        title: 'Teardrop',
        artist: 'Massive Attack',
        durationMs: 330000,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const TrackMetadata.unknown('/m/a.mp3')));
      expect(
        a,
        isNot(
          const TrackMetadata(
            path: '/m/b.mp3',
            title: 'Teardrop',
            artist: 'Massive Attack',
            durationMs: 330000,
          ),
        ),
      );
    });
  });
}
