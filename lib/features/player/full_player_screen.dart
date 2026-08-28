import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../services/audio/playback_engine.dart' as engine;
import '../../core/widgets/song_artwork.dart';
import '../favorites/favorites_controller.dart'
    show FavoriteIds, favoriteIdsProvider;
import '../player/player_controller.dart';

/// The FULL PLAYER surface: dark background (#111111), white text,
/// large artwork, transport controls.
///
/// Rebuild discipline: header and transport listen to [playerProvider]
/// only; seek bar and timestamps subscribe to [playerPositionProvider].
class FullPlayerScreen extends ConsumerWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerState player = ref.watch(playerProvider);
    final engine.AudioTrack? track = player.currentTrack;

    return Scaffold(
      backgroundColor: MusicOasisPalette.darkBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: <Widget>[
                // Dismiss header
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close,
                      color: MusicOasisPalette.white,
                    ),
                  ),
                ),
                // Artwork
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MusicOasisSpacing.lg,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: MusicOasisArtwork.playerSize,
                        height: MusicOasisArtwork.playerSize,
                        child: SongArtwork(
                          artworkPath: track?.artworkPath,
                          size: MusicOasisArtwork.playerSize,
                          accent: false,
                          iconSize: 56,
                        ),
                      ),
                    ),
                  ),
                ),
                // Title + artist + album
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MusicOasisSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        track?.title ?? '—',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: MusicOasisSpacing.xs),
                      Text(
                        _subtitle(player),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamilyFallback:
                              MusicOasisTokens.bodyFamilyFallback,
                          fontSize: 13,
                          color: player.failure == null
                              ? MusicOasisPalette.textSecondary
                              : MusicOasisPalette.error,
                        ),
                      ),
                      if (track case final t? when t.album?.isNotEmpty == true) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          t.album!,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: MusicOasisPalette.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: MusicOasisSpacing.lg),
                // Seek bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MusicOasisSpacing.lg,
                  ),
                  child: _ProgressArea(track: track),
                ),
                // Transport
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    MusicOasisSpacing.md,
                    MusicOasisSpacing.sm,
                    MusicOasisSpacing.md,
                    MusicOasisSpacing.lg,
                  ),
                  child: _Transport(player: player),
                ),
                // Bottom row: favorite + queue
                Padding(
                  padding: const EdgeInsets.only(bottom: MusicOasisSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _FavoriteControl(songId: player.currentTrack?.songId),
                      const SizedBox(width: MusicOasisSpacing.xl),
                      Icon(
                        Icons.queue_music_outlined,
                        color: MusicOasisPalette.white.withValues(alpha: 0.6),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
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

/// Seek bar and timestamps. Subscribes to position ticks.
class _ProgressArea extends ConsumerStatefulWidget {
  const _ProgressArea({required this.track});

  final engine.AudioTrack? track;

  @override
  ConsumerState<_ProgressArea> createState() => _ProgressAreaState();
}

class _ProgressAreaState extends ConsumerState<_ProgressArea> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final PlayerState player = ref.watch(playerProvider);
    final Duration? duration =
        player.duration ??
        (widget.track?.durationMs == null
            ? null
            : Duration(milliseconds: widget.track!.durationMs!));
    final Duration position =
        ref.watch(playerPositionProvider).valueOrNull ?? Duration.zero;

    final int totalMs = duration?.inMilliseconds ?? 0;
    final double positionValue =
        _dragValue ?? position.inMilliseconds.clamp(0, totalMs).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: MusicOasisPalette.white,
            inactiveTrackColor: MusicOasisPalette.white.withValues(alpha: 0.2),
            thumbColor: MusicOasisPalette.white,
            overlayColor: MusicOasisPalette.white.withValues(alpha: 0.08),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: totalMs > 0 && positionValue <= totalMs ? positionValue : 0,
            max: totalMs > 0 ? totalMs.toDouble() : 1,
            onChanged: totalMs > 0
                ? (double value) => setState(() => _dragValue = value)
                : null,
            onChangeEnd: totalMs > 0
                ? (double value) {
                    ref
                        .read(playerProvider.notifier)
                        .seek(Duration(milliseconds: value.round()));
                    setState(() => _dragValue = null);
                  }
                : null,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              _format(position),
              style: const TextStyle(
                fontFamilyFallback: MusicOasisTokens.monoFamilyFallback,
                fontSize: 12,
                height: 1.3,
                letterSpacing: 0.4,
                color: MusicOasisPalette.textSecondary,
              ),
            ),
            Text(
              duration == null ? '--:--' : _format(duration),
              style: const TextStyle(
                fontFamilyFallback: MusicOasisTokens.monoFamilyFallback,
                fontSize: 12,
                height: 1.3,
                letterSpacing: 0.4,
                color: MusicOasisPalette.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _format(Duration duration) {
    final int hours = duration.inHours;
    final String minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(hours > 0 ? 2 : 1, '0');
    final String seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

/// Transport row: shuffle · previous · play/pause · next · repeat.
class _Transport extends ConsumerWidget {
  const _Transport({required this.player});

  final PlayerState player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerController controller = ref.read(playerProvider.notifier);

    IconData repeatIcon = Icons.repeat;
    if (player.repeat == engine.RepeatMode.one) repeatIcon = Icons.repeat_one;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        IconButton(
          tooltip: 'Shuffle',
          onPressed: () => ref.read(playerProvider.notifier).toggleShuffle(),
          icon: Icon(
            Icons.shuffle_outlined,
            color: player.shuffled
                ? MusicOasisPalette.white
                : MusicOasisPalette.white.withValues(alpha: 0.4),
          ),
        ),
        IconButton(
          key: const ValueKey<String>('full-previous'),
          tooltip: 'Previous',
          onPressed: () {
            final Duration position =
                ref.read(playerPositionProvider).valueOrNull ?? Duration.zero;
            controller.previous(position: position);
          },
          icon: const Icon(
            Icons.skip_previous_outlined,
            color: MusicOasisPalette.white,
          ),
          iconSize: 34,
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: MusicOasisPalette.white,
              width: MusicOasisSpacing.hairline,
            ),
          ),
          child: IconButton(
            key: const ValueKey<String>('full-play-pause'),
            tooltip: player.playing ? 'Pause' : 'Play',
            onPressed: () => controller.togglePlayPause(),
            icon: Icon(
              player.playing ? Icons.pause : Icons.play_arrow,
              size: 36,
              color: MusicOasisPalette.white,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey<String>('full-next'),
          tooltip: 'Next',
          onPressed: () => controller.next(),
          icon: const Icon(
            Icons.skip_next_outlined,
            color: MusicOasisPalette.white,
          ),
          iconSize: 34,
        ),
        IconButton(
          tooltip: 'Repeat',
          onPressed: () => ref.read(playerProvider.notifier).cycleRepeatMode(),
          icon: Icon(
            repeatIcon,
            color: player.repeat != engine.RepeatMode.off
                ? MusicOasisPalette.white
                : MusicOasisPalette.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

/// Favorite toggle on the Now Playing screen.
class _FavoriteControl extends ConsumerWidget {
  const _FavoriteControl({required this.songId});

  final int? songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool favorite = ref.watch(
      favoriteIdsProvider.select((FavoriteIds ids) => ids.contains(songId)),
    );

    return IconButton(
      tooltip: favorite ? 'Unfavorite' : 'Favorite',
      onPressed: songId == null
          ? null
          : () => ref.read(favoriteIdsProvider.notifier).toggle(songId!),
      icon: Icon(
        favorite ? Icons.favorite : Icons.favorite_outline,
        color: MusicOasisPalette.white,
      ),
    );
  }
}
