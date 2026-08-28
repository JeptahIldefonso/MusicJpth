/// `playlists` — user-created playlists. Contents live in `playlist_songs`.
abstract final class PlaylistsTable {
  const PlaylistsTable._();

  static const String name = 'playlists';

  static const String id = 'id';
  static const String playlistName = 'name';
  static const String dateCreated = 'date_created';
  static const String dateModified = 'date_modified';

  static const String createTable =
      '''
CREATE TABLE $name (
  $id INTEGER PRIMARY KEY AUTOINCREMENT,
  $playlistName TEXT NOT NULL,
  $dateCreated INTEGER NOT NULL,
  $dateModified INTEGER NOT NULL
)''';

  static const List<String> createIndexes = <String>[
    'CREATE UNIQUE INDEX idx_${name}_$playlistName ON $name($playlistName)',
    'CREATE INDEX idx_${name}_$dateModified ON $name($dateModified)',
  ];
}
