import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/errors/app_error.dart';
import '../artwork/artwork_cache_service.dart';
import 'interruption_policy.dart';
import 'playback_engine.dart';

/// The one audio handler of the application: just_audio wrapped by
/// audio_service (`REQUIREMENTS.md` §49).
///
/// audio_service is what turns this into platform background playback: on
/// Android it owns the foreground service and the real media session behind
/// the notification and lock screen (§10–§12); on desktop it simply keeps
/// playing while the window lives. Every control path — UI, notification,
/// headset — funnels through the same methods here, so there is exactly one
/// source of truth for what plays.
///
/// Created before `runApp` via `AudioService.init`, then handed to Riverpod
/// through an override; nothing above this class touches just_audio directly.
class MusicAudioHandler extends BaseAudioHandler implements PlaybackEngine {
  MusicAudioHandler(this._player, {this.artwork = const ArtworkCacheService()}) {
    _subscriptions.addAll(<StreamSubscription<dynamic>>[
      // Fires on every playback event; keeps the OS session (notification,
      // lock screen) synchronised with the engine (`REQUIREMENTS.md` §11).
      _player.playbackEventStream.listen((_) => _broadcast()),
      _player.playerStateStream.listen(_onPlayerState),
      _player.currentIndexStream.listen(_onIndexChanged),
      // A corrupt or vanished file reports once and is skipped so one bad
      // file cannot silence a whole queue (`REQUIREMENTS.md` §42).
      _player.errorStream.listen(_onPlayerError),
      // One tick per second while playing, so the notification and lock
      // screen carry a live position rather than the value of the last event.
      positionStream.listen((_) => _broadcast()),
    ]);
  }

