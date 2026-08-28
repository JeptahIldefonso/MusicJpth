import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/search_results.dart';
import '../../data/repositories/search_repository.dart' show SearchRepository;
import '../../core/errors/app_error.dart';
import '../../data/repositories/search_repository_provider.dart';

/// Silence below this length is not a search — it is a hand resting on the
/// keyboard. Keeps single-character noise off SQLite.
const Duration debounceDelay = Duration(milliseconds: 250);
const int minQueryLength = 2;

enum SearchStatus { idle, loading, results }

/// Everything the Search screen shows.
@immutable
class SearchState {
  const SearchState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.results,
    this.failure,
  });

  final SearchStatus status;

  /// The query these results answer — the screen can ignore stale answers.
  final String query;
  final SearchResults? results;

  /// Diagnostic text, not user-facing copy.
  final String? failure;

  @override
  bool operator ==(Object other) =>
      other is SearchState &&
      other.status == status &&
      other.query == query &&
      other.results == results &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(status, query, results, failure);
}

/// Debounces user input and asks SQLite, never the filesystem
/// (`REQUIREMENTS.md` §22).
///
/// `build` touches nothing: opening the Search tab performs no database work.
/// Each keystroke resets one timer; only settled input becomes a query, and
/// each result set records the query it belongs to so a slow earlier search
/// can never overwrite a newer one's state.
class SearchController extends Notifier<SearchState> {
  Timer? _debounce;
  int _runId = 0;
  bool _disposed = false;

  @override
  SearchState build() {
    ref.onDispose(() {
      _disposed = true;
      _debounce?.cancel();
      _debounce = null;
    });
    return const SearchState();
  }

  /// Called on every keystroke; restarts the debounce window.
  void onQueryChanged(String raw) {
    final String query = raw.trim();
    _debounce?.cancel();

    if (query.length < minQueryLength) {
      state = const SearchState();
      return;
    }
    if (query == state.query && state.status == SearchStatus.results) {
      return;
    }

    state = SearchState(status: SearchStatus.loading, query: query);
    _debounce = Timer(debounceDelay, () => _search(query));
  }

  Future<void> _search(String query) async {
    final int runId = ++_runId;
    try {
      final SearchRepository repository = await ref.read(
        searchRepositoryProvider.future,
      );
      final SearchResults results = await repository.search(query);
      // A newer keystroke may have started a newer run while this one flew.
      if (_disposed || runId != _runId) return;
      state = SearchState(
        status: SearchStatus.results,
        query: query,
        results: results,
      );
    } on Object catch (_) {
      if (_disposed || runId != _runId) return;
      state = SearchState(
        status: SearchStatus.idle,
        query: query,
        failure: AppError.message(ErrorDomain.database),
      );
    }
  }
}

final NotifierProvider<SearchController, SearchState> searchProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);
