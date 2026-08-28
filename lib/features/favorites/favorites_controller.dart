import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/favorites_repository_provider.dart';

/// The set of favourited song ids, held in memory after one load.
///
/// Rows consult this set directly — a toggle rewrites one entry and rebuilds
/// only the widgets listening to that song's membership, never the library
/// list (`REQUIREMENTS.md` §41). SQLite stays the source of truth; this is a
/// cache, refreshed on load and kept consistent by [toggle].
@immutable
class FavoriteIds {
  const FavoriteIds({this.values = const <int>{}, this.loaded = false});

  final Set<int> values;

  /// Whether the initial load ran; rows render neutral until then.
  final bool loaded;

  bool contains(int? songId) => songId != null && values.contains(songId);

  @override
  bool operator ==(Object other) =>
      other is FavoriteIds &&
      other.loaded == loaded &&
      setEquals(other.values, values);

  @override
  int get hashCode => Object.hash(loaded, Object.hashAllUnordered(values));
}

class FavoritesController extends Notifier<FavoriteIds> {
  @override
  FavoriteIds build() {
    // One load per app session; toggles keep the cache in step afterwards.
    scheduleLoad();
    return const FavoriteIds();
  }

  void scheduleLoad() {
    Future<void>.microtask(() async {
      try {
        final repository = await ref.read(favoritesRepositoryProvider.future);
        // Reading a disposed container throws; the catch leaves the cache
        // empty and the next toggle retries.
        state = FavoriteIds(values: await repository.ids(), loaded: true);
      } on Object {
        // Leave the cache empty; a retry happens on the next toggle.
      }
    });
  }

  /// Optimistic flip, then the database confirms. A failed write reverts.
  Future<void> toggle(int songId) async {
    final bool wasFavorite = state.contains(songId);
    _apply(songId, favorite: !wasFavorite);
    try {
      final repository = await ref.read(favoritesRepositoryProvider.future);
      final bool confirmed = await repository.setFavorite(
        songId,
        favorite: !wasFavorite,
      );
      if (confirmed != state.contains(songId)) {
        _apply(songId, favorite: confirmed);
      }
    } on Object {
      _apply(songId, favorite: wasFavorite);
    }
  }

  void _apply(int songId, {required bool favorite}) {
    final Set<int> values = <int>{...state.values};
    favorite ? values.add(songId) : values.remove(songId);
    state = FavoriteIds(values: values, loaded: true);
  }
}

final NotifierProvider<FavoritesController, FavoriteIds> favoriteIdsProvider =
    NotifierProvider<FavoritesController, FavoriteIds>(FavoritesController.new);
