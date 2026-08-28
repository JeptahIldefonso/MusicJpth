import 'dart:io' show Directory, FileSystemEntity, FileSystemException;

/// Whether Music Oasis can actually read a chosen folder.
enum FolderAccess {
  /// The folder exists and its entries can be listed.
  readable,

  /// The folder exists but the OS refused the listing — on Android this means
  /// the media-read permission is missing, on desktop a locked directory.
  denied,

  /// The folder is gone (unplugged drive, deleted, revoked SAF grant).
  missing,
}

/// Answers one question: can the app read this folder?
///
/// Folder *selection* needs no runtime permission — Android's document picker
/// grants access to what the user picked, and desktop pickers do the same. What
/// can still fail is reading the folder afterwards through `dart:io`, so the
/// permission story is settled by probing rather than by asking, and the user
/// sees a real answer instead of a permission dialog they cannot act on
/// (`REQUIREMENTS.md` §36: request access only when needed).
class StorageAccessService {
  const StorageAccessService();

  /// Lists at most one entry — enough to prove readability, cheap on a folder
  /// holding thousands of files, and never a recursive walk.
  Future<FolderAccess> check(String path) async {
    final Directory directory = Directory(path);
    try {
      if (!await directory.exists()) return FolderAccess.missing;
      await directory
          .list(followLinks: false)
          .take(1)
          .forEach((FileSystemEntity _) {});
      return FolderAccess.readable;
    } on FileSystemException {
      return FolderAccess.denied;
    }
  }
}
