import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/song_artwork.dart';
import '../../core/widgets/song_context_menu.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/repositories/playlist_repository_provider.dart';
import '../../data/repositories/song_repository_provider.dart'
    show availableSongsProvider;
import '../../services/audio/playback_engine.dart' show AudioTrack;
import '../player/player_controller.dart' show playerProvider;
import '../player/widgets/mini_player.dart';
import 'playlists_controller.dart';

/// Square playlist cover: up to four distinct artworks in play order, or a
/// music-note placeholder for art-less playlists.
///
/// The collage reserves a 2x2 cell grid (contiguous with the single-tile
/// case), fills cells in play order, and leaves any leftovers bare. Cells are
/// flex-bucketed and measured with [LayoutBuilder], so no cell can ever exceed
/// its column or row — the old tile arithmetic could not overflow a right
/// edge, but flex sizing makes that impossible by construction.
class PlaylistCover extends StatelessWidget {
  const PlaylistCover({required this.paths, required this.size, super.key});

  final List<String?> paths;
  final double size;

  static const int _columns = 2;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).extension<MusicOasisTokens>()!.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: switch (paths.length) {
        0 => Center(
          child: Icon(
            Icons.queue_music_outlined,
            size: size * 0.4,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        1 => _tile(paths[0]),
        _ => Column(
          children: <Widget>[
            Expanded(child: _row(0)),
            const SizedBox(height: MusicOasisSpacing.hairline),
            Expanded(child: _row(_columns)),
          ],
        ),
      },
    );
  }

  /// One collage row: two equally-divided, half-square cells (the collage is
  /// always a 2x2 grid; a row holds its cells plus the hairline gutter).
  Widget _row(int start) => Row(
    children: <Widget>[
      for (int i = start; i < start + _columns; i++) ...<Widget>[
        if (i > start) const SizedBox(width: MusicOasisSpacing.hairline),
        Expanded(child: i < paths.length ? _tile(paths[i]) : const SizedBox()),
      ],
    ],
  );

  /// Fills whatever space the flex parent hands it by measuring instead of
  /// assuming: artwork is sized to the cell width after flexing, so the tile
  /// and its neighbours sum to the cover exactly.
  Widget _tile(String? path) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double side = constraints.maxWidth;
      return SongArtwork(
        artworkPath: path,
        size: side,
        iconSize: side * 0.45,
      );
    },
  );
}

