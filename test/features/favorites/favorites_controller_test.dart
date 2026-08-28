import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/app/theme.dart';
import 'package:music_oasis/data/models/song.dart';
import 'package:music_oasis/data/repositories/favorites_repository.dart'
    show FavoritesRepository;
import 'package:music_oasis/data/repositories/favorites_repository_provider.dart';
import 'package:music_oasis/features/favorites/favorites_controller.dart';

class FakeRepository implements FavoritesRepository {
  final Set<int> stored = <int>{};
  bool failNext = false;

  @override
  Future<Set<int>> ids() async {
    if (failNext) throw StateError('db gone');
    return Set<int>.of(stored);
  }

  @override
  Future<bool> isFavorite(int songId) async => stored.contains(songId);

  @override
  Future<bool> setFavorite(int songId, {required bool favorite}) async {
    if (failNext) throw StateError('db gone');
    favorite ? stored.add(songId) : stored.remove(songId);
    return favorite;
  }

  @override
  Future<bool> toggle(int songId) async {
    final bool next = !stored.contains(songId);
    return setFavorite(songId, favorite: next);
  }

  @override
  Future<List<Song>> page({int limit = 200, int offset = 0}) async {
    throw UnimplementedError();
  }
}

void main() {
  late FakeRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeRepository();
    container = ProviderContainer(
      overrides: <Override>[
        favoritesRepositoryProvider.overrideWith((Ref ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'toggle flips the cached set optimistically and stays confirmed',
    () async {
      expect(container.read(favoriteIdsProvider).loaded, isFalse);
      await container.read(favoriteIdsProvider.notifier).toggle(7);

      final FavoriteIds state = container.read(favoriteIdsProvider);
      expect(state.contains(7), isTrue);
      expect(state.loaded, isTrue);
      expect(repository.stored, <int>{7});
    },
  );

  test('a failed write reverts the optimistic flip', () async {
    await container.read(favoriteIdsProvider.notifier).toggle(7);
    expect(container.read(favoriteIdsProvider).contains(7), isTrue);

    repository.failNext = true;
    await container.read(favoriteIdsProvider.notifier).toggle(7);
    // The write failed; the cache must not claim success.
    expect(container.read(favoriteIdsProvider).contains(7), isTrue);
    expect(repository.stored, <int>{7});
  });

  testWidgets('the favourite button reflects and toggles only its own song', (
    tester,
  ) async {
    repository.stored
      ..clear()
      ..add(1);
    late ProviderContainer captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          favoritesRepositoryProvider.overrideWith(
            (Ref ref) async => repository,
          ),
        ],
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, _) {
            captured = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: MusicOasisTheme.dark,
              home: Scaffold(
                body: Row(
                  children: <Widget>[
                    _HarnessButton(songId: 1),
                    _HarnessButton(songId: 2),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    bool fav(int id) => captured.read(
      favoriteIdsProvider.select((FavoriteIds s) => s.contains(id)),
    );

    // Initial load lands.
    await tester.pumpAndSettle();
    expect(fav(1), isTrue);
    expect(fav(2), isFalse);

    await tester.tap(find.byTooltip('Unfavorite'));
    await tester.pumpAndSettle();
    expect(fav(1), isFalse);
    expect(repository.stored, isEmpty);
  });
}

class _HarnessButton extends ConsumerWidget {
  const _HarnessButton({required this.songId});

  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool favorite = ref.watch(
      favoriteIdsProvider.select((FavoriteIds ids) => ids.contains(songId)),
    );
    return IconButton(
      tooltip: favorite ? 'Unfavorite' : 'Favorite',
      onPressed: () => ref.read(favoriteIdsProvider.notifier).toggle(songId),
      icon: Icon(favorite ? Icons.favorite : Icons.favorite_outline),
    );
  }
}
