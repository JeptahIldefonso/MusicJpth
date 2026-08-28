import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/metadata_repository_provider.dart';
import '../../data/repositories/music_folder_repository_provider.dart';
import '../../data/repositories/song_repository_provider.dart';
import '../../services/artwork/artwork_cache_service.dart'
    show artworkCacheServiceProvider;
import '../../services/metadata/metadata_service.dart';
import '../../services/permissions/media_permission_service.dart';
import '../../services/scanner/file_discovery.dart';
import '../../services/scanner/music_scanner_service.dart';
import '../../core/errors/app_error.dart';
import '../settings/music_folders_controller.dart'
    show storageAccessServiceProvider;

/// Where a scan is (`PROJECT.md` §24).
enum ScanStatus { idle, scanning, completed, cancelled, error }

/// Everything the scan UI needs, and nothing else.
///
/// Counts only — never the discovered files. The library is read from SQLite,
/// not carried around in provider state (`PROJECT.md` §09).
@immutable
class ScannerState {
  const ScannerState({
    this.status = ScanStatus.idle,
    this.found = 0,
    this.added = 0,
    this.updated = 0,
    this.missing = 0,
    this.tagged = 0,
    this.reason,
    this.failure,
  });

  final ScanStatus status;
  final int found;
  final int added;
  final int updated;

  /// Songs the last scan marked unavailable. Nothing is deleted.
  final int missing;

  /// Songs whose tags were read and stored during this scan.
  final int tagged;

  /// Set when the scan could not run; `null` for a scan that did run.
  final ScanBlockReason? reason;

  /// Set when the scan itself failed. Diagnostic text, not user-facing copy.
  final String? failure;

  bool get isScanning => status == ScanStatus.scanning;

  /// Whether only the system settings screen can unblock this.
  bool get needsSystemSettings =>
      reason == ScanBlockReason.permissionPermanentlyDenied;

  @override
  bool operator ==(Object other) =>
      other is ScannerState &&
      other.status == status &&
      other.found == found &&
      other.added == added &&
      other.updated == updated &&
      other.missing == missing &&
      other.tagged == tagged &&
      other.reason == reason &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(
    status,
    found,
    added,
    updated,
    missing,
    tagged,
    reason,
    failure,
  );
}

/// Android media-permission gate. A no-op on every other platform.
final Provider<MediaPermissionGate> mediaPermissionGateProvider =
    Provider<MediaPermissionGate>((Ref ref) => const MediaPermissionService());

/// Isolate-backed file discovery.
final Provider<FileDiscoveryService> fileDiscoveryServiceProvider =
    Provider<FileDiscoveryService>((Ref ref) => const FileDiscoveryService());

/// Isolate-backed tag reading.
final Provider<MetadataService> metadataServiceProvider =
    Provider<MetadataService>((Ref ref) => const MetadataService());

/// The scanner, available once the database has opened.
final FutureProvider<MusicScanner> musicScannerServiceProvider =
    FutureProvider<MusicScanner>(
      (Ref ref) async => MusicScannerService(
        folders: await ref.watch(musicFolderRepositoryProvider.future),
        songs: await ref.watch(songRepositoryProvider.future),
        metadata: await ref.watch(metadataRepositoryProvider.future),
        permissions: ref.watch(mediaPermissionGateProvider),
        access: ref.watch(storageAccessServiceProvider),
        artwork: ref.watch(artworkCacheServiceProvider),
        discovery: ref.watch(fileDiscoveryServiceProvider),
        reader: ref.watch(metadataServiceProvider),
      ),
    );

/// Drives one scan at a time and publishes its progress.
///
/// Owns no filesystem and no database code: it subscribes to the scanner
/// service and turns updates into state. `build` touches nothing, so opening
/// Settings never opens the database.
class ScannerController extends Notifier<ScannerState> {
  StreamSubscription<ScanUpdate>? _subscription;
  Completer<void>? _completion;

  @override
  ScannerState build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
      _completion = null;
    });
    return const ScannerState();
  }

  /// Runs a scan, completing when it finishes, fails or is cancelled.
  ///
  /// A second call while one is running is ignored rather than queued — two
  /// concurrent scans would fight over the same rows.
  Future<void> scan() async {
    if (state.isScanning) return;

    state = const ScannerState(status: ScanStatus.scanning);
    final Completer<void> completion = Completer<void>();
    _completion = completion;

    try {
      final MusicScanner scanner = await ref.read(
        musicScannerServiceProvider.future,
      );
      _subscription = scanner.scan().listen(
        _apply,
        onError: (Object error, StackTrace stackTrace) {
          _fail(error);
          _release(completion);
        },
        onDone: () => _release(completion),
        cancelOnError: true,
      );
    } on Object catch (error) {
      _fail(error);
      _release(completion);
    }

    await completion.future;
  }

  /// Stops a running scan. Cancelling the subscription stops discovery and kills
  /// its isolate; already-written batches stay written, and no song's
  /// availability changes on this path — a partial scan has not proved that the
  /// files it never reached are gone.
  Future<void> cancel() async {
    final StreamSubscription<ScanUpdate>? subscription = _subscription;
    if (subscription == null) return;

    final Completer<void>? completion = _completion;
    _subscription = null;
    _completion = null;

    await subscription.cancel();

    state = ScannerState(
      status: ScanStatus.cancelled,
      found: state.found,
      added: state.added,
      updated: state.updated,
      tagged: state.tagged,
    );

    if (completion != null && !completion.isCompleted) completion.complete();
  }

  void _apply(ScanUpdate update) {
    switch (update) {
      case ScanProgress(
        :final int found,
        :final int added,
        :final int updated,
        :final int tagged,
      ):
        state = ScannerState(
          status: ScanStatus.scanning,
          found: found,
          added: added,
          updated: updated,
          tagged: tagged,
        );
      case ScanBlocked(:final ScanBlockReason reason):
        state = ScannerState(status: ScanStatus.error, reason: reason);
      case ScanFinished(
        :final int found,
        :final int added,
        :final int updated,
        :final int missing,
        :final int tagged,
      ):
        state = ScannerState(
          status: ScanStatus.completed,
          found: found,
          added: added,
          updated: updated,
          missing: missing,
          tagged: tagged,
        );
    }
  }

  void _fail(Object error) {
    state = ScannerState(
      status: ScanStatus.error,
      found: state.found,
      added: state.added,
      updated: state.updated,
      tagged: state.tagged,
      failure: AppError.message(ErrorDomain.filesystem),
    );
  }

  void _release(Completer<void> completion) {
    _subscription = null;
    _completion = null;
    if (!completion.isCompleted) completion.complete();
  }
}

final NotifierProvider<ScannerController, ScannerState> scannerProvider =
    NotifierProvider<ScannerController, ScannerState>(ScannerController.new);
