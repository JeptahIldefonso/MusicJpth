import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/repositories/playlist_repository_provider.dart';
import '../../features/favorites/favorites_controller.dart'
    show FavoriteIds, favoriteIdsProvider;
import '../../features/history/playback_history_controller.dart'
    show playbackHistoryProvider;
import '../../features/library/library_controller.dart' show libraryProvider;
import '../../features/player/player_controller.dart'
    show PlayerState, playerProvider;
import '../../features/playlists/playlists_controller.dart'
    show AddSongResult, PlaylistsState, playlistDetailProvider, playlistsProvider;
import '../../services/deletion/deletion_orchestrator.dart';
import '../../services/deletion/file_deletion_service.dart';

/// Toggles [song] in Favorites. The controller keeps the "favorite" write
/// itself; this only routes it from a menu.
void toggleFavorite(WidgetRef ref, Song song) {
  ref.read(favoriteIdsProvider.notifier).toggle(song.id);
}

/// Picks an existing playlist (or creates a new one) and adds [song] to it.
///
/// Shared by every song list so the flow — and its copy — is identical
/// whether the row lives in Home, the Library, Search or a playlist detail.
void addSongToPlaylist(BuildContext context, WidgetRef ref, Song song) {
  ref.read(playlistsProvider.notifier).load();
  showModalBottomSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) => SafeArea(
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, _) {
          final PlaylistsState playlists = ref.watch(playlistsProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(MusicOasisSpacing.md),
                child: Text(
                  'ADD TO PLAYLIST',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    ListTile(
                      key: const ValueKey<String>('add-to-new'),
                      leading: const Icon(Icons.add),
                      title: const Text('New playlist'),
                      onTap: () async {
                        final String? name = await _promptPlaylistName(
                          context,
                        );
                        if (name == null || name.isEmpty) return;
                        if (!context.mounted) return;
                        final PlaylistRepository repository = await ref.read(
                          playlistRepositoryProvider.future,
                        );
                        try {
                          final Playlist created = await repository.create(
                            name,
                          );
                          if (!context.mounted) return;
                          final AddSongResult result = await ref
                              .read(
                                playlistDetailProvider(created.id).notifier,
                              )
                              .addSong(song.id);
                          if (!context.mounted) return;
                          ref.read(playlistsProvider.notifier).load();
                          Navigator.of(context).pop();
                          if (result == AddSongResult.error) {
                            _snack(
                              context,
                              'Song could not be added to the playlist.',
                            );
                          }
                        } on PlaylistNameTaken {
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            _snack(context, 'That name is already in use.');
                          }
                        }
                      },
                    ),
                    for (final Playlist playlist in playlists.items)
                      ListTile(
                        key: ValueKey<String>('add-to-${playlist.id}'),
                        leading: const Icon(Icons.queue_music_outlined),
                        title: Text(playlist.name),
                        subtitle: Text(
                          '${playlist.songCount}',
                          style: MusicOasisTokens.of(context).metadata,
                        ),
                        onTap: () async {
                          if (!context.mounted) return;
                          final AddSongResult result = await ref
                              .read(
                                playlistDetailProvider(playlist.id).notifier,
                              )
                              .addSong(song.id);
                          if (!context.mounted) return;
                          ref.read(playlistsProvider.notifier).load();
                          Navigator.of(context).pop();
                          switch (result) {
                            case AddSongResult.added:
                              _snack(context, 'Added to playlist.');
                            case AddSongResult.duplicate:
                              _snack(context, 'Already in playlist.');
                            case AddSongResult.error:
                              _snack(
                                context,
                                'Song could not be added to the playlist.',
                              );
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

Future<String?> _promptPlaylistName(BuildContext context) {
  final TextEditingController controller = TextEditingController();
  try {
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          'New playlist',
          style: Theme.of(dialogContext).textTheme.titleLarge,
        ),
        content: TextField(controller: controller, autofocus: true),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

/// The song context menu every list row shares: favorite, add to a playlist,
/// (optionally) remove from the current playlist, and delete from device.
class SongOptionsMenu extends ConsumerWidget {
  const SongOptionsMenu({required this.song, super.key, this.onRemoveFromPlaylist});

  final Song song;

  /// Present only in playlist detail rows: removes the membership, never the
  /// file — the distinct semantics the spec demands.
  final VoidCallback? onRemoveFromPlaylist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool favorite = ref.watch(
      favoriteIdsProvider.select((FavoriteIds ids) => ids.contains(song.id)),
    );

    return PopupMenuButton<String>(
      tooltip: 'Options',
      onSelected: (String action) {
        switch (action) {
          case 'favorite':
            toggleFavorite(ref, song);
          case 'add_to_playlist':
            addSongToPlaylist(context, ref, song);
          case 'remove_from_playlist':
            onRemoveFromPlaylist?.call();
          case 'delete':
            confirmDeleteSong(context, ref, song);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'favorite',
          child: Text(favorite ? 'UNFAVORITE' : 'FAVORITE'),
        ),
        const PopupMenuItem<String>(
          value: 'add_to_playlist',
          child: Text('ADD TO PLAYLIST'),
        ),
        if (onRemoveFromPlaylist != null)
          const PopupMenuItem<String>(
            value: 'remove_from_playlist',
            child: Text('REMOVE FROM PLAYLIST'),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(
            'DELETE FROM DEVICE',
            style: TextStyle(
              color: scheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Runs the full delete-from-device flow:
///
/// 1. Music Oasis confirmation dialog
/// 2. Android system confirmation (MediaStore delete request)
/// 3. Physical file deletion by the platform
/// 4. Database row removal only on confirmed success (cascades clean playlist
///    memberships, favorites and playback history)
/// 5. UI refresh
///
/// Returns `true` only when the physical file was actually deleted.
Future<bool> confirmDeleteSong(
  BuildContext context,
  WidgetRef ref,
  Song song,
) async {
  // ── Step 1: Music Oasis confirmation dialog ──────────────────────────
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(
        'Delete Song?',
        style: Theme.of(dialogContext).textTheme.titleLarge,
      ),
      content: Text(
        'This will permanently delete this audio file from your device.',
        style: Theme.of(dialogContext).textTheme.bodyMedium,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          key: const ValueKey<String>('delete-song-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: MusicOasisPalette.error),
          child: const Text('DELETE'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return false;

  // ── Step 2: Stop playback if this song is playing ────────────────────
  final PlayerState player = ref.read(playerProvider);
  if (player.currentTrack?.songId == song.id) {
    debugPrint('DELETE_TRACE: stopping playback for song ${song.id}');
    await ref.read(playerProvider.notifier).stopPlayback();
  }

  // ── Step 3: Platform-mediated deletion (Android system confirmation) ─
  final DeletionResult result = await ref
      .read(deletionOrchestratorProvider)
      .deleteSongFromDevice(song.id);

  if (!context.mounted) return false;

  // ── Step 4: Act only on the real outcome ─────────────────────────────
  switch (result.status) {
    case DeletionStatus.success:
      _refresh(ref);
      _snack(context, 'Song deleted.');
      return true;

    case DeletionStatus.userCancelled:
      // Android confirmation was dismissed: the file and database are intact.
      _snack(context, 'Deletion cancelled.');
      return false;

    case DeletionStatus.fileNotFound:
      // The file is not known to MediaStore (or already gone outside the app).
      // The database row is KEPT — it is the scanner's job to mark missing
      // files unavailable, never delete rows.
      _snack(
        context,
        result.message ?? 'File not found on device. Try rescanning.',
      );
      return false;

    case DeletionStatus.permissionDenied:
      _snack(
        context,
        result.message ?? 'Android did not allow deleting this file.',
      );
      return false;

    case DeletionStatus.error:
      _snack(
        context,
        result.message ?? 'Could not delete the file.',
      );
      return false;
  }
}

void _refresh(WidgetRef ref) {
  ref.read(libraryProvider.notifier).loadInitial();
  ref.read(playlistsProvider.notifier).load();
  ref.invalidate(favoriteIdsProvider);
  ref.invalidate(playbackHistoryProvider);
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(duration: const Duration(seconds: 2), content: Text(message)),
    );
}