import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/song_artwork.dart';
import '../../data/models/song.dart';
import '../playlists/playlists_controller.dart'
    show PlaylistsState, playlistsProvider;
import '../playlists/playlists_screen.dart' show PlaylistCover;
import '../player/widgets/mini_player.dart';
import '../scanner/scanner_controller.dart'
    show ScanStatus, ScannerState, scannerProvider;
import 'browse_models.dart';
import 'browse_providers.dart';
import 'library_controller.dart';
import 'widgets/library_filter_chips.dart';
import 'widgets/paged_list_view.dart';
import 'widgets/song_list_tile.dart';

enum _LibraryTab { songs, playlists, artists, albums }

const List<_LibraryTab> _libraryTabs = <_LibraryTab>[
  _LibraryTab.songs,
  _LibraryTab.playlists,
  _LibraryTab.artists,
  _LibraryTab.albums,
];

String _tabLabel(_LibraryTab tab) => switch (tab) {
  _LibraryTab.songs => 'SONGS',
  _LibraryTab.playlists => 'PLAYLISTS',
  _LibraryTab.artists => 'ARTISTS',
  _LibraryTab.albums => 'ALBUMS',
};

/// The LIBRARY destination: chip tabs over the whole collection.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  _LibraryTab _tab = _LibraryTab.songs;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() => ref.read(libraryProvider.notifier).loadInitial());
  }

  @override
  Widget build(BuildContext context) {
    final LibraryState library = ref.watch(libraryProvider);
    final PlaylistsState playlists = ref.watch(playlistsProvider);

    ref.listen<ScannerState>(scannerProvider, (
      ScannerState? previous,
      ScannerState next,
    ) {
      final bool finished =
          next.status == ScanStatus.completed ||
          next.status == ScanStatus.cancelled;
      final bool wasRunning = previous?.status == ScanStatus.scanning;
      if (finished && wasRunning) {
        ref.read(libraryProvider.notifier).loadInitial();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MusicOasisSpacing.lg,
                MusicOasisSpacing.lg,
                MusicOasisSpacing.lg,
                MusicOasisSpacing.sm,
              ),
              child: Text(
                'LIBRARY',
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
            if (library.isEmpty && playlists.items.isEmpty)
              const Expanded(child: EmptyState(message: 'No songs in library yet.'))
            else ...<Widget>[
              LibraryFilterChips<_LibraryTab>(
                tabs: _libraryTabs,
                selected: _tab,
                onSelected: (tab) => setState(() => _tab = tab),
                labelOf: _tabLabel,
              ),
              const SizedBox(height: MusicOasisSpacing.sm),
              Expanded(child: _content(_tab)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _content(_LibraryTab tab) => switch (tab) {
    _LibraryTab.songs => const SongsTab(),
    _LibraryTab.playlists => const PlaylistsTab(),
    _LibraryTab.artists => const ArtistsTab(),
    _LibraryTab.albums => const AlbumsTab(),
  };
}

/// ─── SONGS tab ────────────────────────────────────────────────────────────

class SongsTab extends ConsumerWidget {
  const SongsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LibraryState library = ref.watch(libraryProvider);
    switch (library.status) {
      case LibraryStatus.initial:
      case LibraryStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case LibraryStatus.error when library.songs.isEmpty:
        return const EmptyState(message: 'The library could not be loaded.');
      case LibraryStatus.error:
      case LibraryStatus.ready:
        if (library.isEmpty) {
          return const EmptyState(message: 'No songs in library yet.');
        }
        return _SongPageList(library: library);
    }
  }
}

class _SongPageList extends ConsumerWidget {
  const _SongPageList({required this.library});

  final LibraryState library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PagedListView(
      itemCount: library.songs.length,
      itemBuilder: (BuildContext context, int index) {
        final Song song = library.songs[index];
        return SongListTile(
          song: song,
          onTap: song.isAvailable
              ? () => playSongQueue(ref, library.songs, index)
              : null,
        );
      },
      onReachEnd: () => ref.read(libraryProvider.notifier).loadMore(),
      hadMore: library.hasMore,
      loading: library.status == LibraryStatus.loading,
      error: library.status == LibraryStatus.error ? library.failure : null,
      onRetry: () => ref.read(libraryProvider.notifier).loadMore(),
    );
  }
}

/// ─── PLAYLISTS tab ────────────────────────────────────────────────────────

class PlaylistsTab extends ConsumerWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlaylistsState state = ref.watch(playlistsProvider);
    if (state.failure != null && state.items.isEmpty) {
      return EmptyState(message: state.failure!);
    }
    if (state.items.isEmpty) {
      return const EmptyState(message: 'No playlists yet.');
    }
    return PagedListView(
      itemCount: state.items.length,
      hadMore: false,
      onReachEnd: () {},
      itemBuilder: (BuildContext context, int index) {
        final playlist = state.items[index];
        final List<String?> covers =
            state.covers[playlist.id] ?? const <String?>[];
        return ListTile(
          leading: PlaylistCover(paths: covers, size: MusicOasisArtwork.listSize),
          title: Text(
            playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${playlist.songCount} SONG${playlist.songCount == 1 ? '' : 'S'}',
            style: MusicOasisTokens.of(context).metadata,
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => context.push('/playlists/${playlist.id}'),
        );
      },
    );
  }
}

/// ─── ARTISTS tab ──────────────────────────────────────────────────────────

class ArtistsTab extends ConsumerWidget {
  const ArtistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ArtistItem>> artists = ref.watch(artistsProvider);
    return artists.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) =>
          const EmptyState(message: 'The library could not be loaded.'),
      data: (List<ArtistItem> items) {
        if (items.isEmpty) {
          return const EmptyState(message: 'No artists yet.');
        }
        return PagedListView(
          itemCount: items.length,
          hadMore: false,
          onReachEnd: () {},
          itemBuilder: (BuildContext context, int index) {
            final ArtistItem artist = items[index];
            return ListTile(
              leading: SongArtwork(
                artworkPath: artist.artworkPath,
                size: MusicOasisArtwork.listSize,
              ),
              title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${artist.songCount} SONG${artist.songCount == 1 ? '' : 'S'}',
                style: MusicOasisTokens.of(context).metadata,
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () =>
                  context.push(AppRoutes.libraryArtist, extra: artist),
            );
          },
        );
      },
    );
  }
}

