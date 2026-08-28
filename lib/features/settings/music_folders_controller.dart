import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/music_folder.dart';
import '../../data/repositories/music_folder_repository.dart';
import '../../data/repositories/music_folder_repository_provider.dart';
import '../../services/permissions/storage_access_service.dart';
import '../../services/scanner/folder_picker_service.dart';

/// What came of a folder-add attempt. The UI turns this into one message; the
/// controller never builds user-facing text.
enum AddFolderOutcome {
  added,

  /// The picked folder is already watched, or sits inside a watched folder.
  duplicate,

  /// The user dismissed the picker — nothing changed, nothing to report.
  cancelled,

  /// Picked, but the folder cannot be read.
  denied,

  /// Picked, but the folder no longer exists.
  missing,

  /// The picker or the database failed.
  failed,
}

/// The platform folder picker.
final Provider<FolderPickerService> folderPickerServiceProvider =
    Provider<FolderPickerService>((Ref ref) => const FolderPickerService());

/// Readability probe for a chosen folder.
final Provider<StorageAccessService> storageAccessServiceProvider =
    Provider<StorageAccessService>((Ref ref) => const StorageAccessService());

/// The folders Music Oasis watches, and the two commands that change them.
///
/// Holds no path logic and no platform calls of its own: the picker and the
/// access probe are services, persistence is the repository.
class MusicFoldersController extends AsyncNotifier<List<MusicFolder>> {
  @override
  Future<List<MusicFolder>> build() async {
    final MusicFolderRepository repository = await ref.watch(
      musicFolderRepositoryProvider.future,
    );
    return repository.list();
  }

  /// Picks a folder and persists it.
  ///
  /// The list is only re-read when something actually changed, so a cancelled
  /// pick costs no database work.
  Future<AddFolderOutcome> addFolder() async {
    final String? path = await ref
        .read(folderPickerServiceProvider)
        .pickFolder(dialogTitle: 'Choose a music folder');
    if (path == null) return AddFolderOutcome.cancelled;

    final FolderAccess access = await ref
        .read(storageAccessServiceProvider)
        .check(path);
    switch (access) {
      case FolderAccess.denied:
        return AddFolderOutcome.denied;
      case FolderAccess.missing:
        return AddFolderOutcome.missing;
      case FolderAccess.readable:
        break;
    }

    final MusicFolderRepository repository = await ref.read(
      musicFolderRepositoryProvider.future,
    );
    final AddFolderResult result = await repository.add(path);
    if (result.isDuplicate) return AddFolderOutcome.duplicate;

    await _reload(repository);
    return AddFolderOutcome.added;
  }

  /// Stops watching a folder. The files themselves are never touched
  /// (`REQUIREMENTS.md` §18).
  Future<void> removeFolder(int id) async {
    final MusicFolderRepository repository = await ref.read(
      musicFolderRepositoryProvider.future,
    );
    await repository.remove(id);
    await _reload(repository);
  }

  Future<void> _reload(MusicFolderRepository repository) async {
    state = await AsyncValue.guard<List<MusicFolder>>(repository.list);
  }
}

final AsyncNotifierProvider<MusicFoldersController, List<MusicFolder>>
musicFoldersProvider =
    AsyncNotifierProvider<MusicFoldersController, List<MusicFolder>>(
      MusicFoldersController.new,
    );
