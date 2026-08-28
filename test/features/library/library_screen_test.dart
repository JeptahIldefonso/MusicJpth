import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/app/theme.dart';
import 'package:music_oasis/core/widgets/song_artwork.dart';
import 'package:music_oasis/data/models/playlist.dart';
import 'package:music_oasis/data/models/song.dart';
import 'package:music_oasis/data/repositories/song_repository_provider.dart';
import 'package:music_oasis/features/library/album_detail_screen.dart';
import 'package:music_oasis/features/library/artist_detail_screen.dart';
import 'package:music_oasis/features/library/browse_models.dart';
import 'package:music_oasis/features/library/browse_providers.dart';
import 'package:music_oasis/features/library/library_controller.dart';
import 'package:music_oasis/features/library/library_screen.dart';
import 'package:music_oasis/features/player/player_controller.dart';
import 'package:music_oasis/features/playlists/playlists_controller.dart';

import '../../support/fake_playback_engine.dart';

Playlist playlist(int id, String name, int count) =>
    Playlist(id: id, name: name, songCount: count, dateModified: id);

class FakePlaylistsController extends PlaylistsController {
  final List<Playlist> items;

  FakePlaylistsController(this.items);

  @override
  PlaylistsState build() => PlaylistsState(items: items);

  @override
  Future<void> load() async {}
}

class FakeLibraryController extends LibraryController {
  static List<Song> seed = <Song>[];

  @override
  LibraryState build() => LibraryState(
    status: LibraryStatus.ready,
    songs: seed,
    hasMore: false,
  );

  @override
  Future<void> loadInitial() async {}

  @override
  Future<void> loadMore() async {}
}

Song song(int id, String title, {bool available = true}) => Song(
  id: id,
  path: '/music/$id.mp3',
  title: title,
  isAvailable: available,
);

Song tagged(
  int id,
  String title, {
  String? artist,
  String? album,
  int? trackNumber,
  String? artwork,
}) => Song(
  id: id,
  path: '/music/$id.mp3',
  title: title,
  isAvailable: true,
  artistName: artist,
  albumTitle: album,
  trackNumber: trackNumber,
  artworkPath: artwork,
);

