import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/app/app.dart';
import 'package:music_oasis/data/models/search_results.dart';
import 'package:music_oasis/data/models/song.dart';
import 'package:music_oasis/data/repositories/search_repository.dart';
import 'package:music_oasis/data/repositories/search_repository_provider.dart';
import 'package:music_oasis/features/player/player_controller.dart';

import '../../support/fake_playback_engine.dart';

class FixedRepository implements SearchRepository {
  int calls = 0;

  @override
  Future<SearchResults> search(String query) async {
    calls++;
    if (query == 'zzzz') return const SearchResults();
    return SearchResults(
      songs: <Song>[
        const Song(
          id: 1,
          path: '/music/northern.mp3',
          title: 'Northern Line',
          artistName: 'Vera Mono',
          isAvailable: true,
        ),
      ],
      artists: const <NamedResult>[NamedResult(label: 'North Garden')],
    );
  }
}

Future<(ProviderContainer, FixedRepository)> _pump(WidgetTester tester) async {
  final FixedRepository repository = FixedRepository();
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
      searchRepositoryProvider.overrideWith((Ref ref) async => repository),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MediaQuery(data: MediaQueryData(), child: MusicOasisApp()),
    ),
  );
  await tester.pumpAndSettle();

  // Mobile default platform in tests: use the bottom tab to reach Search.
  await tester.tap(find.byKey(const ValueKey<String>('mobile-nav-SEARCH')));
  await tester.pumpAndSettle();
  return (container, repository);
}

void main() {
  testWidgets('debounces input: nothing queries until input settles', (
    tester,
  ) async {
    final (_, FixedRepository repository) = await _pump(tester);

    await tester.enterText(find.byType(TextField), 'nor');
    await tester.pump(); // no settle: debounce timer pending

    expect(repository.calls, 0);

    await tester.pumpAndSettle();
    expect(repository.calls, 1);
  });

  testWidgets('renders grouped results for the settled query', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'nor');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('SONGS'), findsNWidgets(2));
    expect(find.text('Northern Line'), findsOneWidget);
    expect(find.text('ARTISTS'), findsNWidgets(2));
    expect(find.text('North Garden'), findsOneWidget);
  });

  testWidgets('tapping a song result starts playback through the controller', (
    tester,
  ) async {
    final (ProviderContainer container, _) = await _pump(tester);

    await tester.enterText(find.byType(TextField), 'nor');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Northern Line'));
    await tester.pumpAndSettle();

    final PlayerState player = container.read(playerProvider);
    expect(player.hasQueue, isTrue);
    expect(player.currentTrack?.title, 'Northern Line');
  });

  testWidgets('an empty result set shows honest microcopy', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.textContaining('No results found'), findsOneWidget);
  });
}
