import 'songs_table.dart';

/// `favorites` — songs the user has marked. One row per song at most.
abstract final class FavoritesTable {
  const FavoritesTable._();

  static const String name = 'favorites';

  static const String songId = 'song_id';
  static const String dateAdded = 'date_added';

  static const String createTable =
      '''
CREATE TABLE $name (
  $songId INTEGER PRIMARY KEY REFERENCES ${SongsTable.name}(${SongsTable.id}) ON DELETE CASCADE,
  $dateAdded INTEGER NOT NULL
)''';

  static const List<String> createIndexes = <String>[
    'CREATE INDEX idx_${name}_$dateAdded ON $name($dateAdded)',
  ];
}
