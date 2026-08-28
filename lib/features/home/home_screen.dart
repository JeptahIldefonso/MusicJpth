import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/widgets/brand_header.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/song_artwork.dart';
import '../../core/widgets/song_context_menu.dart';
import '../../data/models/song.dart';
import '../../services/audio/playback_engine.dart' show AudioTrack;
import '../player/player_controller.dart' show playerProvider;
import '../library/library_controller.dart'
    show LibraryState, LibraryStatus, libraryProvider;

import '../library/library_screen.dart';
import '../library/widgets/library_filter_chips.dart';

enum _HomeTab { songs, playlists, artists, albums }

const List<_HomeTab> _homeTabs = <_HomeTab>[
  _HomeTab.songs,
  _HomeTab.playlists,
  _HomeTab.artists,
  _HomeTab.albums,
];

String _tabLabel(_HomeTab tab) => switch (tab) {
  _HomeTab.songs => 'SONGS',
  _HomeTab.playlists => 'PLAYLISTS',
  _HomeTab.artists => 'ARTISTS',
  _HomeTab.albums => 'ALBUMS',
};

/// The HOME destination: entry points into the local library.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _HomeTab _tab = _HomeTab.songs;

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
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const BrandHeader(),
                  const SizedBox(height: MusicOasisSpacing.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'HOME',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            color:
                                Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey<String>('home-settings'),
                        tooltip: 'Settings',
                        onPressed: () => context.push(AppRoutes.settings),
                        icon: Icon(
                          Icons.settings_outlined,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: MusicOasisSpacing.md),
            LibraryFilterChips<_HomeTab>(
              tabs: _homeTabs,
              selected: _tab,
              onSelected: (tab) => setState(() => _tab = tab),
              labelOf: _tabLabel,
            ),
            const SizedBox(height: MusicOasisSpacing.sm),
            Expanded(child: _content(_tab)),
          ],
        ),
      ),
    );
  }

  Widget _content(_HomeTab tab) => switch (tab) {
    _HomeTab.songs => const _SongsHomeTab(),
    _HomeTab.playlists => const PlaylistsTab(),
    _HomeTab.artists => const ArtistsTab(),
    _HomeTab.albums => const AlbumsTab(),
  };
}

class _SongsHomeTab extends StatelessWidget {
  const _SongsHomeTab();

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      slivers: <Widget>[
        _AllSongsHeader(),
        _AllSongsList(),
        SliverPadding(
          padding: EdgeInsets.only(bottom: MusicOasisSpacing.xxl),
          sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
      ],
    );
  }
}

/// Shared play action.
void playSongNow(WidgetRef ref, Song song) {
  ref.read(playerProvider.notifier).playQueue(<AudioTrack>[
    AudioTrack(
      path: song.path,
      title: song.title,
      songId: song.id,
      artworkPath: song.artworkPath,
      artist: song.artistName,
      album: song.albumTitle,
      durationMs: song.durationMs,
    ),
  ]);
}

/// Plays every available song in [songs] starting at [index], fully shuffled.
void _shufflePlayAll(WidgetRef ref, List<Song> songs, int startIndex) {
  final math.Random rng = math.Random();
  final List<Song> available =
      songs.where((Song s) => s.isAvailable).toList()..shuffle(rng);
  if (available.isEmpty) return;
  final int start = startIndex.clamp(0, available.length - 1);
  ref.read(playerProvider.notifier).playQueue(
    <AudioTrack>[
      for (final Song song in available)
        AudioTrack(
          path: song.path,
          title: song.title,
          songId: song.id,
          artworkPath: song.artworkPath,
          artist: song.artistName,
          album: song.albumTitle,
          durationMs: song.durationMs,
        ),
    ],
    startIndex: start,
  );
}

/// "ALL SONGS" header with count and SHUFFLE button.
class _AllSongsHeader extends ConsumerStatefulWidget {
  const _AllSongsHeader();

  @override
  ConsumerState<_AllSongsHeader> createState() => _AllSongsHeaderState();
}

