import 'package:permission_handler/permission_handler.dart';

import '../../core/platform/app_platform.dart';

/// Whether the OS lets Music Oasis read the user's audio files.
enum MediaAccess {
  granted,

  /// Refused this time; asking again later is reasonable.
  denied,

  /// Refused for good, or blocked by policy. Only the system settings screen
  /// can change it, so the UI must offer that instead of asking again.
  permanentlyDenied,
}

/// The permission step of the scan flow, as a seam the scanner can depend on
/// and tests can replace.
abstract interface class MediaPermissionGate {
  /// Grants, or asks for, read access to the user's audio files.
  Future<MediaAccess> ensureAudioAccess();

  /// Opens the OS settings page for this app. `false` if it could not open.
  Future<bool> openSystemSettings();
}

/// Android runtime media permission; a no-op everywhere else.
///
/// Android is the only supported platform that gates `dart:io` reads of the
/// user's music behind a runtime permission. Windows, macOS and Linux read the
/// folder the user picked, so this service grants immediately there and never
/// touches the plugin — keeping Android permission logic out of the desktop
/// path entirely.
///
/// The API level is deduced instead of queried, so no device-info dependency is
/// needed: `READ_MEDIA_AUDIO` only exists from API 33, and
/// `READ_EXTERNAL_STORAGE` is declared with `maxSdkVersion="32"`, so exactly one
/// of the two is present in the manifest for any given device and the other
/// resolves to denied without showing a dialog.
class MediaPermissionService implements MediaPermissionGate {
  const MediaPermissionService();

  @override
  Future<MediaAccess> ensureAudioAccess() async {
    if (!AppPlatform.isAndroid) return MediaAccess.granted;

    final MediaAccess audio = await _ensure(Permission.audio);
    if (audio == MediaAccess.granted) return audio;

    // Android 12 and below: the media-audio permission does not exist, so the
    // legacy storage-read permission is the one that matters.
    final MediaAccess legacy = await _ensure(Permission.storage);
    if (legacy == MediaAccess.granted) return legacy;

    return audio == MediaAccess.permanentlyDenied ||
            legacy == MediaAccess.permanentlyDenied
        ? MediaAccess.permanentlyDenied
        : MediaAccess.denied;
  }

  @override
  Future<bool> openSystemSettings() => openAppSettings();

  /// Asks only when access is actually missing (`REQUIREMENTS.md` §36).
  ///
  /// "Permanently denied" is read from the request result rather than the
  /// pre-request status: on Android a permission that has simply never been
  /// requested is indistinguishable from one denied for good until the request
  /// comes back.
  static Future<MediaAccess> _ensure(Permission permission) async {
    final PermissionStatus status = await permission.status;
    if (status.isGranted || status.isLimited) return MediaAccess.granted;

    final PermissionStatus result = await permission.request();
    if (result.isGranted || result.isLimited) return MediaAccess.granted;
    if (result.isPermanentlyDenied || result.isRestricted) {
      return MediaAccess.permanentlyDenied;
    }
    return MediaAccess.denied;
  }
}
