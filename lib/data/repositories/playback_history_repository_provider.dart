import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import 'playback_history_repository.dart';

/// The playback-history repository, available once the database has opened.
///
/// Derived from [databaseProvider] — no second connection is ever opened.
final FutureProvider<PlaybackHistoryRepository>
playbackHistoryRepositoryProvider = FutureProvider<PlaybackHistoryRepository>(
  (Ref ref) async =>
      PlaybackHistoryRepository(await ref.watch(databaseProvider.future)),
);
