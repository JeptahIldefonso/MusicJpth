import 'songs_table.dart';

/// `playback_history` — one row per play, newest first when read.
abstract final class PlaybackHistoryTable {
  const PlaybackHistoryTable._();

  static const String name = 'playback_history';

  static const String id = 'id';
  static const String songId = 'song_id';
  static const String playedAt = 'played_at';

  static const String createTable =
      '''
CREATE TABLE $name (
  $id INTEGER PRIMARY KEY AUTOINCREMENT,
  $songId INTEGER NOT NULL REFERENCES ${SongsTable.name}(${SongsTable.id}) ON DELETE CASCADE,
  $playedAt INTEGER NOT NULL
)''';

  static const List<String> createIndexes = <String>[
    'CREATE INDEX idx_${name}_$playedAt ON $name($playedAt)',
    'CREATE INDEX idx_${name}_$songId ON $name($songId)',
  ];
}
