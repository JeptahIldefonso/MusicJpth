import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:music_oasis/data/models/playlist.dart';
import 'package:music_oasis/data/models/song.dart';
import 'package:music_oasis/data/repositories/song_repository_provider.dart';
import 'package:music_oasis/features/player/player_controller.dart';
import 'package:music_oasis/features/player/widgets/mini_player.dart';
import 'package:music_oasis/features/playlists/playlists_controller.dart';
import 'package:music_oasis/features/playlists/playlists_screen.dart';
import 'package:music_oasis/app/theme.dart';

import '../../support/fake_playback_engine.dart';

Playlist playlist(int id, String name, int count) =>
    Playlist(id: id, name: name, songCount: count, dateModified: id);

class FakePlaylistsController extends PlaylistsController {
  final List<Playlist> items;
  final Map<int, List<String?>> covers;

  FakePlaylistsController(this.items, {this.covers = const <int, List<String?>>{}});

  @override
  PlaylistsState build() => PlaylistsState(items: items, covers: covers);

  @override
  Future<void> load() async {}
}

/// Family fake seeded per playlist id; instances are retrievable through the
/// container for call assertions.
class FakeDetailController extends PlaylistDetailController {
  static Map<int, List<Song>> seed = <int, List<Song>>{};

  @override
  PlaylistDetailState build(int arg) => PlaylistDetailState(
    status: DetailStatus.ready,
    songs: seed[arg] ?? const <Song>[],
  );

  @override
  Future<void> load() async {}

  final List<int> removed = <int>[];

  @override
  Future<void> removeAt(int position) async => removed.add(position);

  final List<List<int>> added = <List<int>>[];

  @override
  Future<AddSongsResult> addSongs(List<int> songIds) async {
    added.add(songIds);
    return AddSongsResult(added: songIds.length, duplicates: 0);
  }
}

Song song(int id, String title, {bool available = true}) => Song(
  id: id,
  path: '/music/$id.mp3',
  title: title,
  artistName: 'Vera Mono',
  durationMs: 100000,
  isAvailable: available,
);

