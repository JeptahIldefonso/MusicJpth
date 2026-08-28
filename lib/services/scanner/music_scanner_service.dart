import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/utils/music_paths.dart';
import '../../data/models/discovered_file.dart';
import '../../data/models/music_folder.dart';
import '../../data/repositories/metadata_repository.dart';
import '../../data/repositories/music_folder_repository.dart';
import '../../data/repositories/song_repository.dart';
import '../artwork/artwork_cache_service.dart';
import '../metadata/metadata_service.dart';
import '../permissions/media_permission_service.dart';
import '../permissions/storage_access_service.dart';
import 'file_discovery.dart';

/// Why a scan could not run. None of these is a crash — each maps to something
/// the user can act on.
enum ScanBlockReason {
  /// No folders are being watched yet.
  noFolders,

  /// The OS refused read access this time.
  permissionDenied,

  /// The OS refused for good; only the system settings screen can change it.
  permissionPermanentlyDenied,

  /// Every watched folder is unreadable or gone — an unplugged drive, a revoked
  /// grant. No song's availability changes on this path.
  foldersUnreadable,
}

/// What a running scan reports. Sealed, so the controller must handle each case.
@immutable
sealed class ScanUpdate {
  const ScanUpdate();
}

/// Progress after a batch was written. Emitted per batch, not per file, so a
/// 10,000-file scan rebuilds the UI a few dozen times (`PROJECT.md` §09).
final class ScanProgress extends ScanUpdate {
  const ScanProgress({
    required this.found,
    required this.added,
    required this.updated,
    this.tagged = 0,
  });

  final int found;
  final int added;
  final int updated;

  /// Songs whose tags were read and stored so far.
  final int tagged;
}

/// The scan never started; nothing in the database changed.
final class ScanBlocked extends ScanUpdate {
  const ScanBlocked(this.reason);

  final ScanBlockReason reason;
}

/// The scan finished and the library is in sync with the watched folders.
final class ScanFinished extends ScanUpdate {
  const ScanFinished({
    required this.found,
    required this.added,
    required this.updated,
    required this.missing,
    this.tagged = 0,
  });

  final int found;
  final int added;
  final int updated;

  /// Songs this scan marked unavailable because their file was gone. Nothing is
  /// deleted (`PROJECT.md` §12).
  final int missing;

  /// Songs whose tags were read and stored during this scan.
  final int tagged;
}

/// The scan step of the flow, as a seam the controller depends on and tests can
/// replace.
abstract interface class MusicScanner {
  /// Runs one incremental scan and reports what it did as it goes.
  Stream<ScanUpdate> scan();
}

/// Scans the watched folders and brings the `songs` table in line with them.
///
/// The scan flow of `PROJECT.md` §07, in one place: permission, discovery,
/// compare against existing records, read tags for what changed, batched writes,
/// reconciliation. Discovery and tag parsing each happen in another isolate and
/// every batch is written in its own transaction, so the UI keeps rendering and
/// an interrupted scan still leaves a valid database (`PROJECT.md` §29, §30).
///
/// Artwork is not decoded or extracted here: the tag reader returns cover
/// bytes with the rest of the tags, and [artwork] hashes them into the cache.
/// A separate pass repairs rows whose artwork went missing without the file
/// changing, which the incremental comparison alone cannot notice.
class MusicScannerService implements MusicScanner {
  const MusicScannerService({
    required this.folders,
    required this.songs,
    required this.metadata,
    required this.permissions,
    required this.access,
    this.artwork,
    this.discovery = const FileDiscoveryService(),
    this.reader = const MetadataService(),
    this.chunkSize = DiscoveryRequest.defaultChunkSize,
  });

  final MusicFolderRepository folders;
  final SongRepository songs;
  final MetadataRepository metadata;
  final MediaPermissionGate permissions;
  final StorageAccessService access;

  /// Cover storage; `null` keeps scans artwork-free (tests, or a caller that
  /// has not opted in).
  final ArtworkCacheService? artwork;
  final FileDiscoveryService discovery;
  final MetadataService reader;
  final int chunkSize;

