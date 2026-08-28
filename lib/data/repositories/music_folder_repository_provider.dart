import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import 'music_folder_repository.dart';

/// The repository, available once the database has opened.
///
/// Derived from [databaseProvider] so nothing waits for the file synchronously
/// and the connection is still opened exactly once.
final FutureProvider<MusicFolderRepository> musicFolderRepositoryProvider =
    FutureProvider<MusicFolderRepository>(
      (Ref ref) async =>
          MusicFolderRepository(await ref.watch(databaseProvider.future)),
    );
