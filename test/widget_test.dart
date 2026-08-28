import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/app/app.dart';
import 'package:music_oasis/features/home/home_screen.dart';
import 'package:music_oasis/features/player/player_controller.dart'
    show playbackEngineProvider;

import 'support/fake_playback_engine.dart';

void main() {
  testWidgets('app boots inside a ProviderScope on the home destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
        ],
        child: const MusicOasisApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
