import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import 'playlist_repository.dart';

/// The playlist repository, available once the database has opened.
///
/// Derived from [databaseProvider] — no second connection is ever opened.
final FutureProvider<PlaylistRepository> playlistRepositoryProvider =
    FutureProvider<PlaylistRepository>(
      (Ref ref) async =>
          PlaylistRepository(await ref.watch(databaseProvider.future)),
    );
