import 'dart:async';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_error.dart';
import '../../services/audio/playback_engine.dart';

/// Everything the player UI needs about the current session — except the
/// ticking position, which has its own provider below so a progress update
/// never rebuilds a whole screen (`REQUIREMENTS.md` §41).
@immutable
class PlayerState {
  const PlayerState({
    this.queue = const <AudioTrack>[],
    this.currentIndex,
    this.playing = false,
    this.duration,
    this.shuffled = false,
    this.repeat = RepeatMode.off,
    this.failure,
  });

  final List<AudioTrack> queue;
  final int? currentIndex;
  final bool playing;

  /// Duration of the current track, `null` until the engine reports it.
  final Duration? duration;

  final bool shuffled;
  final RepeatMode repeat;

  /// Last playback failure, cleared by the next successful command.
  final String? failure;

  bool get hasQueue => queue.isNotEmpty && currentIndex != null;

  AudioTrack? get currentTrack =>
      currentIndex == null || currentIndex! >= queue.length
      ? null
      : queue[currentIndex!];

  @override
  bool operator ==(Object other) =>
      other is PlayerState &&
      other.playing == playing &&
      other.duration == duration &&
      other.shuffled == shuffled &&
      other.repeat == repeat &&
      other.failure == failure &&
      other.currentIndex == currentIndex &&
      listEquals(other.queue, queue);

  @override
  int get hashCode => Object.hash(
    playing,
    duration,
    shuffled,
    repeat,
    failure,
    currentIndex,
    Object.hashAll(queue),
  );
}

/// The audio engine, built once in `main` before `runApp` because
/// audio_service requires it, then injected here. Overriding this one
/// provider swaps real playback for a fake in tests.
final Provider<PlaybackEngine> playbackEngineProvider =
    Provider<PlaybackEngine>(
      (Ref ref) => throw UnimplementedError(
        'playbackEngineProvider must be overridden before runApp',
      ),
    );

/// Playback position as its own stream, subscribed to only by widgets that
/// show it (mini player, seek bar).
final StreamProvider<Duration> playerPositionProvider =
    StreamProvider<Duration>(
      (Ref ref) => ref.watch(playbackEngineProvider).positionStream,
    );

/// Drives the [PlaybackEngine] and publishes its state.
///
/// Owns no platform code: every command maps onto the engine seam, so the
/// same controller serves taps, notification buttons and headset events
/// (`REQUIREMENTS.md` §08/§12).
class PlayerController extends Notifier<PlayerState> {
  Set<StreamSubscription<dynamic>> _subscriptions =
      const <StreamSubscription<dynamic>>{};

