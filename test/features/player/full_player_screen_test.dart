import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:music_oasis/app/app.dart';
import 'package:music_oasis/features/player/full_player_screen.dart';
import 'package:music_oasis/features/player/player_controller.dart';
import 'package:music_oasis/services/audio/playback_engine.dart';
import 'package:music_oasis/services/audio/playback_engine.dart' as pbe;

import '../../support/fake_playback_engine.dart';

Future<(ProviderContainer, FakePlaybackEngine)> _pump(
  WidgetTester tester,
) async {
  final FakePlaybackEngine engine = FakePlaybackEngine();
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[playbackEngineProvider.overrideWithValue(engine)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MusicOasisApp(),
    ),
  );
  await tester.pumpAndSettle();

  await container.read(playerProvider.notifier).playQueue(<AudioTrack>[
    const AudioTrack(
      path: '/music/a.mp3',
      title: 'Northern Line',
      artist: 'Vera Mono',
      album: 'Signal Forms',
      durationMs: 214000,
    ),
  ]);
  final BuildContext context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push('/player');
  await tester.pumpAndSettle();
  return (container, engine);
}

void main() {
  testWidgets('shows title and artist hierarchy', (tester) async {
    await _pump(tester);

    expect(find.text('Northern Line'), findsOneWidget);
    expect(find.text('Vera Mono'), findsOneWidget);
    expect(find.byType(FullPlayerScreen), findsOneWidget);
  });

  testWidgets('falls back to Unknown Artist without tags', (tester) async {
    final (ProviderContainer container, _) = await _pump(tester);

    await container.read(playerProvider.notifier).playQueue(<AudioTrack>[
      const AudioTrack(path: '/music/untagged.mp3', title: 'Untitled'),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Unknown Artist'), findsOneWidget);
  });

  testWidgets('play/pause reaches the engine', (tester) async {
    final (ProviderContainer container, FakePlaybackEngine engine) =
        await _pump(tester);

    engine.playingController.add(true);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('full-play-pause')));
    await tester.pumpAndSettle();
    expect(engine.pauseCalls, 1);
  });

  testWidgets('next and previous reach the engine', (tester) async {
    final (_, FakePlaybackEngine engine) = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey<String>('full-next')));
    await tester.pumpAndSettle();

    engine.positionController.add(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('full-previous')));
    await tester.pumpAndSettle();

    expect(engine.nextCalls, 1);
    expect(engine.seekCalls, 1);
    expect(engine.previousCalls, 0);
  });

  testWidgets('shuffle and repeat toggles reach the engine', (tester) async {
    final (ProviderContainer container, FakePlaybackEngine engine) =
        await _pump(tester);

    await tester.tap(find.byTooltip('Shuffle'));
    await tester.tap(find.byTooltip('Repeat'));
    await tester.pumpAndSettle();

    final PlayerState state = container.read(playerProvider);
    expect(state.shuffled, isTrue);
    expect(state.repeat, pbe.RepeatMode.all);

    await tester.tap(find.byTooltip('Repeat'));
    await tester.pumpAndSettle();
    expect(container.read(playerProvider).repeat, pbe.RepeatMode.one);
  });

  testWidgets('a failure replaces the artist line with microcopy', (
    tester,
  ) async {
    final (ProviderContainer container, FakePlaybackEngine engine) =
        await _pump(tester);

    engine.failureController.add(const PlaybackFailure(message: 'boom'));
    await tester.pumpAndSettle();

    expect(find.text('PLAYBACK FAILED'), findsOneWidget);
    expect(container.read(playerProvider).failure, isNotNull);

    await container.read(playerProvider.notifier).playQueue(<AudioTrack>[
      const AudioTrack(path: '/music/b.mp3', title: 'Untitled'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('PLAYBACK FAILED'), findsNothing);
  });

  testWidgets('position ticks update only the progress area', (tester) async {
    final (ProviderContainer container, FakePlaybackEngine engine) =
        await _pump(tester);

    engine.durationController.add(const Duration(minutes: 3));
    await tester.pumpAndSettle();

    final Element header = tester.element(find.text('Northern Line'));

    engine.positionController.add(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(find.text('0:30'), findsOneWidget);
    expect(
      identical(tester.element(find.text('Northern Line')), header),
      isTrue,
    );
  });

  testWidgets('dragging the seek bar seeks on release', (tester) async {
    final (ProviderContainer container, FakePlaybackEngine engine) =
        await _pump(tester);

    engine.durationController.add(const Duration(minutes: 3));
    await tester.pumpAndSettle();

    final Rect rect = tester.getRect(find.byType(Slider));
    await tester.dragFrom(
      rect.centerLeft + const Offset(1, 0),
      Offset(rect.width * 0.5, 0),
    );
    await tester.pumpAndSettle();

    final PlayerState stateAfterDrag = container.read(playerProvider);
    expect(stateAfterDrag.hasQueue, isTrue);
    expect(find.byType(Slider), findsOneWidget);
  });
}
