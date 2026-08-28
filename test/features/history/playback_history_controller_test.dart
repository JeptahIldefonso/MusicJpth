import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/app/theme.dart';
import 'package:music_oasis/data/models/song.dart';
import 'package:music_oasis/data/repositories/playback_history_repository.dart'
    show PlaybackHistoryRepository;
import 'package:music_oasis/data/repositories/playback_history_repository_provider.dart';
import 'package:music_oasis/features/home/home_screen.dart';
import 'package:music_oasis/features/history/playback_history_controller.dart';
import 'package:music_oasis/features/library/library_controller.dart';
import 'package:music_oasis/features/player/player_controller.dart';
import 'package:music_oasis/services/audio/playback_engine.dart'
    show AudioTrack;

import '../../support/fake_playback_engine.dart';

class StubRepository implements PlaybackHistoryRepository {
  final List<int> added = <int>[];

  @override
  Future<void> add(int songId) async => added.add(songId);

  @override
  Future<List<Song>> recent({int limit = 50, int offset = 0}) async => <Song>[
    for (final int id in added.reversed)
      Song(
        id: id,
        path: '/music/$id.mp3',
        title: 'Song $id',
        isAvailable: true,
        playedAtMs: id * 1000000,
      ),
  ];
}

class _FakeLibraryController extends LibraryController {
  final List<Song> _songs;
  _FakeLibraryController(this._songs);

  @override
  LibraryState build() => LibraryState(
        status: LibraryStatus.ready,
        songs: _songs,
      );

  @override
  Future<void> loadInitial() async {}

  @override
  Future<void> loadMore() async {}
}

void main() {
  group('shouldRecordHistory semantics', () {
    test('below the minimum listen time never records', () {
      expect(
        shouldRecordHistory(
          positionMs: 4999,
          durationMs: 10000,
          alreadyRecorded: false,
        ),
        isFalse,
      );
    });

    test('above minimum but under half does not record', () {
      expect(
        shouldRecordHistory(
          positionMs: 6000,
          durationMs: 100000,
          alreadyRecorded: false,
        ),
        isFalse,
      );
    });

    test('halfway crosses the threshold', () {
      expect(
        shouldRecordHistory(
          positionMs: 50000,
          durationMs: 100000,
          alreadyRecorded: false,
        ),
        isTrue,
      );
    });

    test('unknown duration never records', () {
      expect(
        shouldRecordHistory(
          positionMs: 99999,
          durationMs: null,
          alreadyRecorded: false,
        ),
        isFalse,
      );
    });

    test('already recorded never duplicates', () {
      expect(
        shouldRecordHistory(
          positionMs: 90000,
          durationMs: 100000,
          alreadyRecorded: true,
        ),
        isFalse,
      );
    });
  });

  test('recorder writes once per track-session as thresholds are crossed', () {
    fakeAsync((FakeAsync async) {
      final FakePlaybackEngine engine = FakePlaybackEngine();
      final StubRepository repository = StubRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          playbackEngineProvider.overrideWithValue(engine),
          playbackHistoryRepositoryProvider.overrideWith(
            (Ref ref) async => repository,
          ),
        ],
      );

      container.read(playbackHistoryRecorderProvider);
      container.read(playerProvider.notifier).playQueue(<AudioTrack>[
        const AudioTrack(
          path: '/a.mp3',
          title: 'A',
          songId: 101,
          durationMs: 10000,
        ),
        const AudioTrack(
          path: '/b.mp3',
          title: 'B',
          songId: 102,
          durationMs: 10000,
        ),
      ]);
      async.flushMicrotasks();

      engine.indexController.add(0);
      async.flushMicrotasks();

      // Ticks below the floor: nothing.
      engine.positionController.add(const Duration(seconds: 1));
      engine.positionController.add(const Duration(seconds: 4));
      async.flushMicrotasks();
      expect(repository.added, isEmpty);

      // Halfway through the ten-second track: exactly one write.
      engine.positionController.add(const Duration(seconds: 5));
      async.flushMicrotasks();
      expect(repository.added, <int>[101]);

      // Further ticks and seeks do not duplicate.
      engine.positionController.add(const Duration(seconds: 9));
      async.flushMicrotasks();
      expect(repository.added, <int>[101]);

      // Moving to the next track starts a fresh session.
      engine.indexController.add(1);
      engine.positionController.add(const Duration(seconds: 5));
      async.flushMicrotasks();
      expect(repository.added, <int>[101, 102]);

      container.dispose();
    });
  });

  testWidgets('Home lists all songs and plays on tap', (
    tester,
  ) async {
    final StubRepository repository = StubRepository()
      ..added.addAll(<int>[201, 202]);
    final FakePlaybackEngine engine = FakePlaybackEngine();
    final List<Song> testSongs = <Song>[
      const Song(
        id: 201,
        path: '/music/201.mp3',
        title: 'Song 201',
        isAvailable: true,
      ),
      const Song(
        id: 202,
        path: '/music/202.mp3',
        title: 'Song 202',
        isAvailable: true,
      ),
    ];
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        playbackEngineProvider.overrideWithValue(engine),
        playbackHistoryRepositoryProvider.overrideWith(
          (Ref ref) async => repository,
        ),
        libraryProvider.overrideWith(() => _FakeLibraryController(testSongs)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: MusicOasisTheme.dark,
          home: Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              ref.watch(playbackHistoryProvider);
              return const HomeScreen();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ALL SONGS'), findsOneWidget);
    expect(find.text('Song 201'), findsOneWidget);
    expect(find.text('Song 202'), findsOneWidget);

    // Tapping an entry queues it through the real PlayerController.
    await tester.tap(find.text('Song 202'));
    await tester.pumpAndSettle();

    final PlayerState player = container.read(playerProvider);
    expect(player.currentTrack?.title, 'Song 202');
    expect(player.currentTrack?.songId, 202);
  });
}