  @override
  PlayerState build() {
    final PlaybackEngine engine = ref.watch(playbackEngineProvider);
    _subscriptions = <StreamSubscription<dynamic>>{
      engine.playingStream.listen(
        (bool playing) => state = _copy(playing: playing),
      ),
      engine.durationStream.listen(
        (Duration? duration) => state = _copy(duration: duration),
      ),
      engine.currentIndexStream.listen((int? index) {
        state = _copy(currentIndex: index);
      }),
      engine.failureStream.listen((PlaybackFailure failure) {
        state = _copy(failure: failure.message);
      }),
    };
    ref.onDispose(() async {
      for (final StreamSubscription<dynamic> subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions = const <StreamSubscription<dynamic>>{};
    });
    return const PlayerState();
  }

  /// Starts [tracks] as the new queue at [startIndex].
  ///
  /// Tapping into a queue already loaded in the engine seeks instead of
  /// reloading — no re-decode, no audible gap (`REQUIREMENTS.md` §31).
  /// Either way the user acted, so any recorded failure is dismissed.
  Future<void> playQueue(List<AudioTrack> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    if (_isLoadedQueue(tracks)) {
      state = _copy(failure: null);
      await _engine().seekToIndex(startIndex.clamp(0, tracks.length - 1));
      return;
    }
    // Optimistic index so the UI can act on the queue immediately; the
    // engine's own index stream confirms or corrects it.
    state = PlayerState(
      queue: tracks,
      currentIndex: startIndex.clamp(0, tracks.length - 1),
    );
    try {
      await _engine().loadQueue(tracks, startIndex: startIndex);
    } on Object catch (_) {
      state = _copy(failure: AppError.message(ErrorDomain.playback));
    }
  }

  /// Plays [tracks] shuffled, starting somewhere in the middle of them.
  ///
  /// Shuffle is *set*, not toggled, so the button means the same thing however
  /// the player was left. The start index is randomised because enabling
  /// shuffle alone still begins at the first track, which does not look
  /// shuffled to anyone. Order matters here: [playQueue] rebuilds the state for
  /// its new queue, so the shuffle flag has to be applied after it, not before.
  Future<void> shuffleQueue(List<AudioTrack> tracks) async {
    if (tracks.isEmpty) return;
    await playQueue(tracks, startIndex: Random().nextInt(tracks.length));
    state = _copy(shuffled: true);
    await _engine().setShuffled(true);
  }

  Future<void> togglePlayPause() async {
    if (!state.hasQueue) return;
    final bool playing = state.playing;
    state = _copy(failure: null);
    await (playing ? _engine().pause() : _engine().play());
  }

  Future<void> next() async {
    if (!state.hasQueue || !_engine().hasNext) return;
    state = _copy(failure: null);
    await _engine().skipToNext();
  }

  /// Standard transport semantics: near the start of a track, previous means
  /// restart; otherwise it means the track before.
  Future<void> previous({required Duration position}) async {
    if (!state.hasQueue) return;
    state = _copy(failure: null);
    if (!_engine().hasPrevious || position > const Duration(seconds: 3)) {
      await _engine().seek(Duration.zero);
      return;
    }
    await _engine().skipToPrevious();
  }

  Future<void> seek(Duration position) async {
    if (!state.hasQueue) return;
    await _engine().seek(position);
  }

  Future<void> toggleShuffle() async {
    final bool shuffled = !state.shuffled;
    state = _copy(shuffled: shuffled);
    await _engine().setShuffled(shuffled);
  }

  Future<void> cycleRepeatMode() async {
    final RepeatMode mode = switch (state.repeat) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    state = _copy(repeat: mode);
    await _engine().setRepeat(mode);
  }

  void acknowledgeFailure() {
    if (state.failure != null) state = _copy(failure: null);
  }

  /// Pauses playback and clears the queue. Used when the current song is
  /// deleted or the user explicitly stops.
  Future<void> stopPlayback() async {
    if (state.playing) await _engine().pause();
    state = const PlayerState();
  }

  PlaybackEngine _engine() => ref.read(playbackEngineProvider);

  bool _isLoadedQueue(List<AudioTrack> tracks) {
    if (tracks.length != state.queue.length) return false;
    for (int i = 0; i < tracks.length; i++) {
      if (tracks[i].path != state.queue[i].path) return false;
    }
    return true;
  }

  /// Marker for "leave [PlayerState.failure] untouched" — `null` itself means
  /// an explicit clear.
  static const Object _keepFailure = Object();

  PlayerState _copy({
    List<AudioTrack>? queue,
    int? currentIndex,
    bool? playing,
    Duration? duration,
    bool? shuffled,
    RepeatMode? repeat,
    Object? failure = _keepFailure,
  }) => PlayerState(
    queue: queue ?? state.queue,
    currentIndex: currentIndex ?? state.currentIndex,
    playing: playing ?? state.playing,
    duration: duration ?? state.duration,
    shuffled: shuffled ?? state.shuffled,
    repeat: repeat ?? state.repeat,
    failure: failure == _keepFailure ? state.failure : failure as String?,
  );
}

final NotifierProvider<PlayerController, PlayerState> playerProvider =
    NotifierProvider<PlayerController, PlayerState>(PlayerController.new);
