import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import 'search_repository.dart';

/// The search repository, available once the database has opened.
///
/// Derived from [databaseProvider] — no second connection is ever opened.
final FutureProvider<SearchRepository> searchRepositoryProvider =
    FutureProvider<SearchRepository>(
      (Ref ref) async =>
          SearchRepository(await ref.watch(databaseProvider.future)),
    );
