import 'dart:async';

import 'package:music_oasis/services/audio/playback_engine.dart';

/// In-memory [PlaybackEngine] for tests above the seam: records commands,
/// exposes controllable streams. No platform channels involved.
class FakePlaybackEngine implements PlaybackEngine {
  int loadCalls = 0;
  int seekIndexCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int seekCalls = 0;
  int nextCalls = 0;
  int previousCalls = 0;
  List<AudioTrack>? loadedTracks;
  int? loadedStart;

  bool nextAvailable = true;
  bool previousAvailable = true;

  final StreamController<bool> playingController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<int?> indexController =
      StreamController<int?>.broadcast();
  final StreamController<PlaybackFailure> failureController =
      StreamController<PlaybackFailure>.broadcast();

  @override
  Stream<bool> get playingStream => playingController.stream;

  @override
  Stream<Duration> get positionStream => positionController.stream;

  @override
  Stream<Duration?> get durationStream => durationController.stream;

  @override
  Stream<int?> get currentIndexStream => indexController.stream;

  @override
  Stream<PlaybackFailure> get failureStream => failureController.stream;

  @override
  bool get hasNext => nextAvailable;

  @override
  bool get hasPrevious => previousAvailable;

  @override
  Future<void> loadQueue(
    List<AudioTrack> tracks, {
    required int startIndex,
  }) async {
    loadCalls++;
    loadedTracks = tracks;
    loadedStart = startIndex;
  }

  @override
  Future<void> play() async => playCalls++;

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> seek(Duration position) async => seekCalls++;

  @override
  Future<void> seekToIndex(int index) async => seekIndexCalls++;

  @override
  Future<void> skipToNext() async => nextCalls++;

  @override
  Future<void> skipToPrevious() async => previousCalls++;

  @override
  Future<void> setShuffled(bool shuffled) async {}

  @override
  Future<void> setRepeat(RepeatMode mode) async {}

  @override
  Future<void> dispose() async {}
}

AudioTrack trackOf(String path) => AudioTrack(path: path, title: path);
