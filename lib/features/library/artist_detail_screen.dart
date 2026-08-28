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

/// One artist's songs, pushed from the Library artist list.
class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({required this.artist, super.key});

  final ArtistItem artist;

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
                        artworkPath: artist.artworkPath,
                        size: cover,
                        iconSize: 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: MusicOasisSpacing.sm),
                  Text(
                    artist.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: MusicOasisSpacing.xs),
                  Text(
                    '${artist.songCount} SONG${artist.songCount == 1 ? '' : 'S'}',
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
    if (artist.songs.isEmpty) {
      return const EmptyState(message: 'No songs by this artist.');
    }
    return PagedListView(
      itemCount: artist.songs.length,
      hadMore: false,
      onReachEnd: () {},
      itemBuilder: (BuildContext context, int index) {
        final Song song = artist.songs[index];
        return SongListTile(
          song: song,
          onTap: song.isAvailable
              ? () => playSongQueue(ref, artist.songs, index)
              : null,
        );
      },
    );
  }
}