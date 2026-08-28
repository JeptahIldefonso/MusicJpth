import 'package:sqflite/sqflite.dart' show Database;

import '../database/tables/albums_table.dart';
import '../database/tables/artists_table.dart';
import '../database/tables/playlists_table.dart';
import '../database/tables/songs_table.dart';
import '../models/search_results.dart';
import '../models/song.dart';

/// Per-group result cap. A page, not a wall: large libraries stay honest via
/// the [SearchResults.capped] marker instead of a second count query
/// (`REQUIREMENTS.md` §21: pagination when useful).
const int groupLimit = 25;

/// Read-only grouped search over the indexed library.
///
/// Every query is a bounded SQLite `LIKE` against indexed columns — title,
/// artist name, album title, playlist name — plus the genre column; the
/// filesystem is never touched and no tag is re-read (`REQUIREMENTS.md` §22).
class SearchRepository {
  const SearchRepository(this._db);

  final Database _db;

  /// Runs all group queries for one user query. Sequential awaits on the same
  /// connection keep it simple and ordered; each is index-backed and capped,
  /// so the whole set costs milliseconds even on five-figure libraries.
  Future<SearchResults> search(String query) async {
    final String pattern = '%${_escapeLike(query)}%';

    final List<Song> songs = (await _db.rawQuery(
      'SELECT s.${SongsTable.id}, s.${SongsTable.path}, s.${SongsTable.title}, '
      's.${SongsTable.duration}, s.${SongsTable.trackNumber}, '
      's.${SongsTable.artworkPath}, '
      's.${SongsTable.isAvailable}, '
      'a.${ArtistsTable.artistName} AS artist_name, '
      'al.${AlbumsTable.title} AS album_title '
      'FROM ${SongsTable.name} AS s '
      'LEFT JOIN ${ArtistsTable.name} AS a ON a.${ArtistsTable.id} = s.${SongsTable.artistId} '
      'LEFT JOIN ${AlbumsTable.name} AS al ON al.${AlbumsTable.id} = s.${SongsTable.albumId} '
      "WHERE s.${SongsTable.title} COLLATE NOCASE LIKE ? ESCAPE '\\' "
      'ORDER BY s.${SongsTable.isAvailable} DESC, '
      's.${SongsTable.title} COLLATE NOCASE ASC, s.${SongsTable.id} ASC '
      'LIMIT ?',
      <Object?>[pattern, groupLimit + 1],
    )).map(Song.fromRow).toList();

    final List<NamedResult> artists = await _names(
      ArtistsTable.name,
      ArtistsTable.artistName,
      pattern,
    );
    final List<NamedResult> albums = (await _db.rawQuery(
      'SELECT al.${AlbumsTable.title} AS label, '
      'a.${ArtistsTable.artistName} AS detail '
      'FROM ${AlbumsTable.name} AS al '
      'LEFT JOIN ${ArtistsTable.name} AS a ON a.${ArtistsTable.id} = al.${AlbumsTable.artistId} '
      "WHERE al.${AlbumsTable.title} COLLATE NOCASE LIKE ? ESCAPE '\\' "
      'ORDER BY al.${AlbumsTable.title} COLLATE NOCASE ASC '
      'LIMIT ?',
      <Object?>[pattern, groupLimit + 1],
    )).map(_namedFromRow).toList();
    final List<NamedResult> playlists = await _names(
      PlaylistsTable.name,
      PlaylistsTable.playlistName,
      pattern,
    );

    final List<String> genres =
        (await _db.query(
              SongsTable.name,
              distinct: true,
              columns: <String>[SongsTable.genre],
              where: "${SongsTable.genre} COLLATE NOCASE LIKE ? ESCAPE '\\'",
              whereArgs: <Object?>[pattern],
              orderBy: '${SongsTable.genre} COLLATE NOCASE ASC',
              limit: groupLimit + 1,
            ))
            .map((Map<String, Object?> row) => row[SongsTable.genre]! as String)
            .toList();

    return SearchResults(
      songs: _capped(songs),
      artists: _capped(artists),
      albums: _capped(albums),
      playlists: _capped(playlists),
      genres: _capped(genres),
      capped: <String, bool>{
        if (_over(songs)) 'songs': true,
        if (_over(artists)) 'artists': true,
        if (_over(albums)) 'albums': true,
        if (_over(playlists)) 'playlists': true,
        if (_over(genres)) 'genres': true,
      },
    );
  }

  /// One-column name lookup shared by artists and playlists.
  Future<List<NamedResult>> _names(
    String table,
    String column,
    String pattern,
  ) async {
    final List<Map<String, Object?>> rows = await _db.query(
      table,
      distinct: true,
      columns: <String>[column],
      where: "$column COLLATE NOCASE LIKE ? ESCAPE '\\'",
      whereArgs: <Object?>[pattern],
      orderBy: '$column COLLATE NOCASE ASC',
      limit: groupLimit + 1,
    );
    return rows
        .map(
          (Map<String, Object?> row) =>
              NamedResult(label: row[column]! as String),
        )
        .toList(growable: false);
  }

  NamedResult _namedFromRow(Map<String, Object?> row) => NamedResult(
    label: row['label']! as String,
    detail: row['detail'] as String?,
  );

  /// User input must never inject wildcards: `%` and `_` are literals here.
  static String _escapeLike(String query) => query
      .replaceAll('\\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  static bool _over<T>(List<T> list) => list.length > groupLimit;

  /// Trims an over-limit fetch down to the visible cap.
  static List<T> _capped<T>(List<T> list) =>
      _over(list) ? list.sublist(0, groupLimit) : list;
}