/// The PLAYLISTS destination: a responsive grid of cover cards.
class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() => ref.read(playlistsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final PlaylistsState state = ref.watch(playlistsProvider);

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
                  Text(
                    'PLAYLISTS',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ],
              ),
            ),
            Expanded(child: _body(context, state)),
            Padding(
              padding: const EdgeInsets.all(MusicOasisSpacing.lg),
              child: OutlinedButton(
                key: const ValueKey<String>('playlist-create'),
                onPressed: () => _create(context),
                child: const Text('NEW PLAYLIST'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, PlaylistsState state) {
    if (state.failure != null && state.items.isEmpty) {
      return EmptyState(message: state.failure!);
    }
    if (state.items.isEmpty) {
      return const EmptyState(message: 'No playlists yet.');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        MusicOasisSpacing.lg,
        MusicOasisSpacing.md,
        MusicOasisSpacing.lg,
        MusicOasisSpacing.lg,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisSpacing: MusicOasisSpacing.lg,
        crossAxisSpacing: MusicOasisSpacing.lg,
        mainAxisExtent: 240,
      ),
      itemCount: state.items.length,
      itemBuilder: (BuildContext context, int index) {
        final Playlist playlist = state.items[index];
        final List<String?> covers =
            state.covers[playlist.id] ?? const <String?>[];
        return _PlaylistCard(
          key: ValueKey<String>('playlist-card-${playlist.id}'),
          playlist: playlist,
          covers: covers,
          onTap: () => context.push('/playlists/${playlist.id}'),
          onRename: () => _rename(context, playlist),
          onDelete: () => _delete(context, playlist),
        );
      },
    );
  }

  Future<void> _rename(BuildContext context, Playlist playlist) async {
    final String? name = await _promptName(
      context,
      title: 'Rename playlist',
      initial: playlist.name,
    );
    if (name == null || name.isEmpty || name == playlist.name) return;
    if (!context.mounted) return;
    final String? failure = await ref
        .read(playlistsProvider.notifier)
        .rename(playlist.id, name);
    if (!context.mounted) return;
    _report(context, failure);
  }

  Future<void> _delete(BuildContext context, Playlist playlist) async {
    if (!await _confirmDeletePlaylist(context, playlist)) return;
    if (!context.mounted) return;
    await ref.read(playlistsProvider.notifier).delete(playlist.id);
  }

  Future<void> _create(BuildContext context) async {
    final String? name = await _promptName(context, title: 'New playlist');
    if (name == null || name.trim().isEmpty) return;
    if (!context.mounted) return;
    final String? failure = await ref
        .read(playlistsProvider.notifier)
        .create(name.trim());
    if (!context.mounted) return;
    _report(context, failure);
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.covers,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    super.key,
  });

  final Playlist playlist;
  final List<String?> covers;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

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
                    final double side = constraints.maxWidth.clamp(0.0, 192.0);
                    return SizedBox(
                      width: side,
                      height: side,
                      child: Stack(
                        children: [
                          PlaylistCover(paths: covers, size: side),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: PopupMenuButton<String>(
                                iconSize: 18,
                                tooltip: 'Options',
                                onSelected: (String action) {
                                  switch (action) {
                                    case 'rename':
                                      onRename.call();
                                    case 'delete':
                                      onDelete.call();
                                  }
                                },
                                itemBuilder: (BuildContext context) =>
                                    const <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'rename',
                                    child: Text('RENAME'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text('DELETE'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: MusicOasisSpacing.sm),
          Text(
            playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: MusicOasisSpacing.xs),
          Text(
            '${playlist.songCount} SONG${playlist.songCount == 1 ? '' : 'S'}',
            style: tokens.metadata,
          ),
        ],
      ),
    );
  }
}

