import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import 'favorites_repository.dart';

/// The favourites repository, available once the database has opened.
///
/// Derived from [databaseProvider] — no second connection is ever opened.
final FutureProvider<FavoritesRepository> favoritesRepositoryProvider =
    FutureProvider<FavoritesRepository>(
      (Ref ref) async =>
          FavoritesRepository(await ref.watch(databaseProvider.future)),
    );
