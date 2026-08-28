/// `music_folders` — the folders the user granted and asked to be scanned.
///
/// [lastScanned] is the scan bookkeeping referred to in `REQUIREMENTS.md` §05;
/// it lets a later incremental scan skip untouched folders.
abstract final class MusicFoldersTable {
  const MusicFoldersTable._();

  static const String name = 'music_folders';

  static const String id = 'id';
  static const String path = 'path';
  static const String dateAdded = 'date_added';
  static const String lastScanned = 'last_scanned';

  static const String createTable =
      '''
CREATE TABLE $name (
  $id INTEGER PRIMARY KEY AUTOINCREMENT,
  $path TEXT NOT NULL,
  $dateAdded INTEGER NOT NULL,
  $lastScanned INTEGER
)''';

  static const List<String> createIndexes = <String>[
    'CREATE UNIQUE INDEX idx_${name}_$path ON $name($path)',
  ];
}