  /// Builds the handler and wires the platform audio session: headphone
  /// unplug pauses (§13), and audio-focus interruptions follow platform
  /// behaviour through [InterruptionPolicy]. This is what lets playback run
  /// on as a foreground service while the UI is gone — the session, not the
  /// widget tree, owns the sound (`REQUIREMENTS.md` §09).
  static Future<MusicAudioHandler> create({
    ArtworkCacheService artwork = const ArtworkCacheService(),
  }) async {
    final MusicAudioHandler handler = await AudioService.init(
      builder: () => MusicAudioHandler(AudioPlayer(), artwork: artwork),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.musicoasis.music_oasis.playback',
        androidNotificationChannelName: 'Music Jpth',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    final AudioSession session = await AudioSession.instance;
    handler._subscriptions.addAll(<StreamSubscription<dynamic>>[
      session.becomingNoisyEventStream.listen((_) => handler.pause()),
      session.interruptionEventStream.listen(handler._onInterruption),
    ]);
    return handler;
  }

  final AudioPlayer _player;

  /// Resolves cached covers to absolute URIs for the media session.
  final ArtworkCacheService artwork;
  final Set<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>{};

  /// The loaded queue, kept so failures and index changes can resolve paths.
  List<AudioTrack> _tracks = const <AudioTrack>[];

  /// Guards the async media-item refresh against out-of-order index changes.
  int _mediaGeneration = 0;

  /// Consecutive files that failed without one succeeding; bounded auto-skip.
  int _consecutiveFailures = 0;

  /// Whether the current interruption found us playing — the only state an
  /// interruption end may undo. Cleared by any direct command, so a manual
  /// play/pause always wins over an automatic resume.
  bool _interruptedWhilePlaying = false;

  static const double _normalVolume = 1.0;
  static const double _duckedVolume = 0.25;

  final InterruptionPolicy _interruptionPolicy = const InterruptionPolicy();

  @override
  Stream<bool> get playingStream =>
      _player.playerStateStream.map((PlayerState state) => state.playing);

  @override
  Stream<Duration> get positionStream => _player.createPositionStream(
    steps: 60,
    minPeriod: const Duration(milliseconds: 200),
    maxPeriod: const Duration(seconds: 1),
  );

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  @override
  Stream<PlaybackFailure> get failureStream => _player.errorStream.map(
    (PlayerException error) => const PlaybackFailure(
      // Sanitised: engine codes and platform text stay internal; the UI
      // renders only this copy (`REQUIREMENTS.md` §42).
      message: AppError.playbackMessage,
    ),
  );

  @override
  bool get hasNext => _player.hasNext;

  @override
  bool get hasPrevious => _player.hasPrevious;

  @override
  Future<void> loadQueue(
    List<AudioTrack> tracks, {
    required int startIndex,
  }) async {
    _tracks = List<AudioTrack>.of(tracks);
    _consecutiveFailures = 0;
    _interruptedWhilePlaying = false;
    _mediaGeneration++;
    final List<MediaItem> items =
        await Future.wait(tracks.map(_mediaItemForTrack));
    queue.add(items.toList(growable: false));
    await _player.setAudioSources(
      tracks
          .map((AudioTrack track) {
            return AudioSource.uri(Uri.file(track.path));
          })
          .toList(growable: false),
      initialIndex: startIndex,
    );
    _onIndexChanged(_player.currentIndex);
    await play();
  }

  @override
  Future<void> play() async {
    _interruptedWhilePlaying = false;
    await _player.play();
  }

  @override
  Future<void> pause() async {
    _interruptedWhilePlaying = false;
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> seekToIndex(int index) async {
    await _player.seek(Duration.zero, index: index);
    await play();
  }

  @override
  Future<void> skipToNext() async {
    if (!_player.hasNext) return;
    await _player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    if (!_player.hasPrevious) return;
    await _player.seekToPrevious();
  }

  @override
  Future<void> setShuffled(bool shuffled) =>
      _player.setShuffleModeEnabled(shuffled);

  @override
  Future<void> setRepeat(RepeatMode mode) => _player.setLoopMode(switch (mode) {
    RepeatMode.off => LoopMode.off,
    RepeatMode.all => LoopMode.all,
    RepeatMode.one => LoopMode.one,
  });

  @override
  Future<void> dispose() async {
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
  }

  void _onPlayerState(PlayerState state) {
    // A track reaching ready means the previous failure was survived; the
    // bounded-skip counter counts consecutive failures only.
    if (state.processingState == ProcessingState.ready) {
      _consecutiveFailures = 0;
    }
    _broadcast();
  }

  Future<void> _onIndexChanged(int? index) async {
    if (index == null || index < 0 || index >= _tracks.length) return;
    final int generation = ++_mediaGeneration;
    final MediaItem item = await _mediaItemForTrack(_tracks[index]);
    // A newer track already claimed the session; ignore the stale resolve.
    if (generation != _mediaGeneration) return;
    mediaItem.add(item);
  }

  /// Resolves the cached artwork for [track] into an absolute URI for the
  /// media session, so the notification and lock screen carry the real cover.
  Future<MediaItem> _mediaItemForTrack(AudioTrack track) async {
    final File? cover = await artwork.resolve(track.artworkPath);
    return mediaItemForTrack(
      track,
      artUri: cover == null ? null : Uri.file(cover.path),
    );
  }

  Future<void> _onPlayerError(PlayerException error) async {
    _consecutiveFailures++;
    // Bounded: a queue where every file fails stops after one pass rather
    // than spinning forever.
    if (_consecutiveFailures > _tracks.length) return;
    if (hasNext) await skipToNext();
  }

  /// Applies platform audio-focus events (`REQUIREMENTS.md` §13): duck under
  /// brief claims, pause for real ones, and only undo what this app itself
  /// did — a phone call never auto-resumes.
  Future<void> _onInterruption(AudioInterruptionEvent event) async {
    final InterruptionKind kind = switch (event.type) {
      AudioInterruptionType.duck => InterruptionKind.duck,
      AudioInterruptionType.pause => InterruptionKind.pause,
      AudioInterruptionType.unknown => InterruptionKind.unknown,
    };

    if (event.begin) {
      final InterruptionResponse response = _interruptionPolicy.onStart(
        kind,
        playing: _player.playing,
      );
      switch (response) {
        case InterruptionResponse.duck:
          _interruptedWhilePlaying = true;
          await _player.setVolume(_duckedVolume);
        case InterruptionResponse.pause:
          _interruptedWhilePlaying = true;
          // The engine directly, not [pause]: an interruption is not a user
          // command and must not clear its own resume intent.
          await _player.pause();
          _broadcast();
        case InterruptionResponse.ignore ||
            InterruptionResponse.resume ||
            InterruptionResponse.unduck:
          break;
      }
      return;
    }

    final InterruptionResponse response = _interruptionPolicy.onEnd(
      kind,
      wasInterruptedWhilePlaying: _interruptedWhilePlaying,
    );
    switch (response) {
      case InterruptionResponse.unduck:
        await _player.setVolume(_normalVolume);
      case InterruptionResponse.resume:
        await _player.play();
        _broadcast();
      case InterruptionResponse.ignore ||
          InterruptionResponse.duck ||
          InterruptionResponse.pause:
        break;
    }
    if (response != InterruptionResponse.ignore) {
      _interruptedWhilePlaying = false;
    }
  }

  void _broadcast() {
    final bool playing = _player.playing;
    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{MediaAction.seek},
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.buffering,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
      ),
    );
  }
}
