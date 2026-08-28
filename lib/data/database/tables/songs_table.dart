import 'albums_table.dart';
import 'artists_table.dart';

/// `songs` — indexed metadata for, and a reference to, each audio file.
///
/// Columns follow `CLAUDE.md` §09. The audio itself stays on the filesystem;
/// only [path] points at it. Durations and timestamps are integers
/// (milliseconds, and epoch milliseconds) so ordering is index-friendly.
abstract final class SongsTable {
  const SongsTable._();

  static const String name = 'songs';

  static const String id = 'id';
  static const String path = 'path';
  static const String title = 'title';
  static const String artistId = 'artist_id';
  static const String albumId = 'album_id';
  static const String duration = 'duration';
  static const String trackNumber = 'track_number';
  static const String discNumber = 'disc_number';
  static const String genre = 'genre';
  static const String year = 'year';
  static const String format = 'format';
  static const String fileSize = 'file_size';
  static const String modifiedTime = 'modified_time';
  static const String artworkPath = 'artwork_path';
  static const String dateAdded = 'date_added';
  static const String lastPlayed = 'last_played';

  /// Whether the file was still on disk at the end of the last scan that
  /// covered it. `1` available, `0` unavailable.
  static const String isAvailable = 'is_available';

  /// [path] is the stable identity of a song; [fileSize] and [modifiedTime]
  /// let an incremental scan decide whether re-reading metadata is needed.
  static const String createTable =
      '''
CREATE TABLE $name (
  $id INTEGER PRIMARY KEY AUTOINCREMENT,
  $path TEXT NOT NULL,
  $title TEXT NOT NULL,
  $artistId INTEGER REFERENCES ${ArtistsTable.name}(${ArtistsTable.id}) ON DELETE SET NULL,
  $albumId INTEGER REFERENCES ${AlbumsTable.name}(${AlbumsTable.id}) ON DELETE SET NULL,
  $duration INTEGER,
  $trackNumber INTEGER,
  $discNumber INTEGER,
  $genre TEXT,
  $year INTEGER,
  $format TEXT,
  $fileSize INTEGER,
  $modifiedTime INTEGER,
  $artworkPath TEXT,
  $dateAdded INTEGER NOT NULL,
  $lastPlayed INTEGER
)''';

  /// Covers the queries in `REQUIREMENTS.md` §06: path lookup during scanning,
  /// title/artist/album browsing and search, recently added, recently played.
  static const List<String> createIndexes = <String>[
    'CREATE UNIQUE INDEX idx_${name}_$path ON $name($path)',
    'CREATE INDEX idx_${name}_$title ON $name($title)',
    'CREATE INDEX idx_${name}_$artistId ON $name($artistId)',
    'CREATE INDEX idx_${name}_$albumId ON $name($albumId)',
    'CREATE INDEX idx_${name}_$dateAdded ON $name($dateAdded)',
    'CREATE INDEX idx_${name}_$lastPlayed ON $name($lastPlayed)',
  ];

  /// Schema version 2: [isAvailable].
  ///
  /// A separate statement rather than a new column in [createTable], because a
  /// published migration must never be edited — a fresh install runs version 1
  /// then this, and lands on the same schema an existing install upgrades to.
  ///
  /// `DEFAULT 1` is what makes the upgrade safe: every row that predates the
  /// column is a song whose file was there the last time a scan looked, so it
  /// starts available and the next scan decides otherwise if it must.
  static const String addIsAvailable =
      'ALTER TABLE $name ADD COLUMN $isAvailable INTEGER NOT NULL DEFAULT 1';

  /// Schema version 3, large-library optimisation (`REQUIREMENTS.md` §21): an
  /// index matching the Library browse order exactly. Without it every paged
  /// read sorted the whole table; with it each page is an index range scan and
  /// keyset seeks are exact. Plain CREATE INDEX IF NOT EXISTS — no row
  /// rewrite, safe to run on any size of library.
  static const String createLibraryOrderIndex =
      'CREATE INDEX IF NOT EXISTS idx_${name}_library_order '
      'ON $name($isAvailable DESC, $title COLLATE NOCASE ASC, $id ASC)';

  /// Whether this file's tags have already been examined for embedded cover
  /// art. `1` examined, `0` not yet looked at.
  ///
  /// Distinct from [artworkPath] being null, which only says no cover was
  /// found — this says whether anyone ever looked.
  static const String artworkChecked = 'artwork_checked';

  /// Schema version 4: [artworkChecked].
  ///
  /// `DEFAULT 0` is the repair. An incremental scan deliberately skips reading
  /// tags for a file whose size and mtime are unchanged (`REQUIREMENTS.md`
  /// §31), and cover extraction rides along with that tag pass — so a row
  /// indexed before extraction worked, or one whose cached cover file was lost
  /// with the app's support directory, had no route back to having artwork.
  /// Every pre-existing row starts unexamined, gets looked at once, and is
  /// then left alone.
  static const String addArtworkChecked =
      'ALTER TABLE $name ADD COLUMN $artworkChecked INTEGER NOT NULL DEFAULT 0';

  /// Partial index over the backfill's only query. The unexamined rows are a
  /// shrinking minority that reaches empty and stays there, so indexing just
  /// them keeps the per-scan check proportional to what is left rather than to
  /// the size of the library.
  static const String createArtworkPendingIndex =
      'CREATE INDEX IF NOT EXISTS idx_${name}_artwork_pending '
      'ON $name($artworkChecked) WHERE $artworkChecked = 0';
}
