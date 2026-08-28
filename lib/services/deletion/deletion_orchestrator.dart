import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/song_repository.dart';
import '../../data/repositories/song_repository_provider.dart';
import 'file_deletion_service.dart';

/// Orchestrates the full "delete from device" flow:
///
/// 1. Look up the file path from the database.
/// 2. Ask the platform to delete via MediaStore (system confirmation on
///    Android 11+).
/// 3. Only after the platform confirms physical deletion (SUCCESS), remove
///    the database record. Cascades clean playlist memberships, favorites and
///    playback history.
///
/// The database is never touched before the file is confirmed deleted.
class DeletionOrchestrator {
  const DeletionOrchestrator(this._ref);

  final Ref _ref;

  /// Deletes the audio file for [songId] from the device, then cleans up the
  /// database on success.
  ///
  /// Returns an [Outcome]; callers must not synchronize any UI state on
  /// anything other than [DeletionStatus.success].
  Future<DeletionResult> deleteSongFromDevice(int songId) async {
    // 1. Look up the file path.
    final SongRepository songRepo = await _ref.read(
      songRepositoryProvider.future,
    );
    final String? filePath = await songRepo.pathFor(songId);
    if (filePath == null) {
      debugPrint('DELETE_TRACE: song $songId not in database');
      return const DeletionResult(
        status: DeletionStatus.fileNotFound,
        message: 'Song not found in database.',
      );
    }
    debugPrint('DELETE_TRACE: song=$songId path=$filePath');

    // 2. Platform deletion (MediaStore confirmation on Android 11+).
    final FileDeletionService deletionService = _ref.read(
      fileDeletionServiceProvider,
    );
    final DeletionResult platformResult = await deletionService.deleteFile(
      filePath,
    );
    debugPrint(
      'DELETE_TRACE: platform result=${platformResult.status} '
      'message=${platformResult.message}',
    );

    // 3. Only SUCCESS proves the physical file is gone. CANCELLED,
    //    PERMISSION_DENIED, NOT_FOUND and ERROR leave the database untouched.
    if (!platformResult.isSuccess) return platformResult;

    final bool removed = await songRepo.removeFromDatabase(songId);
    debugPrint('DELETE_TRACE: db remove song=$songId removed=$removed');
    return platformResult;
  }
}

final Provider<FileDeletionService> fileDeletionServiceProvider =
    Provider<FileDeletionService>(
      (Ref ref) => FileDeletionService(),
    );

final Provider<DeletionOrchestrator> deletionOrchestratorProvider =
    Provider<DeletionOrchestrator>(
      (Ref ref) => DeletionOrchestrator(ref),
    );