void main() {
  tearDown(() => FakeDetailController.seed = <int, List<Song>>{});

  testWidgets('playlists list shows names and song counts', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playlistsProvider.overrideWith(
            () => FakePlaylistsController(<Playlist>[
              playlist(1, 'Night Drive', 12),
              playlist(2, 'Rainy Day', 0),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: MusicOasisTheme.dark,
          home: const PlaylistsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Night Drive'), findsOneWidget);
    expect(find.text('Rainy Day'), findsOneWidget);
    expect(find.text('12 SONGS'), findsOneWidget);
    expect(find.text('0 SONGS'), findsOneWidget);
  });

  testWidgets(
    'detail plays the playlist as a queue; unavailable files stay listed but out',
    (tester) async {
      FakeDetailController.seed = <int, List<Song>>{
        7: <Song>[
          song(10, 'First'),
          song(11, 'Vanished', available: false),
          song(12, 'Third'),
        ],
      };
      final FakePlaybackEngine engine = FakePlaybackEngine();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          playbackEngineProvider.overrideWithValue(engine),
          playlistDetailProvider.overrideWith(FakeDetailController.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: MusicOasisTheme.dark,
            home: const PlaylistDetailScreen(playlistId: 7),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 SONGS'), findsOneWidget);
      expect(find.text('Vanished'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('playlist-play')));
      await tester.pumpAndSettle();

      expect(engine.loadCalls, 1);
      expect(engine.loadedTracks!.map((t) => t.title), <String>[
        'First',
        'Third',
      ]);
      expect(engine.loadedStart, 0);
    },
  );

  testWidgets('remove drops a membership at that position', (tester) async {
    FakeDetailController.seed = <int, List<Song>>{
      7: <Song>[song(10, 'First'), song(11, 'Second')],
    };
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
        playlistDetailProvider.overrideWith(FakeDetailController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: MusicOasisTheme.dark,
          home: const PlaylistDetailScreen(playlistId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('REMOVE FROM PLAYLIST'));
    await tester.pumpAndSettle();

    final FakeDetailController controller = container.read(
      playlistDetailProvider(7).notifier,
    ) as FakeDetailController;
    expect(controller.removed, <int>[0]);
  });

  testWidgets('detail header fits narrow screens without an overflow', (
    tester,
  ) async {
    FakeDetailController.seed = <int, List<Song>>{
      7: <Song>[
        song(10, 'A Very Long Playlist Member Title'),
        song(11, 'Second'),
      ],
    };
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
        playlistsProvider.overrideWith(
          () => FakePlaylistsController(<Playlist>[
            playlist(
              7,
              'A Very Long Playlist Name That Must Stay Horizontal',
              0,
            ),
          ]),
        ),
        playlistDetailProvider.overrideWith(FakeDetailController.new),
      ],
    );
    addTearDown(container.dispose);

    Widget build() => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: MusicOasisTheme.dark,
        home: PlaylistDetailScreen(playlistId: 7),
      ),
    );

    Future<void> checkAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('playlist-add-songs')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('playlist-play')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('playlist-shuffle')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }

    await checkAt(const Size(320, 640));
    await checkAt(const Size(360, 800));
  });

  testWidgets('playlist row opens detail and the back button returns', (
    tester,
  ) async {
    FakeDetailController.seed = <int, List<Song>>{
      1: <Song>[song(10, 'First')],
    };
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
        playlistsProvider.overrideWith(
          () => FakePlaylistsController(<Playlist>[
            playlist(1, 'Night Drive', 1),
          ]),
        ),
        playlistDetailProvider.overrideWith(FakeDetailController.new),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: '/playlists',
      routes: <RouteBase>[
        GoRoute(
          path: '/playlists',
          builder: (BuildContext context, GoRouterState state) =>
              const PlaylistsScreen(),
        ),
        GoRoute(
          path: '/playlists/:id',
          builder: (BuildContext context, GoRouterState state) =>
              PlaylistDetailScreen(
                playlistId: int.parse(state.pathParameters['id']!),
              ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: MusicOasisTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Night Drive'), findsOneWidget);
    await tester.tap(find.text('Night Drive'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('playlist-add-songs')), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    expect(router.canPop(), isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Night Drive'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('playlist-add-songs')), findsNothing);
  });

  testWidgets(
    'tapping a song starts the whole playlist queue from that song',
    (tester) async {
      FakeDetailController.seed = <int, List<Song>>{
        7: <Song>[
          song(10, 'First'),
          song(11, 'Vanished', available: false),
          song(12, 'Third'),
        ],
      };
      final FakePlaybackEngine engine = FakePlaybackEngine();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          playbackEngineProvider.overrideWithValue(engine),
          playlistDetailProvider.overrideWith(FakeDetailController.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: MusicOasisTheme.dark,
            home: PlaylistDetailScreen(playlistId: 7),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Third'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Third'));
      await tester.pumpAndSettle();

      // The full playable queue (unavailable rows excluded) with the tapped
      // song as the start index, so Next/Previous walk the playlist.
      expect(engine.loadCalls, 1);
      expect(engine.loadedTracks!.map((t) => t.title), <String>[
        'First',
        'Third',
      ]);
      expect(engine.loadedStart, 1);
      // Tapping a song never navigates away from the detail.
      expect(
        find.byKey(const ValueKey<String>('playlist-add-songs')),
        findsOneWidget,
      );
    },
  );

  testWidgets('shuffle plays the playlist queue through the shared player', (
    tester,
  ) async {
    FakeDetailController.seed = <int, List<Song>>{
      7: <Song>[
        song(10, 'First'),
        song(11, 'Vanished', available: false),
        song(12, 'Third'),
      ],
    };
    final FakePlaybackEngine engine = FakePlaybackEngine();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        playbackEngineProvider.overrideWithValue(engine),
        playlistDetailProvider.overrideWith(FakeDetailController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: MusicOasisTheme.dark,
          home: PlaylistDetailScreen(playlistId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('playlist-shuffle')));
    await tester.pumpAndSettle();

    expect(engine.loadCalls, 1);
    expect(engine.loadedTracks!.map((t) => t.title), <String>['First', 'Third']);
    expect(engine.loadedStart, inInclusiveRange(0, 1));
  });

  testWidgets(
    'add songs sheet filters without dropping selection, marks members, '
    'submits the selection',
    (tester) async {
      const int alphaId = 100;
      const int betaId = 101;
      const int gammaId = 102;

      FakeDetailController.seed = <int, List<Song>>{
        7: <Song>[song(alphaId, 'Alpha')],
      };
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
          availableSongsProvider.overrideWith(
            (Ref ref) async => <Song>[
              song(alphaId, 'Alpha'),
              song(betaId, 'Beta'),
              song(gammaId, 'Gamma'),
            ],
          ),
          playlistsProvider.overrideWith(
            () => FakePlaylistsController(<Playlist>[
              playlist(7, 'Night Drive', 1),
            ]),
          ),
          playlistDetailProvider.overrideWith(FakeDetailController.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: MusicOasisTheme.dark,
            home: PlaylistDetailScreen(playlistId: 7),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('playlist-add-songs')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('add-songs-search')), findsOneWidget);
      // The sheet and the detail behind it both show 'Alpha'; the IN PLAYLIST
      // marker is sheet-only.
      final Finder alphaRow = find.widgetWithText(ListTile, 'Alpha');
      expect(
        find.descendant(
          of: alphaRow,
          matching: find.text('IN PLAYLIST'),
        ),
        findsOneWidget,
      );
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);

      await tester.tap(find.text('Beta'));
      await tester.tap(find.text('Gamma'));
      await tester.pump();
      expect(find.text('2 SELECTED'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('add-songs-search')),
        'gamma',
      );
      await tester.pumpAndSettle();

      expect(find.text('Beta'), findsNothing);
      expect(find.text('Gamma'), findsOneWidget);
      expect(find.text('2 SELECTED'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('add-songs-confirm')));
      await tester.pumpAndSettle();

      final FakeDetailController controller = container.read(
        playlistDetailProvider(7).notifier,
      ) as FakeDetailController;
      expect(controller.added, <List<int>>[
        <int>[betaId, gammaId],
      ]);
      expect(find.byKey(const ValueKey<String>('add-songs-search')), findsNothing);
      // Let the confirmation snackbar time out so no timer is left pending.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'grid cards collage artwork inside the cover at narrow widths without overflow',
    (tester) async {
      Future<void> checkAt(Size size) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              playlistsProvider.overrideWith(
                () => FakePlaylistsController(
                  <Playlist>[
                    playlist(
                      1,
                      'A Playlist Name Long Enough To Demand Ellipsis',
                      4,
                    ),
                    playlist(2, 'Rainy Day', 3),
                  ],
                  covers: <int, List<String?>>{
                    1: <String?>[
                      '/art/one.jpg',
                      '/art/two.jpg',
                      '/art/three.jpg',
                      '/art/four.jpg',
                    ],
                    2: <String?>['/art/a.jpg', null, null, null],
                  },
                ),
              ),
            ],
            child: MaterialApp(
              theme: MusicOasisTheme.dark,
              home: const PlaylistsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size');
      }

      await checkAt(const Size(320, 640));
      await checkAt(const Size(360, 800));
    },
  );

  testWidgets('the PLAYLISTS destination no longer shows the brand header', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playlistsProvider.overrideWith(
            () => FakePlaylistsController(<Playlist>[
              playlist(1, 'Night Drive', 12),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: MusicOasisTheme.dark,
          home: const PlaylistsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PLAYLISTS'), findsOneWidget);
    expect(find.text('MUSIC JPTH'), findsNothing);
  });

  testWidgets('starting the queue brings the mini player transport along', (
    tester,
  ) async {
    FakeDetailController.seed = <int, List<Song>>{
      7: <Song>[song(10, 'First'), song(11, 'Second')],
    };
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
        playlistDetailProvider.overrideWith(FakeDetailController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: MusicOasisTheme.dark,
          home: const PlaylistDetailScreen(playlistId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The bar stays mounted but collapsed while nothing is loaded.
    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('mini-play-pause')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('playlist-play')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('mini-play-pause')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('mini-previous')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('mini-next')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
