import 'package:path/path.dart' as p;

/// Path handling for every path Music Oasis stores or compares.
///
/// One place, because a file seen as two paths becomes two songs
/// (`REQUIREMENTS.md` §14: avoid duplicates).
abstract final class MusicPaths {
  const MusicPaths._();

  /// Stored form: trimmed, platform separators, no trailing separator, no
  /// `.`/`..` segments. What goes into `music_folders.path` and `songs.path`.
  static String normalise(String path) => p.normalize(path.trim());

  /// Comparison form: [normalise] plus absolute, plus the platform's case
  /// rules — `C:\Music` and `c:\music` are one folder on Windows and two on
  /// Linux. Never stored; used as a map/set key only.
  static String key(String path) => p.canonicalize(path.trim());

  /// Whether [path] is [root] itself or sits inside it.
  static bool isUnder(String root, String path) =>
      p.equals(root, path) || p.isWithin(root, path);

  /// File name without its extension — the placeholder song title until tags
  /// are read.
  static String basenameWithoutExtension(String path) =>
      p.basenameWithoutExtension(path);

  /// The title to store when a file carries no usable title tag.
  ///
  /// `songs.title` is `NOT NULL` and the UI always has to show something, so
  /// this never returns empty: the filename, or the whole path if even that is
  /// blank (`REQUIREMENTS.md` §16: missing metadata must not break anything).
  static String fallbackTitle(String path) {
    final String name = basenameWithoutExtension(path).trim();
    return name.isEmpty ? path : name;
  }
}