/// Confirms a playlist deletion: the list goes, the songs never do.
Future<bool> _confirmDeletePlaylist(
  BuildContext context,
  Playlist playlist,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(
            'Delete Playlist?',
            style: Theme.of(dialogContext).textTheme.titleLarge,
          ),
          content: Text(
            '"${playlist.name}" will be removed. Your songs stay on the device.',
            style: Theme.of(dialogContext).textTheme.bodyMedium,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              key: const ValueKey<String>('delete-playlist-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: const Text('DELETE'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<String?> _promptName(
  BuildContext context, {
  required String title,
  String initial = '',
}) async {
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => _PromptNameDialog(
      title: title,
      initial: initial,
    ),
  );
}

class _PromptNameDialog extends StatefulWidget {
  const _PromptNameDialog({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_PromptNameDialog> createState() => _PromptNameDialogState();
}

class _PromptNameDialogState extends State<_PromptNameDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Name'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        TextButton(
          key: const ValueKey<String>('playlist-name-save'),
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}

void _report(BuildContext context, String? failure) {
  if (failure == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(failure)));
}

/// Playlist detail: ordered, reorderable, playable as a queue.
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({required this.playlistId, super.key});

  final int playlistId;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  late Future<List<String?>> _coversFuture;

  @override
  void initState() {
    super.initState();
    _coversFuture = _loadCovers();
    scheduleMicrotask(() {
      ref.read(playlistDetailProvider(widget.playlistId).notifier).load();
    });
  }

  Future<List<String?>> _loadCovers() async {
    final PlaylistRepository repository = await ref.read(
      playlistRepositoryProvider.future,
    );
    return repository.coverPaths(widget.playlistId);
  }

  Future<void> _openAddSongs(BuildContext context) async {
    final List<int>? selected = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) =>
          _AddSongsSheet(playlistId: widget.playlistId),
    );
    if (selected == null || selected.isEmpty || !context.mounted) return;

    final AddSongsResult result = await ref
        .read(playlistDetailProvider(widget.playlistId).notifier)
        .addSongs(selected);
    if (!context.mounted) return;
    setState(() {
      _coversFuture = _loadCovers();
    });
    if (result.failed) {
      _report(context, 'Songs could not be added to the playlist.');
    } else if (result.added > 0) {
      _report(
        context,
        'Added ${result.added} song${result.added == 1 ? '' : 's'} to the playlist.',
      );
    } else {
      _report(
        context,
        'All selected songs were already in the playlist.',
      );
    }
  }

  Playlist? _playlistOf(WidgetRef ref) {
    for (final Playlist playlist in ref.watch(playlistsProvider).items) {
      if (playlist.id == widget.playlistId) return playlist;
    }
    return null;
  }

  Future<void> _rename(Playlist playlist) async {
    final String? name = await _promptName(
      context,
      title: 'Rename playlist',
      initial: playlist.name,
    );
    if (name == null || name.isEmpty || name == playlist.name) return;
    if (!mounted) return;
    final String? failure = await ref
        .read(playlistsProvider.notifier)
        .rename(playlist.id, name);
    if (!mounted) return;
    _report(context, failure);
  }

  Future<void> _delete(Playlist playlist) async {
    if (!await _confirmDeletePlaylist(context, playlist)) return;
    if (!mounted) return;
    await ref.read(playlistsProvider.notifier).delete(playlist.id);
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final PlaylistDetailState detail = ref.watch(
      playlistDetailProvider(widget.playlistId),
    );
    final List<Song> songs = detail.songs;
    final Playlist? playlist = _playlistOf(ref);

    final List<AudioTrack> queue = _queueOf(songs);

    final ThemeData theme = Theme.of(context);
    final MusicOasisTokens tokens = MusicOasisTokens.of(context);
    final double cover = (MediaQuery.sizeOf(context).width -
            MusicOasisSpacing.lg * 2)
        .clamp(140.0, 280.0);

    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: 'Playlist options',
            onSelected: (String action) {
              switch (action) {
                case 'add_songs':
                  _openAddSongs(context);
                case 'rename':
                  if (playlist != null) _rename(playlist);
                case 'delete':
                  if (playlist != null) _delete(playlist);
              }
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'add_songs',
                child: Text('ADD SONGS'),
              ),
              PopupMenuItem<String>(
                value: 'rename',
                child: Text('RENAME'),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text('DELETE PLAYLIST'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MusicOasisSpacing.lg,
                0,
                MusicOasisSpacing.lg,
                MusicOasisSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Align(
                    alignment: Alignment.center,
                    child: FutureBuilder<List<String?>>(
                      future: _coversFuture,
                      builder: (BuildContext context, AsyncSnapshot<List<String?>> snapshot) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: PlaylistCover(
                            paths: snapshot.data ?? const <String?>[],
                            size: cover,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: MusicOasisSpacing.sm),
                  Text(
                    playlist?.name ?? 'PLAYLIST',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: MusicOasisSpacing.xs),
                  Text(
                    '${songs.length} SONG${songs.length == 1 ? '' : 'S'}',
                    textAlign: TextAlign.center,
                    style: tokens.metadataStrong,
                  ),
                  const SizedBox(height: MusicOasisSpacing.md),
                  Wrap(
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: MusicOasisSpacing.sm,
                    runSpacing: MusicOasisSpacing.xs,
                    children: <Widget>[
                      OutlinedButton(
                        key: const ValueKey<String>('playlist-add-songs'),
                        onPressed: () => _openAddSongs(context),
                        style: _pillButtonStyle(theme),
                        child: const Text('ADD SONGS'),
                      ),
                      OutlinedButton(
                        key: const ValueKey<String>('playlist-shuffle'),
                        onPressed: queue.isEmpty
                            ? null
                            : () => ref
                                  .read(playerProvider.notifier)
                                  .shuffleQueue(queue),
                        style: _pillButtonStyle(theme),
                        child: const Icon(Icons.shuffle, size: 18),
                      ),
                      FilledButton(
                        key: const ValueKey<String>('playlist-play'),
                        onPressed: queue.isEmpty
                            ? null
                            : () => ref
                                  .read(playerProvider.notifier)
                                  .playQueue(queue),
                        style:
                            FilledButton.styleFrom(shape: const StadiumBorder()),
                        child: const Text('PLAY ALL'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: MusicOasisTokens.of(context).hairline),
            Expanded(child: _list(context, detail, queue)),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    PlaylistDetailState detail,
    List<AudioTrack> queue,
  ) {
    switch (detail.status) {
      case DetailStatus.initial:
      case DetailStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case DetailStatus.ready when detail.songs.isEmpty:
        return EmptyState(
          message: 'Empty playlist.\nTap ADD SONGS to fill it from the library.',
        );
      case DetailStatus.ready:
        final List<Song> songs = detail.songs;
        return ReorderableListView.builder(
          buildDefaultDragHandles: false,
          itemCount: songs.length,
          onReorderItem: (int oldIndex, int newIndex) {
            ref
                .read(playlistDetailProvider(widget.playlistId).notifier)
                .move(from: oldIndex, to: newIndex);
          },
          footer: detail.failure == null
              ? null
              : Padding(
                  padding: const EdgeInsets.all(MusicOasisSpacing.lg),
                  child: Text(
                    detail.failure!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
          itemBuilder: (BuildContext context, int index) {
            // The tapped song opens the whole playlist queue at that song, so
            // Next/Previous walk the playlist and the tapped track is current.
            final int startIndex = _queueStartIndex(songs, index);
            return _DetailSongRow(
              key: ValueKey<String>('entry-${songs[index].id}-$index'),
              song: songs[index],
              position: index,
              onPlay: () => ref
                  .read(playerProvider.notifier)
                  .playQueue(queue, startIndex: startIndex),
              onRemove: () => ref
                  .read(playlistDetailProvider(widget.playlistId).notifier)
                  .removeAt(index),
            );
          },
        );
    }
  }

  /// The playable queue for [songs]: every available track in playlist order.
  List<AudioTrack> _queueOf(List<Song> songs) => <AudioTrack>[
    for (final Song song in songs)
      if (song.isAvailable) _trackOf(song),
  ];

  /// Queue position — among available tracks — of the row at [rowIndex], so a
  /// tap starts exactly the tapped song and the rows before it stay reachable
  /// via Previous. Taps only exist on available rows, so the result is >= 0.
  int _queueStartIndex(List<Song> songs, int rowIndex) {
    int available = 0;
    for (int i = 0; i <= rowIndex && i < songs.length; i++) {
      if (songs[i].isAvailable) available++;
    }
    final int start = available - 1;
    return start < 0 ? 0 : start;
  }
}

/// Shared pill button style for the detail controls.
ButtonStyle _pillButtonStyle(ThemeData theme) {
  final ButtonStyle flat = theme.outlinedButtonTheme.style ??
      OutlinedButton.styleFrom();
  return flat.copyWith(
    shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
  );
}

class _DetailSongRow extends StatelessWidget {
  const _DetailSongRow({
    required this.song,
    required this.position,
    required this.onPlay,
    required this.onRemove,
    super.key,
  });

  final Song song;

  /// Drag-handle index for the reorderable list.
  final int position;

  /// Starts the whole playlist queue at this song through the shared player;
  /// playback stays in the mini player and the detail remains on screen.
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Opacity(
      opacity: song.isAvailable ? 1 : 0.4,
      child: Row(
        children: <Widget>[
          Expanded(
            child: ListTile(
              contentPadding: const EdgeInsets.only(
                left: MusicOasisSpacing.lg,
                right: MusicOasisSpacing.xs,
              ),
              dense: true,
              leading: SongArtwork(
                artworkPath: song.artworkPath,
                size: 40,
                iconSize: 16,
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
              onTap: song.isAvailable ? onPlay : null,
            ),
          ),
          ReorderableDragStartListener(
            index: position,
            child: Padding(
              padding: const EdgeInsets.all(MusicOasisSpacing.sm),
              child: Icon(
                Icons.drag_indicator_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SongOptionsMenu(
            song: song,
            onRemoveFromPlaylist: onRemove,
          ),
          const SizedBox(width: MusicOasisSpacing.sm),
        ],
      ),
    );
  }
}

/// Full-library picker for adding songs to a playlist: search + multi-select.
class _AddSongsSheet extends ConsumerStatefulWidget {
  const _AddSongsSheet({required this.playlistId});

  final int playlistId;

  @override
  ConsumerState<_AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends ConsumerState<_AddSongsSheet> {
  final Set<int> _selected = <int>{};
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  late final Future<List<Song>> _library = _load();

  Future<List<Song>> _load() => ref.read(availableSongsProvider.future);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MusicOasisTokens tokens = MusicOasisTokens.of(context);
    final PlaylistDetailState detail = ref.watch(
      playlistDetailProvider(widget.playlistId),
    );
    final Set<int> existing = detail.songs.map((Song song) => song.id).toSet();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(MusicOasisSpacing.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'ADD SONGS',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  Text(
                    '${_selected.length} SELECTED',
                    key: const ValueKey<String>('add-songs-count'),
                    style: tokens.metadataStrong,
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MusicOasisSpacing.lg,
                0,
                MusicOasisSpacing.lg,
                MusicOasisSpacing.md,
              ),
              child: TextField(
                key: const ValueKey<String>('add-songs-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Search songs'),
              ),
            ),
            Divider(color: MusicOasisTokens.of(context).hairline),
            Expanded(
              child: FutureBuilder<List<Song>>(
                future: _library,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<Song>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    return const EmptyState(
                      message: 'Songs could not be loaded.',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final List<Song> filtered = _filter(snapshot.data!, existing);
                  if (filtered.isEmpty) {
                    return const EmptyState(message: 'No matching songs.');
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Song song = filtered[index];
                      final bool alreadyJoined = existing.contains(song.id);
                      final bool isSelected = _selected.contains(song.id);
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: MusicOasisSpacing.lg,
                        ),
                        leading: SongArtwork(
                          artworkPath: song.artworkPath,
                          size: 36,
                          iconSize: 14,
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          song.artistName ?? 'Unknown Artist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: alreadyJoined
                            ? Text(
                                'IN PLAYLIST',
                                style: tokens.metadata,
                              )
                            : Icon(
                                isSelected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                size: 20,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                        onTap: alreadyJoined
                            ? null
                            : () => setState(() {
                                  if (isSelected) {
                                    _selected.remove(song.id);
                                  } else {
                                    _selected.add(song.id);
                                  }
                                }),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(MusicOasisSpacing.lg),
              child: FilledButton(
                key: const ValueKey<String>('add-songs-confirm'),
                onPressed: _selected.isEmpty
                    ? null
                    : () =>
                        Navigator.of(context).pop(_selected.toList(growable: false)),
                child: Text(
                  'ADD ${_selected.isEmpty ? '' : '(${_selected.length}) '}TO PLAYLIST',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Song> _filter(List<Song> songs, Set<int> existing) {
    final String query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return songs;
    return <Song>[
      for (final Song song in songs)
        if (existing.contains(song.id) || _matches(song, query)) song,
    ];
  }

  bool _matches(Song song, String query) {
    if (song.title.toLowerCase().contains(query)) return true;
    final String? artist = song.artistName;
    if (artist != null && artist.toLowerCase().contains(query)) return true;
    final String? album = song.albumTitle;
    if (album != null && album.toLowerCase().contains(query)) return true;
    return false;
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