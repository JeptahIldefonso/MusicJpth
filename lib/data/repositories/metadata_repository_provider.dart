import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import 'metadata_repository.dart';

/// The metadata repository, available once the database has opened.
///
/// Derived from [databaseProvider] so the connection is still opened exactly
/// once and nothing waits for it synchronously.
final FutureProvider<MetadataRepository> metadataRepositoryProvider =
    FutureProvider<MetadataRepository>(
      (Ref ref) async =>
          MetadataRepository(await ref.watch(databaseProvider.future)),
    );
