import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import '../models/song.dart';
import 'song_repository.dart';

/// The song repository, available once the database has opened.
///
/// Derived from [databaseProvider] so the connection is still opened exactly
/// once and nothing waits for it synchronously.
final FutureProvider<SongRepository> songRepositoryProvider =
    FutureProvider<SongRepository>(
      (Ref ref) async =>
          SongRepository(await ref.watch(databaseProvider.future)),
    );

/// Every available song in the library, for pickers that need to filter the
/// whole library locally (for example add-to-playlist).
///
/// Kept distinct from paginated browsing: the repository is still the only
/// data source, and widgets never touch the database directly.
final FutureProvider<List<Song>> availableSongsProvider =
    FutureProvider<List<Song>>(
      (Ref ref) async =>
          (await ref.watch(songRepositoryProvider.future)).all(),
    );