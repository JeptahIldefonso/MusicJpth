import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/song_artwork.dart';
import '../../../services/audio/playback_engine.dart';
import '../player_controller.dart';

/// Persistent bar above the translucent navigation during playback.
///
/// Smoked glass blur, sharp artwork, clean sans-serif typography. One shared
/// widget — anywhere navigation lives, the mini player lives with it.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerState player = ref.watch(playerProvider);
    final PlaybackEngine engine = ref.watch(playbackEngineProvider);
    final AudioTrack? track = player.currentTrack;

    if (track == null) return const SizedBox.shrink();

    // Transport-above-the-rest semantics: previous restarts a track that has
    // run past three seconds even when there is no earlier track, so the
    // button stays reachable exactly while it still has something to do.
    final Duration position =
        ref.read(playerPositionProvider).valueOrNull ?? Duration.zero;
    final bool canPrevious =
        player.hasQueue &&
        (engine.hasPrevious || position > const Duration(seconds: 3));
    final bool canNext = player.hasQueue && engine.hasNext;

    final ThemeData theme = Theme.of(context);
    final MusicOasisTokens tokens = MusicOasisTokens.of(context);
    final Color disabled = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.35,
    );

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: MusicOasisNav.blur,
          sigmaY: MusicOasisNav.blur,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.smokedGlass,
            border: Border(
              top: BorderSide(
                color: tokens.hairline,
                width: MusicOasisSpacing.hairline,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push(AppRoutes.player),
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: MusicOasisSpacing.md),
                      SongArtwork(
                        artworkPath: track.artworkPath,
                        size: 40,
                        iconSize: 16,
                      ),
                      const SizedBox(width: MusicOasisSpacing.sm),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              key: const ValueKey<String>('mini-subtitle'),
                              _subtitle(player),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: player.failure == null
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey<String>('mini-previous'),
                        tooltip: 'Previous',
                        visualDensity: VisualDensity.compact,
                        onPressed: canPrevious
                            ? () => ref
                                  .read(playerProvider.notifier)
                                  .previous(position: position)
                            : null,
                        icon: Icon(
                          Icons.skip_previous_rounded,
                          color: canPrevious
                              ? theme.colorScheme.onSurface
                              : disabled,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey<String>('mini-play-pause'),
                        tooltip: player.playing ? 'Pause' : 'Play',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => ref
                            .read(playerProvider.notifier)
                            .togglePlayPause(),
                        icon: Icon(
                          player.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey<String>('mini-next'),
                        tooltip: 'Next',
                        visualDensity: VisualDensity.compact,
                        onPressed: canNext
                            ? () => ref
                                  .read(playerProvider.notifier)
                                  .next()
                            : null,
                        icon: Icon(
                          Icons.skip_next_rounded,
                          color: canNext
                              ? theme.colorScheme.onSurface
                              : disabled,
                        ),
                      ),
                      const SizedBox(width: MusicOasisSpacing.sm),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(PlayerState player) {
    if (player.failure != null) return 'PLAYBACK FAILED';
    return player.currentTrack?.artist ?? 'Unknown Artist';
  }
}