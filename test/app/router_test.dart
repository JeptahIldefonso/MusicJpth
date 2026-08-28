import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/app/app.dart';
import 'package:music_oasis/features/home/home_screen.dart';
import 'package:music_oasis/features/library/library_controller.dart';
import 'package:music_oasis/features/library/library_screen.dart';
import 'package:music_oasis/features/player/player_controller.dart';
import 'package:music_oasis/features/playlists/playlists_screen.dart';
import 'package:music_oasis/features/search/search_screen.dart';

import '../support/fake_playback_engine.dart';

/// Runs [body] with the platform overridden, resetting it inside the test body
/// — `flutter_test` asserts foundation debug variables are unset before
/// `tearDown` runs, so the reset cannot live there.
Future<void> _onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// An empty but loaded library: navigation tests must not open SQLite —
/// widget tests run under fake async, where real database I/O cannot complete.
class _EmptyLibraryController extends LibraryController {
  @override
  LibraryState build() => const LibraryState(status: LibraryStatus.ready);

  @override
  Future<void> loadInitial() async {}

  @override
  Future<void> loadMore() async {}
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        // The shell hosts the mini player, whose controller needs an engine;
        // navigation tests never drive real playback.
        playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
        libraryProvider.overrideWith(_EmptyLibraryController.new),
      ],
      child: const MusicOasisApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _mobileTab(String label) =>
    find.byKey(ValueKey<String>('mobile-nav-$label'));

Finder _sidebarItem(String label) =>
    find.byKey(ValueKey<String>('desktop-nav-$label'));

void main() {
  group('navigation on mobile', () {
    testWidgets('shows the four bottom destinations and no sidebar', (
      tester,
    ) async {
      await _onPlatform(TargetPlatform.android, () async {
        await _pumpApp(tester);

        expect(_mobileTab('HOME'), findsOneWidget);
        expect(_mobileTab('SEARCH'), findsOneWidget);
        expect(_mobileTab('LIBRARY'), findsOneWidget);
        expect(_mobileTab('PLAYLISTS'), findsOneWidget);
        expect(_sidebarItem('HOME'), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
      });
    });

    testWidgets('switches branch when a tab is tapped', (tester) async {
      await _onPlatform(TargetPlatform.android, () async {
        await _pumpApp(tester);

        await tester.tap(_mobileTab('SEARCH'));
        await tester.pumpAndSettle();
        expect(find.byType(SearchScreen), findsOneWidget);

        await tester.tap(_mobileTab('LIBRARY'));
        await tester.pumpAndSettle();
        expect(find.byType(LibraryScreen), findsOneWidget);

        await tester.tap(_mobileTab('PLAYLISTS'));
        await tester.pumpAndSettle();
        expect(find.byType(PlaylistsScreen), findsOneWidget);
      });
    });
  });

  group('navigation on desktop', () {
    testWidgets('shows the sidebar destinations and no bottom tabs', (
      tester,
    ) async {
      await _onPlatform(TargetPlatform.windows, () async {
        await _pumpApp(tester);

        expect(find.text('MUSIC JPTH'), findsAtLeastNWidgets(1));
        expect(_sidebarItem('HOME'), findsOneWidget);
        expect(_sidebarItem('SEARCH'), findsOneWidget);
        expect(_sidebarItem('LIBRARY'), findsOneWidget);
        expect(_sidebarItem('PLAYLISTS'), findsOneWidget);
        expect(_mobileTab('HOME'), findsNothing);
      });
    });

    testWidgets('switches branch from the sidebar', (tester) async {
      await _onPlatform(TargetPlatform.windows, () async {
        await _pumpApp(tester);

        await tester.tap(_sidebarItem('SEARCH'));
        await tester.pumpAndSettle();
        expect(find.byType(SearchScreen), findsOneWidget);

        await tester.tap(_sidebarItem('LIBRARY'));
        await tester.pumpAndSettle();
        expect(find.byType(LibraryScreen), findsOneWidget);

        await tester.tap(_sidebarItem('PLAYLISTS'));
        await tester.pumpAndSettle();
        expect(find.byType(PlaylistsScreen), findsOneWidget);
      });
    });
  });
}