  /// Runs one incremental scan of every watched folder.
  ///
  /// Cancelling the subscription cancels the scan: discovery stops, the isolate
  /// is killed, and the reconciliation pass is skipped — a partial scan must
  /// never conclude that the files it did not reach are gone, so a cancelled
  /// scan leaves every song's availability exactly as it found it.
  ///
  /// Nothing is ever deleted from the library. A song whose file a completed
  /// scan could not find is marked unavailable instead, keeping the playlist
  /// entries, favorites and history that reference it (`PROJECT.md` §12).
  @override
  Stream<ScanUpdate> scan() async* {
    final List<MusicFolder> watched = await folders.list();
    if (watched.isEmpty) {
      yield const ScanBlocked(ScanBlockReason.noFolders);
      return;
    }

    switch (await permissions.ensureAudioAccess()) {
      case MediaAccess.denied:
        yield const ScanBlocked(ScanBlockReason.permissionDenied);
        return;
      case MediaAccess.permanentlyDenied:
        yield const ScanBlocked(ScanBlockReason.permissionPermanentlyDenied);
        return;
      case MediaAccess.granted:
        break;
    }

    // Only folders that can be read take part. A folder that is missing or
    // refused is left out of reconciliation, so an unplugged drive cannot mark
    // a whole library unavailable (`REQUIREMENTS.md` §18: the scanner is
    // read-only, and hiding files that still exist is not acceptable either).
    final List<MusicFolder> readable = <MusicFolder>[];
    for (final MusicFolder folder in watched) {
      if (await access.check(folder.path) == FolderAccess.readable) {
        readable.add(folder);
      }
    }
    if (readable.isEmpty) {
      yield const ScanBlocked(ScanBlockReason.foldersUnreadable);
      return;
    }

    final List<String> roots = readable
        .map((MusicFolder folder) => folder.path)
        .toList(growable: false);

    // Paths only — the comparison key for reconciliation, not the library. A
    // 10,000-song library costs well under a megabyte here.
    final Set<String> seen = <String>{};
    SongSyncCounts totals = SongSyncCounts.none;
    MetadataSyncCounts tags = MetadataSyncCounts.none;
    int found = 0;

    await for (final List<DiscoveredFile> batch in discovery.discover(
      DiscoveryRequest(roots: roots, chunkSize: chunkSize),
    )) {
      // Only what the index actually changed needs its tags read, so a repeat
      // scan of an unchanged library opens no audio file at all
      // (`REQUIREMENTS.md` §31, `PROJECT.md` §07: read metadata only when
      // needed).
      final List<String> changed = <String>[];
      totals += await songs.syncBatch(batch, changedPaths: changed);
      if (changed.isNotEmpty) {
        tags += await metadata.apply(
          await reader.read(changed),
          artwork: artwork,
        );
        // These files were just opened with cover extraction in play, so they
        // do not need the backfill pass below to look again.
        if (artwork != null) await songs.markArtworkChecked(changed);
      }

      for (final DiscoveredFile file in batch) {
        seen.add(MusicPaths.key(file.path));
      }
      found += batch.length;
      yield ScanProgress(
        found: found,
        added: totals.added,
        updated: totals.updated,
        tagged: tags.tagged,
      );
    }

    // ── Artwork backfill ───────────────────────────────────────────────────
    // The loop above reads tags only for files the index saw change, which is
    // right for tags — they cannot change without the file changing — but wrong
    // for artwork, which lives in a cache *outside* the file. A cover lost with
    // the app's support directory, or a row indexed before extraction worked,
    // leaves an unchanged file that nothing would ever open again.
    //
    // So the rows that have never been examined get read here, in batches,
    // through the same reader and the same cache as any other scan — no second
    // extraction path. Each batch is marked examined whether or not a cover
    // turned up, which both bounds the work to once per file for the life of
    // the library and guarantees this loop terminates.
    if (artwork != null) {
      while (true) {
        final List<String> pending = await songs.pathsAwaitingArtwork(
          limit: chunkSize,
        );
        if (pending.isEmpty) break;
        tags += await metadata.apply(
          await reader.read(pending),
          artwork: artwork,
        );
        await songs.markArtworkChecked(pending);
        yield ScanProgress(
          found: found,
          added: totals.added,
          updated: totals.updated,
          tagged: tags.tagged,
        );
      }
    }

    final int missing = await songs.markMissing(roots: roots, seenKeys: seen);

    final DateTime finishedAt = DateTime.now();
    for (final MusicFolder folder in readable) {
      await folders.markScanned(folder.id, finishedAt);
    }

    yield ScanFinished(
      found: found,
      added: totals.added,
      updated: totals.updated,
      missing: missing,
      tagged: tags.tagged,
    );
  }
}
