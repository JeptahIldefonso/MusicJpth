import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/features/player/player_controller.dart';
import 'package:music_oasis/services/audio/playback_engine.dart';

import '../../support/fake_playback_engine.dart';

AudioTrack track(String path) => AudioTrack(path: path, title: path);

void main() {
  late FakePlaybackEngine engine;
  late ProviderContainer container;

  setUp(() {
    engine = FakePlaybackEngine();
    container = ProviderContainer(
      overrides: <Override>[playbackEngineProvider.overrideWithValue(engine)],
    );
    addTearDown(container.dispose);
  });

  PlayerController controller() => container.read(playerProvider.notifier);

  test('playQueue loads a new queue at the start index', () async {
    final List<AudioTrack> queue = <String>[
      '/a.mp3',
      '/b.mp3',
    ].map(track).toList();

    await controller().playQueue(queue, startIndex: 1);

    expect(engine.loadCalls, 1);
    expect(engine.loadedTracks, hasLength(2));
    expect(engine.loadedStart, 1);
    expect(container.read(playerProvider).hasQueue, isTrue);
    expect(container.read(playerProvider).currentTrack?.path, '/b.mp3');
  });

  test(
    'tapping a song in the already-loaded queue seeks instead of reloading',
    () async {
      final List<AudioTrack> queue = <String>[
        '/a.mp3',
        '/b.mp3',
      ].map(track).toList();

      await controller().playQueue(queue);
      await controller().playQueue(queue, startIndex: 1);

      expect(engine.loadCalls, 1);
      expect(engine.seekIndexCalls, 1);
    },
  );

  test('togglePlayPause routes on playing state', () async {
    await controller().playQueue(<AudioTrack>[track('/a.mp3')]);

    engine.playingController.add(true);
    await Future<void>.delayed(Duration.zero);

    await container.read(playerProvider.notifier).togglePlayPause();
    expect(engine.pauseCalls, 1);
    expect(engine.playCalls, 0);

    engine.playingController.add(false);
    await Future<void>.delayed(Duration.zero);

    await container.read(playerProvider.notifier).togglePlayPause();
    expect(engine.playCalls, 1);
  });

  test('next does nothing when the engine reports no next track', () async {
    await controller().playQueue(<AudioTrack>[track('/a.mp3')]);
    engine.nextAvailable = false;

    await controller().next();

    expect(engine.nextCalls, 0);
  });

  test('previous restarts when far into a track', () async {
    await controller().playQueue(
      <String>['/a.mp3', '/b.mp3'].map(track).toList(),
    );

    await controller().previous(position: const Duration(seconds: 30));

    expect(engine.seekCalls, 1);
    expect(engine.previousCalls, 0);
  });

  test('previous skips back near the start of a track', () async {
    await controller().playQueue(
      <String>['/a.mp3', '/b.mp3'].map(track).toList(),
    );

    await controller().previous(position: const Duration(seconds: 1));

    expect(engine.previousCalls, 1);
  });

  test('failure stream lands in state and acknowledge clears it', () async {
    await controller().playQueue(<AudioTrack>[track('/a.mp3')]);

    engine.failureController.add(const PlaybackFailure(message: 'boom'));
    await Future<void>.delayed(Duration.zero);

    expect(container.read(playerProvider).failure, 'boom');

    controller().acknowledgeFailure();
    expect(container.read(playerProvider).failure, isNull);
  });
}