class _AllSongsHeaderState extends ConsumerState<_AllSongsHeader> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() => ref.read(libraryProvider.notifier).loadInitial());
  }

  @override
  Widget build(BuildContext context) {
    final LibraryState library = ref.watch(libraryProvider);
    final MusicOasisTokens tokens = MusicOasisTokens.of(context);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        MusicOasisSpacing.lg,
        MusicOasisSpacing.lg,
        MusicOasisSpacing.lg,
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SectionHeader('ALL SONGS'),
                  if (library.songs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${library.songs.length}',
                        style: tokens.metadata,
                      ),
                    ),
                ],
              ),
            ),
            if (library.songs.isNotEmpty)
              TextButton.icon(
                key: const ValueKey<String>('home-shuffle'),
                onPressed: () => _shufflePlayAll(ref, library.songs, 0),
                icon: const Icon(Icons.shuffle, size: 18),
                label: const Text('SHUFFLE'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lazy list of every song in the library.
class _AllSongsList extends ConsumerWidget {
  const _AllSongsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LibraryState library = ref.watch(libraryProvider);

    if (library.songs.isEmpty) {
      return const SliverPadding(
        padding: EdgeInsets.symmetric(vertical: MusicOasisSpacing.xxl),
        sliver: SliverToBoxAdapter(
          child: EmptyState(message: 'No songs in library yet.'),
        ),
      );
    }

    final int itemCount =
        library.songs.length +
        (library.hasMore ? 1 : 0) +
        (library.status == LibraryStatus.loading && !library.hasMore ? 1 : 0);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: MusicOasisSpacing.lg),
      sliver: SliverList.builder(
        itemCount: itemCount,
        itemBuilder: (BuildContext context, int index) {
          if (index >= library.songs.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: MusicOasisSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final Song song = library.songs[index];
          if (library.hasMore && index >= library.songs.length - 10) {
            scheduleMicrotask(
              () => ref.read(libraryProvider.notifier).loadMore(),
            );
          }
          return _SongRow(
            song: song,
            onTap: song.isAvailable
                ? () => _playFrom(ref, library.songs, index)
                : null,
          );
        },
      ),
    );
  }
}

class _SongRow extends ConsumerWidget {
  const _SongRow({required this.song, this.onTap});

  final Song song;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MusicOasisTokens tokens = MusicOasisTokens.of(context);

    return Opacity(
      opacity: song.isAvailable ? 1 : 0.4,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: SongArtwork(
          artworkPath: song.artworkPath,
          size: MusicOasisArtwork.listSize,
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          song.isAvailable
              ? song.artistName ?? 'Unknown Artist'
              : 'FILE UNAVAILABLE',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              song.isAvailable ? _formatDuration(song.durationMs) : '—',
              style: tokens.metadata,
            ),
            SongOptionsMenu(song: song),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

void _playFrom(WidgetRef ref, List<Song> songs, int index) {
  final AudioTrack tapped = _trackOf(songs[index]);
  final List<AudioTrack> queue = <AudioTrack>[
    for (final Song song in songs)
      if (song.isAvailable) _trackOf(song),
  ];
  ref
      .read(playerProvider.notifier)
      .playQueue(queue, startIndex: queue.indexOf(tapped));
}

AudioTrack _trackOf(Song song) => AudioTrack(
  path: song.path,
  title: song.title,
  songId: song.id,
  artworkPath: song.artworkPath,
  artist: song.artistName,
  album: song.albumTitle,
  durationMs: song.durationMs,
);

String _formatDuration(int? durationMs) {
  if (durationMs == null || durationMs <= 0) return '—:—';
  final Duration duration = Duration(milliseconds: durationMs);
  final int minutes = duration.inMinutes.remainder(Duration.minutesPerHour);
  final int seconds = duration.inSeconds.remainder(Duration.secondsPerMinute);
  if (duration.inHours > 0) {
    return '${duration.inHours}:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
