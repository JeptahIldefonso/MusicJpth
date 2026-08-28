import 'package:audio_service/audio_service.dart' show MediaItem;

/// One playable entry handed to the audio engine.
///
/// Deliberately not a `Song`: services sit below data models, and playback
/// needs only what the engine and media notification show (`PROJECT.md` §05).
/// `path` points at the file on disk — nothing is copied or cached here.
class AudioTrack {
  const AudioTrack({
    required this.path,
    required this.title,
    this.songId,
    this.artist,
    this.album,
    this.durationMs,
    this.artworkPath,
  });

  /// Absolute filesystem path; also the track's stable identity.
  final String path;
  final String title;

  /// The library row this track was built from, when known — lets UI
  /// features (favourites) relate a playing track back to its song without
  /// any lookup.
  final int? songId;
  final String? artist;
  final String? album;
  final int? durationMs;

  /// Relative artwork-cache path for the track's cover, when extracted.
  final String? artworkPath;

  @override
  bool operator ==(Object other) => other is AudioTrack && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// Repeat behaviour, engine-agnostic so features never import just_audio.
enum RepeatMode { off, all, one }

/// A playback failure, already reduced to what the UI can present
/// (`REQUIREMENTS.md` §42: one bad file must never take the player down).
class PlaybackFailure {
  const PlaybackFailure({required this.message, this.trackPath});

  final String message;

  /// The file that failed, when known; `null` for engine-level errors.
  final String? trackPath;
}

/// The seam between the player feature and the audio stack.
///
/// [MusicAudioHandler] implements it with just_audio + audio_service; tests
/// substitute an in-memory fake, so no platform channel is involved anywhere
/// above this interface (`REQUIREMENTS.md` §08: playback independent of UI).
abstract class PlaybackEngine {
  /// Emits whether sound is currently being produced.
  Stream<bool> get playingStream;

  /// Ticks while playing; drives position UI and nothing else.
  Stream<Duration> get positionStream;

  /// Duration of the loaded track, `null` until known.
  Stream<Duration?> get durationStream;

  /// Index into the loaded queue, `null` when nothing is loaded.
  Stream<int?> get currentIndexStream;

  /// Failures that stopped or degraded playback.
  Stream<PlaybackFailure> get failureStream;

  /// Whether another track follows in play order (shuffle-aware).
  bool get hasNext;

  /// Whether a track precedes in play order (shuffle-aware).
  bool get hasPrevious;

  /// Replaces the queue with [tracks] and starts at [startIndex].
  ///
  /// Loading is engine work, off the UI isolate's hot path — decoding happens
  /// in the platform player either way.
  Future<void> loadQueue(List<AudioTrack> tracks, {required int startIndex});

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  /// Jumps to [index] within the current queue without reloading it.
  Future<void> seekToIndex(int index);

  Future<void> skipToNext();

  Future<void> skipToPrevious();

  Future<void> setShuffled(bool shuffled);

  Future<void> setRepeat(RepeatMode mode);

  /// Releases platform resources; the engine must not be used afterwards.
  Future<void> dispose();
}

/// Builds the notification metadata for one track (`REQUIREMENTS.md` §10).
///
/// Kept next to the engine because only the engine knows what a platform media
/// session needs; artwork arrives as an absolute [artUri] resolved from the
/// artwork cache.
MediaItem mediaItemForTrack(AudioTrack track, {Uri? artUri}) => MediaItem(
  id: track.path,
  title: track.title,
  artist: track.artist ?? 'Unknown Artist',
  album: track.album,
  duration: track.durationMs == null
      ? null
      : Duration(milliseconds: track.durationMs!),
  artUri: artUri,
);
