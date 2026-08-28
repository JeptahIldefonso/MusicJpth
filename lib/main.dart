import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/player/player_controller.dart';
import 'services/audio/music_audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // audio_service must be initialised before runApp so the platform side of
  // background playback and the media session exists from the first frame
  // (`REQUIREMENTS.md` §09/§10). The handler is created exactly once here and
  // injected through [playbackEngineProvider]; nothing else builds engines.
  final MusicAudioHandler engine = await MusicAudioHandler.create();
  runApp(
    ProviderScope(
      overrides: <Override>[playbackEngineProvider.overrideWithValue(engine)],
      child: const MusicOasisApp(),
    ),
  );
}
