import 'package:flutter/services.dart';

/// Result of a platform-mediated file deletion attempt.
enum DeletionStatus {
  /// The physical file was deleted by the platform.
  success,

  /// The user dismissed the Android system confirmation dialog.
  userCancelled,

  /// The file was not found in MediaStore / on disk.
  fileNotFound,

  /// The platform refused the operation on permission grounds.
  permissionDenied,

  /// Any other platform-side failure.
  error,
}

/// Typed result from the native deletion flow.
class DeletionResult {
  const DeletionResult({required this.status, this.message});

  final DeletionStatus status;
  final String? message;

  bool get isSuccess => status == DeletionStatus.success;
}

/// Bridges to native Android for real MediaStore-backed file deletion.
///
/// On Android 11+ this triggers the system confirmation dialog via
/// `MediaStore.createDeleteRequest()`. On older versions it performs a direct
/// deletion. Only a [DeletionStatus.success] means the audio file was actually
/// removed from device storage.
class FileDeletionService {
  FileDeletionService({MethodChannel? channel})
      : _channel = channel ?? _defaultChannel;

  static const MethodChannel _defaultChannel = MethodChannel(
    'com.musicoasis.music_oasis/file_deletion',
  );

  final MethodChannel _channel;

  /// Requests deletion of the audio file at [filePath] via the platform.
  ///
  /// The method channel is registered by `MainActivity`; if no native side is
  /// present (wrong activity, engine reuse) this reports [DeletionStatus.error]
  /// instead of throwing.
  Future<DeletionResult> deleteFile(String filePath) async {
    try {
      final Map<dynamic, dynamic>? raw = await _channel
          .invokeMapMethod<dynamic, dynamic>(
        'deleteAudioFile',
        <String, dynamic>{'path': filePath},
      );

      if (raw == null) {
        return const DeletionResult(
          status: DeletionStatus.error,
          message: 'Platform returned null.',
        );
      }

      final String status = raw['status'] as String? ?? 'ERROR';
      final String? message = raw['message'] as String?;

      return switch (status) {
        'SUCCESS' => const DeletionResult(status: DeletionStatus.success),
        'CANCELLED' || 'USER_CANCELLED' => const DeletionResult(
          status: DeletionStatus.userCancelled,
        ),
        'NOT_FOUND' || 'FILE_NOT_FOUND' =>
          DeletionResult(status: DeletionStatus.fileNotFound, message: message),
        'PERMISSION_DENIED' =>
          DeletionResult(status: DeletionStatus.permissionDenied, message: message),
        _ => DeletionResult(status: DeletionStatus.error, message: message),
      };
    } on PlatformException catch (e) {
      return DeletionResult(
        status: DeletionStatus.error,
        message: 'Platform error: ${e.message}',
      );
    } on MissingPluginException {
      // No native handler is registered — the deletion did not happen and no
      // database change may be made.
      return const DeletionResult(
        status: DeletionStatus.error,
        message: 'Native deletion bridge is not available.',
      );
    }
  }
}