/// ─── ALBUMS tab ───────────────────────────────────────────────────────────

class AlbumsTab extends ConsumerWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AlbumItem>> albums = ref.watch(albumsProvider);
    return albums.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) =>
          const EmptyState(message: 'The library could not be loaded.'),
      data: (List<AlbumItem> items) {
        if (items.isEmpty) {
          return const EmptyState(message: 'No albums yet.');
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            MusicOasisSpacing.lg,
            MusicOasisSpacing.sm,
            MusicOasisSpacing.lg,
            MusicOasisSpacing.lg,
          ),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 210,
            mainAxisSpacing: MusicOasisSpacing.lg,
            crossAxisSpacing: MusicOasisSpacing.lg,
            mainAxisExtent: 268,
          ),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) {
            final AlbumItem album = items[index];
            return _AlbumCard(
              album: album,
              onTap: () => context.push(AppRoutes.libraryAlbum, extra: album),
            );
          },
        );
      },
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.onTap});

  final AlbumItem album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MusicOasisTokens tokens = MusicOasisTokens.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double side = constraints.maxWidth.clamp(0.0, 200.0);
                    return SongArtwork(
                      artworkPath: album.artworkPath,
                      size: side,
                      iconSize: 48,
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: MusicOasisSpacing.sm),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: MusicOasisSpacing.xs),
          Text(
            album.artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: MusicOasisSpacing.xs),
          Text(
            '${album.songCount} SONG${album.songCount == 1 ? '' : 'S'}',
            style: tokens.metadata,
          ),
        ],
      ),
    );
  }
}

/// Full song list view.
class LibrarySongList extends ConsumerStatefulWidget {
  const LibrarySongList({super.key});

  @override
  ConsumerState<LibrarySongList> createState() => _LibrarySongListState();
}

class _LibrarySongListState extends ConsumerState<LibrarySongList> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MusicOasisSpacing.lg,
                MusicOasisSpacing.lg,
                MusicOasisSpacing.lg,
                MusicOasisSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  const BackButton(),
                  const SizedBox(width: MusicOasisSpacing.xs),
                  Expanded(
                    child: Text(
                      'SONGS',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(child: SongsTab()),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }
}