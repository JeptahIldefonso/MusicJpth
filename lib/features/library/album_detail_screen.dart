import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/song_artwork.dart';
import '../../data/models/song.dart';
import '../player/widgets/mini_player.dart';
import 'browse_models.dart';
import 'widgets/paged_list_view.dart';
import 'widgets/song_list_tile.dart';

/// One album's songs, pushed from the Library album grid.
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({required this.album, super.key});

  final AlbumItem album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final double cover = (MediaQuery.sizeOf(context).width -
            MusicOasisSpacing.lg * 2)
        .clamp(140.0, 280.0);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MusicOasisSpacing.lg,
                MusicOasisSpacing.sm,
                MusicOasisSpacing.lg,
                MusicOasisSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SongArtwork(
                        artworkPath: album.artworkPath,
                        size: cover,
                        iconSize: 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: MusicOasisSpacing.sm),
                  Text(
                    album.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: MusicOasisSpacing.xs),
                  Text(
                    album.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: MusicOasisSpacing.xs),
                  Text(
                    '${album.songCount} SONG${album.songCount == 1 ? '' : 'S'}',
                    style: MusicOasisTokens.of(context).metadataStrong,
                  ),
                ],
              ),
            ),
            Divider(color: MusicOasisTokens.of(context).hairline),
            Expanded(child: _songs(context, ref)),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _songs(BuildContext context, WidgetRef ref) {
    if (album.songs.isEmpty) {
      return const EmptyState(message: 'No songs in this album.');
    }
    return PagedListView(
      itemCount: album.songs.length,
      hadMore: false,
      onReachEnd: () {},
      itemBuilder: (BuildContext context, int index) {
        final Song song = album.songs[index];
        return SongListTile(
          song: song,
          onTap: song.isAvailable
              ? () => playSongQueue(ref, album.songs, index)
              : null,
        );
      },
    );
  }
}