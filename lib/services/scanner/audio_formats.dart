import 'package:path/path.dart' as p;

/// The audio containers the scanner indexes (`REQUIREMENTS.md` §15,
/// `PROJECT.md` §07).
///
/// Indexing a format is not a promise to play it: playback support is decided
/// per platform by the audio engine in a later step.
abstract final class AudioFormats {
  const AudioFormats._();

  /// Lower-case, without the leading dot.
  static const Set<String> supported = <String>{
    'mp3',
    'flac',
    'wav',
    'm4a',
    'aac',
    'ogg',
    'opus',
  };

  /// The file's extension in [supported] form, or `null` when it has none.
  ///
  /// A dot-prefixed name (`.hidden`) has no extension, so it is never audio.
  static String? extensionOf(String path) {
    final String extension = p.extension(path);
    if (extension.length < 2) return null;
    return extension.substring(1).toLowerCase();
  }

  /// Whether the scanner should index this file. Extension only — no file is
  /// opened during discovery (`PROJECT.md` §07: read metadata only when needed).
  static bool isSupported(String path) {
    final String? extension = extensionOf(path);
    return extension != null && supported.contains(extension);
  }
}
