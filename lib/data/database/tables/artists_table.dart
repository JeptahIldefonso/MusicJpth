/// `artists` — one row per distinct artist name.
///
/// Songs and albums reference this table so an artist rename touches one row.
abstract final class ArtistsTable {
  const ArtistsTable._();

  static const String name = 'artists';

  static const String id = 'id';
  static const String artistName = 'name';

  static const String createTable =
      '''
CREATE TABLE $name (
  $id INTEGER PRIMARY KEY AUTOINCREMENT,
  $artistName TEXT NOT NULL
)''';

  /// Unique so the scanner can upsert by name; also serves name lookups.
  static const List<String> createIndexes = <String>[
    'CREATE UNIQUE INDEX idx_${name}_$artistName ON $name($artistName)',
  ];
}