void main() {
  group('browse providers', () {
    test('albums group by artist + album and pick the first real artwork', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          availableSongsProvider.overrideWith((Ref ref) async => <Song>[
            tagged(1, 'B', artist: 'Vera', album: 'Shared', trackNumber: 2, artwork: 'artwork/b.jpg'),
            tagged(2, 'A', artist: 'Vera', album: 'Shared', trackNumber: 1),
            tagged(3, 'X', artist: 'North', album: 'Shared'),
            tagged(4, 'Z', artist: null, album: null),
          ]),
        ],
      );
      addTearDown(container.dispose);

      final List<AlbumItem> albums = await container.read(albumsProvider.future);
      expect(albums, hasLength(3));

      final AlbumItem vera = albums.firstWhere(
        (AlbumItem a) => a.artistName == 'Vera',
      );
      expect(vera.songCount, 2);
      expect(vera.title, 'Shared');
      expect(vera.songs.map((Song s) => s.title), <String>['A', 'B']);
      expect(vera.artworkPath, 'artwork/b.jpg');

      final AlbumItem unknown = albums.firstWhere(
        (AlbumItem a) => a.title == unknownAlbumName,
      );
      expect(unknown.artistName, unknownArtistName);
      expect(unknown.songCount, 1);
    });

    test('artists group by name and keep Unknown Artist last', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          availableSongsProvider.overrideWith((Ref ref) async => <Song>[
            tagged(1, 'A', artist: 'Vera', album: 'Shared'),
            tagged(2, 'B', artist: 'Vera', album: 'Shared'),
            tagged(3, 'X', artist: 'North', album: 'Other'),
            tagged(4, 'Z', artist: null, album: null),
          ]),
        ],
      );
      addTearDown(container.dispose);

      final List<ArtistItem> artists = await container.read(artistsProvider.future);
      expect(artists, hasLength(3));
      expect(artists.last.name, unknownArtistName);

      final ArtistItem vera = artists.firstWhere((ArtistItem a) => a.name == 'Vera');
      expect(vera.songCount, 2);
      expect(vera.songs.map((Song s) => s.title), <String>['A', 'B']);
    });
  });

  testWidgets('library chips switch between songs, playlists, artists, albums', (
    tester,
  ) async {
    FakeLibraryController.seed = <Song>[
      tagged(1, 'Alpha', artist: 'Vera Mono', album: 'Night Drive'),
      tagged(2, 'Beta', artist: 'Vera Mono', album: 'Night Drive'),
      tagged(3, 'Gamma', artist: 'North Garden', album: 'Parallel'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
          libraryProvider.overrideWith(FakeLibraryController.new),
          playlistsProvider.overrideWith(
            () => FakePlaylistsController(<Playlist>[
              playlist(1, 'Road', 2),
              playlist(2, 'Rainy', 0),
            ]),
          ),
          availableSongsProvider.overrideWith(
            (Ref ref) async => FakeLibraryController.seed,
          ),
        ],
        child: MaterialApp(
          theme: MusicOasisTheme.dark,
          home: const LibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.text('ALBUMS'));
    await tester.pumpAndSettle();
    expect(find.text('Night Drive'), findsOneWidget);
    expect(find.text('Parallel'), findsOneWidget);
    expect(find.text('2 SONGS'), findsOneWidget);
    expect(find.text('1 SONG'), findsOneWidget);
    expect(find.byType(SongArtwork), findsWidgets);

    await tester.tap(find.text('ARTISTS'));
    await tester.pumpAndSettle();
    expect(find.text('Vera Mono'), findsOneWidget);
    expect(find.text('North Garden'), findsOneWidget);
    expect(find.text('2 SONGS'), findsOneWidget);
    expect(find.text('1 SONG'), findsOneWidget);

    await tester.tap(find.text('PLAYLISTS'));
    await tester.pumpAndSettle();
    expect(find.text('Road'), findsOneWidget);
    expect(find.text('Rainy'), findsOneWidget);
    expect(find.text('2 SONGS'), findsOneWidget);
    expect(find.text('0 SONGS'), findsOneWidget);

    await tester.tap(find.text('SONGS'));
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final double width in <double>[320, 360, 393, 412]) {
    testWidgets('no overflow at ${width.toInt()}px across every library tab', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      FakeLibraryController.seed = <Song>[
        tagged(1, 'Alpha', artist: 'Vera Mono', album: 'Night Drive'),
        tagged(2, 'Beta', artist: 'Vera Mono', album: 'Night Drive'),
        tagged(3, 'Gamma', artist: 'North Garden', album: 'Parallel'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
            libraryProvider.overrideWith(FakeLibraryController.new),
            playlistsProvider.overrideWith(
              () => FakePlaylistsController(<Playlist>[
                playlist(1, 'Road', 2),
                playlist(2, 'Rainy', 0),
              ]),
            ),
            availableSongsProvider.overrideWith(
              (Ref ref) async => FakeLibraryController.seed,
            ),
          ],
          child: MaterialApp(
            theme: MusicOasisTheme.dark,
            home: const LibraryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final String chip in <String>['SONGS', 'PLAYLISTS', 'ARTISTS', 'ALBUMS']) {
        await _openChip(tester, chip);
      }
    });
  }

  testWidgets(
    'library song tap plays the whole loaded list from that song without leaving',
    (tester) async {
      FakeLibraryController.seed = <Song>[
        song(1, 'Alpha'),
        song(2, 'Beta'),
        song(3, 'Gamma', available: false),
      ];
      final FakePlaybackEngine engine = FakePlaybackEngine();

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            playbackEngineProvider.overrideWithValue(engine),
            libraryProvider.overrideWith(FakeLibraryController.new),
            availableSongsProvider.overrideWith((Ref ref) async => <Song>[
              song(1, 'Alpha'),
              song(2, 'Beta'),
            ]),
          ],
          child: MaterialApp(
            theme: MusicOasisTheme.dark,
            home: const LibraryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();

      expect(engine.loadCalls, 1);
      expect(engine.loadedTracks!.map((t) => t.title), <String>['Alpha', 'Beta']);
      expect(engine.loadedStart, 1);
      expect(find.text('LIBRARY'), findsOneWidget);
    },
  );

  testWidgets('album detail renders artwork and plays its songs as a queue', (
    tester,
  ) async {
    final AlbumItem album = AlbumItem(
      key: 'Vera Mono\u0000Night Drive',
      title: 'Night Drive',
      artistName: 'Vera Mono',
      songs: <Song>[song(1, 'Alpha'), song(2, 'Beta')],
    );
    final FakePlaybackEngine engine = FakePlaybackEngine();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playbackEngineProvider.overrideWithValue(engine),
        ],
        child: MaterialApp(
          theme: MusicOasisTheme.dark,
          home: AlbumDetailScreen(album: album),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Night Drive'), findsOneWidget);
    expect(find.text('2 SONGS'), findsOneWidget);
    expect(find.byType(SongArtwork), findsWidgets);
    expect(find.byType(AppBar), findsOneWidget);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(engine.loadCalls, 1);
    expect(engine.loadedTracks!.map((t) => t.title), <String>['Alpha', 'Beta']);
    expect(engine.loadedStart, 0);
    expect(find.text('Night Drive'), findsOneWidget);
  });

  testWidgets('artist detail tapping a later song starts there', (tester) async {
    final ArtistItem artist = ArtistItem(
      name: 'Vera Mono',
      songs: <Song>[song(1, 'Alpha'), song(2, 'Beta')],
    );
    final FakePlaybackEngine engine = FakePlaybackEngine();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playbackEngineProvider.overrideWithValue(engine),
        ],
        child: MaterialApp(
          theme: MusicOasisTheme.dark,
          home: ArtistDetailScreen(artist: artist),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vera Mono'), findsOneWidget);
    expect(find.byType(SongArtwork), findsWidgets);

    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();

    expect(engine.loadCalls, 1);
    expect(engine.loadedTracks!.map((t) => t.title), <String>['Alpha', 'Beta']);
    expect(engine.loadedStart, 1);
    expect(tester.takeException(), isNull);
  });
}

/// The pill chips row scrolls horizontally, so a label builds lazily — a wide
/// label may not exist until the row has been scrolled. Scroll to either end
/// and only tap once the label is actually hittable.
Future<void> _openChip(WidgetTester tester, String label) async {
  final ScrollableState chips = tester.state<ScrollableState>(
    find.byType(Scrollable).first,
  );
  final Finder candidate = find.text(label);
  for (final double offset in <double>[0, chips.position.maxScrollExtent]) {
    chips.position.jumpTo(offset);
    await tester.pumpAndSettle();
    if (candidate.hitTestable().evaluate().isNotEmpty) {
      await tester.tap(candidate);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      return;
    }
  }
  fail('Chip "$label" never became tappable.');
}