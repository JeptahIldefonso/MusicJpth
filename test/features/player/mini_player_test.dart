import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/app/app.dart';
import 'package:music_oasis/features/player/full_player_screen.dart';
import 'package:music_oasis/features/player/player_controller.dart';
import 'package:music_oasis/features/player/widgets/mini_player.dart';
import 'package:music_oasis/services/audio/playback_engine.dart';

import '../../support/fake_playback_engine.dart';

Future<(ProviderContainer, FakePlaybackEngine)> _pump(
  WidgetTester tester, {
  FakePlaybackEngine? engine,
}) async {
  final FakePlaybackEngine cut = engine ?? FakePlaybackEngine();
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[playbackEngineProvider.overrideWithValue(cut)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MusicOasisApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (container, cut);
}

void main() {
  testWidgets('is hidden while nothing is loaded', (tester) async {
    await _pump(tester);

    // The widget stays mounted but collapses; nothing of the bar shows.
    expect(find.byKey(const ValueKey<String>('mini-play-pause')), findsNothing);
    expect(find.text('Untitled'), findsNothing);
  });

  testWidgets('shows title and artist once a queue exists', (tester) async {
    final (ProviderContainer container, _) = await _pump(tester);

    await container.read(playerProvider.notifier).playQueue(<AudioTrack>[
      const AudioTrack(
        path: '/music/a.mp3',
        title: 'Northern Line',
        artist: 'Vera Mono',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(find.text('Northern Line'), findsOneWidget);
    expect(find.text('Vera Mono'), findsOneWidget);
  });

  testWidgets('falls back to Unknown Artist', (tester) async {
    final (ProviderContainer container, _) = await _pump(tester);

    await container.read(playerProvider.notifier).playQueue(<AudioTrack>[
      const AudioTrack(path: '/music/a.mp3', title: 'Untitled'),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Unknown Artist'), findsOneWidget);
  });

  testWidgets('surfaces a playback failure as microcopy', (tester) async {
    final (ProviderContainer container, FakePlaybackEngine engine) =
        await _pump(tester);

    await container.read(playerProvider.notifier).playQueue(<AudioTrack>[
      const AudioTrack(path: '/music/a.mp3', title: 'Untitled'),
    ]);
    engine.failureController.add(const PlaybackFailure(message: 'boom'));
    await tester.pumpAndSettle();

    expect(find.text('PLAYBACK FAILED'), findsOneWidget);
  });

  testWidgets('play/pause routes through the controller to the engine', (
    tester,
  ) async {
    final (ProviderContainer container, FakePlaybackEngine engine) =
        await _pump(tester);

    await container.read(playerProvider.notifier).playQueue(<AudioTrack>[
      const AudioTrack(path: '/music/a.mp3', title: 'Untitled'),
    ]);
    await tester.pumpAndSettle();

    // The engine reports playing; the bar must offer pause.
    engine.playingController.add(true);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('mini-play-pause')));
    await tester.pumpAndSettle();
    expect(engine.pauseCalls, 1);

    engine.playingController.add(false);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('mini-play-pause')));
    await tester.pumpAndSettle();
    expect(engine.playCalls, 1);
  });

  testWidgets('tapping the bar opens the full player over the shell', (
    tester,
  ) async {
    final (ProviderContainer container, _) = await _pump(tester);

    await container.read(playerProvider.notifier).playQueue(<AudioTrack>[
      const AudioTrack(path: '/music/a.mp3', title: 'Untitled'),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MiniPlayer));
    await tester.pumpAndSettle();

    expect(find.byType(FullPlayerScreen), findsOneWidget);
  });

  testWidgets(
    'previous and next show once a queue exists and drive the engine',
    (tester) async {
      final (ProviderContainer container, FakePlaybackEngine engine) =
          await _pump(tester);

      await container.read(playerProvider.notifier).playQueue(<AudioTrack>[
        const AudioTrack(path: '/music/a.mp3', title: 'A'),
        const AudioTrack(path: '/music/b.mp3', title: 'B'),
      ]);
      await tester.pumpAndSettle();

      final IconButton previous = tester.widget<IconButton>(
        find.byKey(const ValueKey<String>('mini-previous')),
      );
      final IconButton next = tester.widget<IconButton>(
        find.byKey(const ValueKey<String>('mini-next')),
      );
      expect(previous.onPressed, isNotNull);
      expect(next.onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey<String>('mini-next')));
      await tester.pumpAndSettle();
      expect(engine.nextCalls, 1);

      await tester.tap(find.byKey(const ValueKey<String>('mini-previous')));
      await tester.pumpAndSettle();
      expect(engine.previousCalls, 1);
    },
  );

  testWidgets('transport obeys engine availability for a single track', (
    tester,
  ) async {
    // With a single track the real engine reports neither direction
    // available; mirror that on the fake so the bar must disable both.
    final (ProviderContainer container, _) = await _pump(
      tester,
      engine: FakePlaybackEngine()
        ..previousAvailable = false
        ..nextAvailable = false,
    );

    await container.read(playerProvider.notifier).playQueue(<AudioTrack>[
      const AudioTrack(path: '/music/a.mp3', title: 'Alone'),
    ]);
    await tester.pumpAndSettle();

    // The track is the only one in its queue: neither direction has anywhere
    // to go until a lower position gives previous its restart carve-out.
    final IconButton previous = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('mini-previous')),
    );
    final IconButton next = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('mini-next')),
    );
    expect(previous.onPressed, isNull);
    expect(next.onPressed, isNull);
  });

  testWidgets('a skip disabled by the engine stays disabled in the bar', (
    tester,
  ) async {
    final (ProviderContainer container, _) = await _pump(
      tester,
      engine: FakePlaybackEngine()
        ..previousAvailable = false
        ..nextAvailable = true,
    );

    await container.read(playerProvider.notifier).playQueue(<AudioTrack>[
      const AudioTrack(path: '/music/a.mp3', title: 'A'),
      const AudioTrack(path: '/music/b.mp3', title: 'B'),
    ]);
    await tester.pumpAndSettle();

    final IconButton previous = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('mini-previous')),
    );
    final IconButton next = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('mini-next')),
    );
    expect(previous.onPressed, isNull);
    expect(next.onPressed, isNotNull);
  });

  testWidgets('long titles ellipsize in the bar on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 1710);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final (ProviderContainer container, _) = await _pump(tester);

    await container.read(playerProvider.notifier).playQueue(<AudioTrack>[
      const AudioTrack(
        path: '/music/a.mp3',
        title: 'A Very Long Song Title That Must Ellipsize Instead Of Overflowing The Mini Player Row On A Narrow Screen',
        artist: 'An Equally Overlong Artist Name For Good Measure',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
