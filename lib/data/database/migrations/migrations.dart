import 'package:flutter/foundation.dart';

import '../tables/albums_table.dart';
import '../tables/artists_table.dart';
import '../tables/favorites_table.dart';
import '../tables/music_folders_table.dart';
import '../tables/playback_history_table.dart';
import '../tables/playlist_songs_table.dart';
import '../tables/playlists_table.dart';
import '../tables/songs_table.dart';

/// One schema version, expressed as the statements that reach it.
///
/// To evolve the schema: append a new [Migration] with the next [version] and
/// raise [schemaVersion]. Never edit a published migration — existing installs
/// have already run it, and `REQUIREMENTS.md` §43 forbids destroying a user's
/// library on update.
@immutable
class Migration {
  const Migration({required this.version, required this.statements});

  final int version;
  final List<String> statements;
}

/// Current schema version. Must equal the last entry in [migrations].
const int schemaVersion = 4;

/// Ordered, append-only migration history.
const List<Migration> migrations = <Migration>[
  Migration(version: 1, statements: _initialSchema),
  Migration(version: 2, statements: _songAvailability),
  Migration(version: 3, statements: _libraryOrderIndex),
  Migration(version: 4, statements: _artworkBackfill),
];

/// Statements needed to move a database from [from] to [to], in order.
///
/// A fresh database passes `from: 0`; an upgrade passes the stored version.
List<String> statementsBetween({required int from, required int to}) {
  assert(
    migrations.last.version == schemaVersion,
    'schemaVersion must match the last migration',
  );
  return <String>[
    for (final Migration migration in migrations)
      if (migration.version > from && migration.version <= to)
        ...migration.statements,
  ];
}

/// Version 1: the library schema from `CLAUDE.md` §09.
///
/// Tables precede their indexes, and referenced tables precede their
/// referencing tables so the foreign keys resolve on creation.
const List<String> _initialSchema = <String>[
  ArtistsTable.createTable,
  ...ArtistsTable.createIndexes,
  AlbumsTable.createTable,
  ...AlbumsTable.createIndexes,
  SongsTable.createTable,
  ...SongsTable.createIndexes,
  PlaylistsTable.createTable,
  ...PlaylistsTable.createIndexes,
  PlaylistSongsTable.createTable,
  ...PlaylistSongsTable.createIndexes,
  FavoritesTable.createTable,
  ...FavoritesTable.createIndexes,
  PlaybackHistoryTable.createTable,
  ...PlaybackHistoryTable.createIndexes,
  MusicFoldersTable.createTable,
  ...MusicFoldersTable.createIndexes,
];

/// Version 2: a song whose file a scan can no longer find is marked unavailable
/// instead of deleted (`PROJECT.md` §12).
///
/// Deleting the row would take the user's playlist entries, favorites and
/// playback history with it — an unplugged drive or a file moved and moved back
/// must not cost them (`REQUIREMENTS.md` §43).
const List<String> _songAvailability = <String>[SongsTable.addIsAvailable];

/// Version 3: large-library optimisation — the Library browse order as a real
/// index, so paged reads stop sorting the table (`REQUIREMENTS.md` §21).
const List<String> _libraryOrderIndex = <String>[
  SongsTable.createLibraryOrderIndex,
];

/// Version 4: make lost cover art recoverable.
///
/// Cover extraction happens inside the tag pass, and the tag pass deliberately
/// skips files whose size and mtime are unchanged (`REQUIREMENTS.md` §31).
/// That is correct for tags — they cannot change without the file changing —
/// but artwork lives in a cache *outside* the file, so it can go missing while
/// the file stays identical, and nothing would ever look again. This column
/// records whether a row has been examined; every existing row starts
/// unexamined and the next scan repairs it once.
///
/// Additive and defaulted, so an upgrade rewrites no rows and destroys no
/// library (`REQUIREMENTS.md` §43).
const List<String> _artworkBackfill = <String>[
  SongsTable.addArtworkChecked,
  SongsTable.createArtworkPendingIndex,
];
