import 'dart:io' show File, Directory;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Content-addressed store for extracted cover images.
///
/// One file per unique image, named by an FNV-1a 64-bit content hash: a
/// thousand tracks sharing one album cover cost one file and one write
/// (`REQUIREMENTS.md` §23). The pipeline never decodes image data — hashing
/// and copying bytes only; decoding happens once per rendered thumbnail in
/// the UI, bounded by `cacheWidth`.
///
/// Stored paths are relative (`artwork/<hash>.<ext>`), so the database never
/// bakes in an absolute location that breaks when the app moves.
class ArtworkCacheService {
  const ArtworkCacheService({this.baseDirOverride});

  /// Tests point this at a temp directory; production resolves the app
  /// support directory.
  final Directory? baseDirOverride;

  /// Memoised *successful* resolutions, keyed by absolute path. Cover files
  /// are content-addressed and never rewritten in place, so a hit stays valid
  /// for the life of the process.
  ///
  /// Misses are deliberately not memoised: a song with no artwork yet becomes
  /// one with artwork after a backfill, and that must show up without a
  /// restart.
  static final Map<String, File> _resolved = <String, File>{};

  /// The production support directory, kept once resolved so [peek] can answer
  /// synchronously. Only ever set from the non-overridden path, so a test's
  /// temp directory never leaks into production lookups.
  static Directory? _supportDir;

  /// Stores [bytes] if not already cached. Returns the relative path to
  /// store on a song row, or `null` when there was nothing to store or the
  /// bytes are not a recognised image format.
  Future<String?> save(Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    final String ext = _extension(bytes);
    if (ext.isEmpty) return null;

    final String name = '${_fnv1a64(bytes)}.$ext';
    final Directory dir = await _directory();
    final File file = File(p.join(dir.path, name));
    // Same content already cached: the write is skipped, not repeated.
    if (!await file.exists()) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return 'artwork/$name';
  }

  /// The absolute file for a stored relative path, or `null` when there is
  /// nothing stored or the file has since vanished.
  ///
  /// A successful lookup is memoised, so the repeated calls a scrolling list
  /// makes cost one `exists()` per cover rather than one per rebuild.
  Future<File?> resolve(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;
    final Directory base = await _baseDirectory();
    final String absolute = p.join(base.path, relativePath);
    final File? hit = _resolved[absolute];
    if (hit != null) return hit;
    final File file = File(absolute);
    if (!await file.exists()) return null;
    _resolved[absolute] = file;
    return file;
  }

  /// The already-memoised file for [relativePath], or `null` when it has not
  /// been resolved yet.
  ///
  /// This is what stops artwork flashing: [resolve] returns a *new* future on
  /// every build, so a rebuilt `FutureBuilder` repaints its placeholder before
  /// the identical answer arrives. A synchronous hit lets the real cover paint
  /// on the first frame instead. Static so it stays off the instance surface
  /// that fakes implement.
  static File? peek(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    final Directory? base = _supportDir;
    if (base == null) return null;
    return _resolved[p.join(base.path, relativePath)];
  }

  /// Drops memoised state between tests.
  @visibleForTesting
  static void resetMemo() {
    _resolved.clear();
    _supportDir = null;
  }

  Future<Directory> _baseDirectory() async {
    final Directory? override = baseDirOverride;
    if (override != null) return override;
    return _supportDir ??= await getApplicationSupportDirectory();
  }

  Future<Directory> _directory() async {
    final Directory base = await _baseDirectory();
    final Directory dir = Directory(p.join(base.path, 'artwork'));
    await dir.create(recursive: true);
    return dir;
  }

  /// Sniffs the container: JPEG starts FF D8, PNG starts the 8-byte
  /// signature, WebP is `RIFF....WEBP`. Anything else is refused rather than
  /// stored unidentifiable.
  static String _extension(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'jpg';
    }
    if (_startsWith(bytes, const <int>[0x89, 0x50, 0x4E, 0x47])) return 'png';
    // RIFF container with a WEBP form type at offset 8; the four size bytes in
    // between are content, not signature.
    if (_startsWith(bytes, const <int>[0x52, 0x49, 0x46, 0x46]) &&
        bytes.length >= 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return '';
  }

  static bool _startsWith(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (int i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  /// FNV-1a 64-bit, hex-encoded. Not cryptographic — collisions only risk a
  /// shared thumbnail, and the input is already trusted media metadata — but
  /// deterministic across platforms and runs without any dependency.
  @visibleForTesting
  static String fnv1a64Hex(Uint8List bytes) => _fnv1a64(bytes);

  static String _fnv1a64(Uint8List bytes) {
    int hash = 0xcbf29ce484222325;
    for (final int byte in bytes) {
      hash ^= byte;
      // Dart ints are 64-bit wrapping; mask keeps the multiply in range.
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}

/// The one artwork cache for the application.
final Provider<ArtworkCacheService> artworkCacheServiceProvider =
    Provider<ArtworkCacheService>((Ref ref) => const ArtworkCacheService());
