import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/song.dart';
import '../../data/repositories/playback_history_repository_provider.dart';
import '../../services/audio/playback_engine.dart';
import '../player/player_controller.dart';

/// When a play counts as played — the recorded design decision, since
/// neither `REQUIREMENTS.md` nor `PROJECT.md` fixes a threshold: at least
/// half the track heard, and never less than five seconds of it. One row per
/// track-session; seeks, pauses and ticks never duplicate a write.
const double historyThresholdFraction = 0.5;
const int historyMinListenMs = 5000;

/// Pure decision for one position tick. Unit-testable without streams.
bool shouldRecordHistory({
  required int positionMs,
  required int? durationMs,
  required bool alreadyRecorded,
}) {
  if (alreadyRecorded || durationMs == null || durationMs <= 0) return false;
  if (positionMs < historyMinListenMs) return false;
  return positionMs >= durationMs * historyThresholdFraction;
}

@immutable
class PlaybackHistoryState {
  const PlaybackHistoryState({
    this.items = const <Song>[],
    this.loaded = false,
  });

  final List<Song> items;

  /// Whether the initial load ran; Home shows its empty hint only after.
  final bool loaded;

  @override
  bool operator ==(Object other) =>
      other is PlaybackHistoryState &&
      other.loaded == loaded &&
      listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(loaded, Object.hashAll(items));
}

/// The recent-plays list shown on Home.
class PlaybackHistoryController extends Notifier<PlaybackHistoryState> {
  @override
  PlaybackHistoryState build() => const PlaybackHistoryState();

  /// Loads the newest [limit] plays. Called when Home becomes visible.
  Future<void> load({int limit = 50}) async {
    try {
      final repository = await ref.read(
        playbackHistoryRepositoryProvider.future,
      );
      state = PlaybackHistoryState(
        items: await repository.recent(limit: limit),
        loaded: true,
      );
    } on Object {
      state = PlaybackHistoryState(loaded: true);
    }
  }
}

final NotifierProvider<PlaybackHistoryController, PlaybackHistoryState>
playbackHistoryProvider =
    NotifierProvider<PlaybackHistoryController, PlaybackHistoryState>(
      PlaybackHistoryController.new,
    );

/// Records plays into history as playback crosses the threshold.
///
/// Self-contained below the screens: two low-frequency subscriptions (queue
/// index changes and the engine's existing ~1 Hz position stream), pure
/// arithmetic per tick, exactly one database write per track-session. No
/// widget subscribes to anything here, so position ticks cost no rebuilds
/// (`REQUIREMENTS.md` §41).
class PlaybackHistoryRecorder extends Notifier<void> {
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<int?>? _indexSub;

  int? _currentSongId;
  bool _recorded = false;

  @override
  void build() {
    final PlaybackEngine engine = ref.watch(playbackEngineProvider);
    _indexSub = engine.currentIndexStream.listen(_onIndexChanged);
    _positionSub = engine.positionStream.listen(_onPosition);
    ref.onDispose(() async {
      await _positionSub?.cancel();
      await _indexSub?.cancel();
      _positionSub = null;
      _indexSub = null;
    });
  }

  void _onIndexChanged(int? index) {
    // Leaving a track ends its session even if the threshold was never met.
    _currentSongId = null;
    _recorded = false;
    if (index == null) return;

    final PlayerState player = ref.read(playerProvider);
    if (index >= player.queue.length) return;
    _currentSongId = player.queue[index].songId;
  }

  Future<void> _onPosition(Duration position) async {
    if (_recorded || _currentSongId == null) return;
    final PlayerState player = ref.read(playerProvider);
    final int? durationMs =
        player.duration?.inMilliseconds ?? player.currentTrack?.durationMs;
    if (!shouldRecordHistory(
      positionMs: position.inMilliseconds,
      durationMs: durationMs,
      alreadyRecorded: _recorded,
    )) {
      return;
    }

    // Set before awaiting: a failed or slow write must not loop on ticks.
    _recorded = true;
    try {
      final repository = await ref.read(
        playbackHistoryRepositoryProvider.future,
      );
      await repository.add(_currentSongId!);
      // One bounded read per qualifying play keeps Home current without any
      // widget holding a stream.
      await ref.read(playbackHistoryProvider.notifier).load();
    } on Object {
      // History is best-effort; playback must never fail because of it.
    }
  }
}

final NotifierProvider<PlaybackHistoryRecorder, void>
playbackHistoryRecorderProvider =
    NotifierProvider<PlaybackHistoryRecorder, void>(
      PlaybackHistoryRecorder.new,
    );
