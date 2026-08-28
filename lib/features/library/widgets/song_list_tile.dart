import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/song_artwork.dart';
import '../../../core/widgets/song_context_menu.dart';
import '../../../data/models/song.dart';
import '../../../services/audio/playback_engine.dart' show AudioTrack;
import '../../favorites/favorites_controller.dart'
    show FavoriteIds, favoriteIdsProvider;
import '../../player/player_controller.dart' show playerProvider;

/// One song row shared by the Library song tab, album detail and artist detail.
///
/// Artwork, bold white title, muted artist, duration, favorite heart and the
/// shared context menu. The whole row is one tap target; availability dims it.
class SongListTile extends ConsumerWidget {
  const SongListTile({required this.song, this.onTap, super.key});

  final Song song;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final MusicOasisTokens tokens = MusicOasisTokens.of(context);

    return Opacity(
      opacity: song.isAvailable ? 1 : 0.4,
      child: ListTile(
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
            _FavoriteButton(songId: song.id),
            const SizedBox(width: MusicOasisSpacing.xs),
            Text(
              song.isAvailable ? _formatDuration(song.durationMs) : '—',
              style: song.isAvailable ? tokens.metadata : tokens.metadataStrong,
            ),
            SongOptionsMenu(song: song),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Starts the whole list as a playable queue from the tapped row, so
/// Next/Previous walk the list and the tapped song is current.
void playSongQueue(WidgetRef ref, List<Song> songs, int index) {
  final AudioTrack tapped = trackOf(songs[index]);
  final List<AudioTrack> queue = <AudioTrack>[
    for (final Song song in songs)
      if (song.isAvailable) trackOf(song),
  ];
  ref
      .read(playerProvider.notifier)
      .playQueue(queue, startIndex: queue.indexOf(tapped));
}

AudioTrack trackOf(Song song) => AudioTrack(
  path: song.path,
  title: song.title,
  songId: song.id,
  artworkPath: song.artworkPath,
  artist: song.artistName,
  album: song.albumTitle,
  durationMs: song.durationMs,
);

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.songId});

  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool favorite = ref.watch(
      favoriteIdsProvider.select((FavoriteIds ids) => ids.contains(songId)),
    );
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        tooltip: favorite ? 'Unfavorite' : 'Favorite',
        padding: EdgeInsets.zero,
        iconSize: 18,
        onPressed: () => ref.read(favoriteIdsProvider.notifier).toggle(songId),
        icon: Icon(
          favorite ? Icons.favorite : Icons.favorite_outline,
          color: favorite ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

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