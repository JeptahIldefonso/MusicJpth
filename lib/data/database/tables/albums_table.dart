import 'artists_table.dart';

/// `albums` — one row per album, optionally attributed to an artist.
abstract final class AlbumsTable {
  const AlbumsTable._();

  static const String name = 'albums';

  static const String id = 'id';
  static const String title = 'title';
  static const String artistId = 'artist_id';
  static const String year = 'year';
  static const String artworkPath = 'artwork_path';

  /// `ON DELETE SET NULL`: losing an artist row must not delete the album.
  static const String createTable =
      '''
CREATE TABLE $name (
  $id INTEGER PRIMARY KEY AUTOINCREMENT,
  $title TEXT NOT NULL,
  $artistId INTEGER REFERENCES ${ArtistsTable.name}(${ArtistsTable.id}) ON DELETE SET NULL,
  $year INTEGER,
  $artworkPath TEXT
)''';

  static const List<String> createIndexes = <String>[
    // Same title by different artists stays distinct; scanner upserts on this.
    'CREATE UNIQUE INDEX idx_${name}_${title}_$artistId ON $name($title, $artistId)',
    'CREATE INDEX idx_${name}_$artistId ON $name($artistId)',
  ];
}
