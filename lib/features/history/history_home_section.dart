import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/song_artwork.dart';
import '../../data/models/song.dart';
import '../home/home_screen.dart' show playSongNow;
import 'playback_history_controller.dart';

/// RECENTLY PLAYED on Home: newest history entries, newest first.
class RecentPlaysSection extends ConsumerStatefulWidget {
  const RecentPlaysSection({super.key});

  @override
  ConsumerState<RecentPlaysSection> createState() => _RecentPlaysSectionState();
}

class _RecentPlaysSectionState extends ConsumerState<RecentPlaysSection> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(
      () => ref.read(playbackHistoryProvider.notifier).load(limit: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PlaybackHistoryState history = ref.watch(playbackHistoryProvider);

    if (!history.loaded) return const SizedBox.shrink();

    if (history.items.isEmpty) {
      return const EmptyState(message: 'Nothing played yet.');
    }

    return Column(
      children: <Widget>[
        for (int i = 0; i < history.items.take(8).length; i++)
          _HistoryRow(
            song: history.items[i],
            position: i + 1,
          ),
      ],
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.song, required this.position});

  final Song song;
  final int position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
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
        trailing: Text(_formatPlayedTime(song), style: tokens.metadata),
        onTap: song.isAvailable ? () => playSongNow(ref, song) : null,
      ),
    );
  }
}

String _formatPlayedTime(Song song) {
  final int? ms = song.playedAtMs;
  if (ms == null || ms <= 0) return '—';
  final DateTime played = DateTime.fromMillisecondsSinceEpoch(ms);
  final DateTime now = DateTime.now();
  final bool sameDay =
      played.year == now.year &&
      played.month == now.month &&
      played.day == now.day;
  final String hh = played.hour.toString().padLeft(2, '0');
  final String mm = played.minute.toString().padLeft(2, '0');
  return sameDay ? '$hh:$mm' : '${played.month}/${played.day}';
}
