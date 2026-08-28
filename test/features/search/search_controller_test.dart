import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/data/models/search_results.dart';
import 'package:music_oasis/data/repositories/search_repository.dart';
import 'package:music_oasis/data/repositories/search_repository_provider.dart';
import 'package:music_oasis/features/search/search_controller.dart';

/// Repository double whose answers the test controls per query.
class StubRepository implements SearchRepository {
  int calls = 0;
  final Map<String, Completer<SearchResults>> _gates =
      <String, Completer<SearchResults>>{};
  final Set<String> failures = <String>{};

  void gate(String query) {
    _gates[query] = Completer<SearchResults>();
  }

  void answer(String query, [SearchResults? results]) {
    _gates.remove(query)!.complete(results ?? const SearchResults());
  }

  void fail(String query) => failures.add(query);

  @override
  Future<SearchResults> search(String query) async {
    calls++;
    if (failures.contains(query)) {
      throw StateError('db gone');
    }
    final Completer<SearchResults>? gate = _gates[query];
    if (gate != null) return gate.future;
    return Future<SearchResults>.value(
      query == 'vera'
          ? const SearchResults(
              artists: <NamedResult>[NamedResult(label: 'Vera Mono')],
            )
          : const SearchResults(),
    );
  }
}

void main() {
  late StubRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = StubRepository();
    container = ProviderContainer(
      overrides: <Override>[
        searchRepositoryProvider.overrideWith((Ref ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
  });

  test('queries are debounced and coalesced', () {
    fakeAsync((FakeAsync async) {
      final SearchController controller = container.read(
        searchProvider.notifier,
      );

      controller.onQueryChanged('v');
      controller.onQueryChanged('ver');
      controller.onQueryChanged('ver ');
      controller.onQueryChanged('vera');
      expect(container.read(searchProvider).status, SearchStatus.loading);
      expect(repository.calls, 0);

      async.elapse(debounceDelay + const Duration(milliseconds: 1));

      expect(repository.calls, 1);
      expect(
        container.read(searchProvider).results?.artists.single.label,
        'Vera Mono',
      );
    });
  });

  test('short input resets to idle without querying', () {
    fakeAsync((FakeAsync async) {
      final SearchController controller = container.read(
        searchProvider.notifier,
      );

      controller.onQueryChanged('vera');
      async.elapse(debounceDelay);
      expect(repository.calls, 1);

      controller.onQueryChanged('');
      async.elapse(debounceDelay);

      final SearchState state = container.read(searchProvider);
      expect(state.status, SearchStatus.idle);
      expect(state.results, isNull);
      expect(repository.calls, 1);
    });
  });

  test('a slow earlier run never overwrites a newer result set', () {
    fakeAsync((FakeAsync async) {
      final SearchController controller = container.read(
        searchProvider.notifier,
      );

      repository.gate('slow');
      controller.onQueryChanged('slow');
      async.elapse(debounceDelay + const Duration(milliseconds: 1));
      expect(container.read(searchProvider).status, SearchStatus.loading);

      controller.onQueryChanged('fast');
      async.elapse(debounceDelay + const Duration(milliseconds: 1));
      expect(
        container.read(searchProvider).results?.artists,
        isEmpty,
      ); // fast answered

      // Now the slow answer arrives late…
      repository.answer('slow');
      async.flushMicrotasks();

      // …and must not replace what the user last asked for.
      final SearchState state = container.read(searchProvider);
      expect(state.status, SearchStatus.results);
      expect(state.failure, isNull);
    });
  });

  test('failures land in state as diagnostics, not crashes', () {
    fakeAsync((FakeAsync async) {
      final SearchController controller = container.read(
        searchProvider.notifier,
      );

      repository.fail('boom');
      controller.onQueryChanged('boom');
      async.elapse(debounceDelay + const Duration(milliseconds: 1));
      async.flushMicrotasks();

      expect(container.read(searchProvider).failure, isNotNull);
      expect(container.read(searchProvider).status, SearchStatus.idle);
    });
  });
}
