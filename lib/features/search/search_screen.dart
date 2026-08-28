import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/widgets/brand_header.dart';
import '../../core/widgets/song_artwork.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/song_context_menu.dart';
import '../../data/models/search_results.dart';
import '../../data/models/song.dart';
import '../../data/repositories/search_repository.dart' show groupLimit;
import '../../services/audio/playback_engine.dart' show AudioTrack;
import '../player/player_controller.dart' show playerProvider;
import '../library/widgets/library_filter_chips.dart';
import 'search_controller.dart';

enum _SearchCategory { all, songs, artists, albums, playlists }

const List<_SearchCategory> _searchCategories = <_SearchCategory>[
  _SearchCategory.all,
  _SearchCategory.songs,
  _SearchCategory.artists,
  _SearchCategory.albums,
  _SearchCategory.playlists,
];

String _categoryLabel(_SearchCategory category) => switch (category) {
  _SearchCategory.all => 'ALL',
  _SearchCategory.songs => 'SONGS',
  _SearchCategory.artists => 'ARTISTS',
  _SearchCategory.albums => 'ALBUMS',
  _SearchCategory.playlists => 'PLAYLISTS',
};

/// The SEARCH destination: debounced local-only queries against SQLite.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _field = TextEditingController();
  final FocusNode _focus = FocusNode();
  _SearchCategory _category = _SearchCategory.all;

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SearchState search = ref.watch(searchProvider);
    final ThemeData theme = Theme.of(context);

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
                  Text('SEARCH', style: theme.textTheme.displaySmall),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MusicOasisSpacing.lg,
                MusicOasisSpacing.md,
                MusicOasisSpacing.lg,
                MusicOasisSpacing.md,
              ),
              child: TextField(
                controller: _field,
                focusNode: _focus,
                onChanged: (String value) {
                  ref.read(searchProvider.notifier).onQueryChanged(value);
                  setState(() {});
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Type to search...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _field.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _field.clear();
                            ref
                                .read(searchProvider.notifier)
                                .onQueryChanged('');
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: MusicOasisSpacing.sm),
            LibraryFilterChips<_SearchCategory>(
              tabs: _searchCategories,
              selected: _category,
              onSelected: (cat) => setState(() => _category = cat),
              labelOf: _categoryLabel,
            ),
            const SizedBox(height: MusicOasisSpacing.sm),
            Expanded(child: _results(context, search, _category)),
          ],
        ),
      ),
    );
  }

  Widget _results(BuildContext context, SearchState search, _SearchCategory category) {
    switch (search.status) {
      case SearchStatus.idle:
        if (search.failure != null) {
          return EmptyState(message: search.failure!);
        }
        return const EmptyState(message: 'Search your library.');
      case SearchStatus.loading:
        return Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      case SearchStatus.results:
        final SearchResults? results = search.results;
        if (results == null || results.isEmpty) {
          return const EmptyState(message: 'No results found.');
        }
        return _ResultList(results: results, category: category);
    }
  }
}

class _ResultList extends ConsumerWidget {
  const _ResultList({required this.results, required this.category});

  final SearchResults results;
  final _SearchCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Widget> items = <Widget>[
      if ((category == _SearchCategory.all || category == _SearchCategory.songs) && results.songs.isNotEmpty)
        _Header(label: 'SONGS', more: results.capped['songs'] ?? false),
      if (category == _SearchCategory.all || category == _SearchCategory.songs)
        for (final Song song in results.songs)
          _SongRow(
            key: ValueKey<String>('song-${song.id}'),
            song: song,
            onTap: song.isAvailable ? () => _play(ref, song) : null,
          ),
      if ((category == _SearchCategory.all || category == _SearchCategory.artists) && results.artists.isNotEmpty)
        _Header(label: 'ARTISTS', more: results.capped['artists'] ?? false),
      if (category == _SearchCategory.all || category == _SearchCategory.artists)
        for (final NamedResult artist in results.artists)
          _NameRow(
            key: ValueKey<String>('artist-${artist.label}'),
            entry: artist,
          ),
      if ((category == _SearchCategory.all || category == _SearchCategory.albums) && results.albums.isNotEmpty)
        _Header(label: 'ALBUMS', more: results.capped['albums'] ?? false),
      if (category == _SearchCategory.all || category == _SearchCategory.albums)
        for (final NamedResult album in results.albums)
          _NameRow(key: ValueKey<String>('album-${album.label}'), entry: album),
      if ((category == _SearchCategory.all || category == _SearchCategory.playlists) && results.playlists.isNotEmpty)
        _Header(label: 'PLAYLISTS', more: results.capped['playlists'] ?? false),
      if (category == _SearchCategory.all || category == _SearchCategory.playlists)
        for (final NamedResult playlist in results.playlists)
          _NameRow(
            key: ValueKey<String>('playlist-${playlist.label}'),
            entry: playlist,
          ),
      if (category == _SearchCategory.all && results.genres.isNotEmpty)
        _Header(label: 'GENRES', more: results.capped['genres'] ?? false),
      if (category == _SearchCategory.all)
        for (final String genre in results.genres)
          _NameRow(
            key: ValueKey<String>('genre-$genre'),
            entry: NamedResult(label: genre),
          ),
    ];

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) => items[index],
    );
  }

  void _play(WidgetRef ref, Song song) {
    ref.read(playerProvider.notifier).playQueue(<AudioTrack>[
      _trackOf(song),
    ], startIndex: 0);
  }
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

class _Header extends StatelessWidget {
  const _Header({required this.label, required this.more});

  final String label;
  final bool more;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MusicOasisSpacing.lg,
        MusicOasisSpacing.lg,
        MusicOasisSpacing.lg,
        MusicOasisSpacing.xs,
      ),
      child: Text(
        more ? '$label · $groupLimit+' : label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SongRow extends ConsumerWidget {
  const _SongRow({
    required this.song,
    required this.onTap,
    super.key,
  });

  final Song song;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final MusicOasisTokens tokens = MusicOasisTokens.of(context);

    return Opacity(
      opacity: song.isAvailable ? 1 : 0.4,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MusicOasisSpacing.lg,
        ),
        leading: SongArtwork(
          artworkPath: song.artworkPath,
          size: MusicOasisArtwork.listSize,
        ),
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          song.isAvailable
              ? song.artistName ?? 'Unknown Artist'
              : 'FILE UNAVAILABLE',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              song.isAvailable ? _duration(song.durationMs) : '—',
              style: tokens.metadata,
            ),
            SongOptionsMenu(song: song),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _duration(int? ms) {
    if (ms == null || ms <= 0) return '—:—';
    final Duration duration = Duration(milliseconds: ms);
    final String seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '${duration.inMinutes}:$seconds';
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.entry, super.key});

  final NamedResult entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MusicOasisSpacing.lg,
      ),
      dense: true,
      title: Text(entry.label, style: theme.textTheme.titleSmall),
      subtitle: entry.detail == null
          ? null
          : Text(
              entry.detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}
