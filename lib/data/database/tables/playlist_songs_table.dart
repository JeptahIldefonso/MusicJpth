import 'playlists_table.dart';
import 'songs_table.dart';

/// `playlist_songs` — ordered membership of songs in a playlist.
///
/// A surrogate key rather than `(playlist_id, song_id)`: the same song may
/// legitimately appear twice in one playlist, and reordering rewrites
/// [position] without fighting a unique constraint.
abstract final class PlaylistSongsTable {
  const PlaylistSongsTable._();

  static const String name = 'playlist_songs';

  static const String id = 'id';
  static const String playlistId = 'playlist_id';
  static const String songId = 'song_id';
  static const String position = 'position';

  /// Cascades: deleting a playlist or a song removes its membership rows.
  static const String createTable =
      '''
CREATE TABLE $name (
  $id INTEGER PRIMARY KEY AUTOINCREMENT,
  $playlistId INTEGER NOT NULL REFERENCES ${PlaylistsTable.name}(${PlaylistsTable.id}) ON DELETE CASCADE,
  $songId INTEGER NOT NULL REFERENCES ${SongsTable.name}(${SongsTable.id}) ON DELETE CASCADE,
  $position INTEGER NOT NULL
)''';

  static const List<String> createIndexes = <String>[
    // Reading a playlist in order is the hot query.
    'CREATE INDEX idx_${name}_${playlistId}_$position ON $name($playlistId, $position)',
    'CREATE INDEX idx_${name}_$songId ON $name($songId)',
  ];
}
