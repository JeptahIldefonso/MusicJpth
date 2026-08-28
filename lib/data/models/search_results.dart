import 'package:flutter/foundation.dart';

import 'song.dart';

/// One matching artist, album, playlist or genre name.
@immutable
class NamedResult {
  const NamedResult({required this.label, this.detail});

  final String label;

  /// Secondary line, e.g. an album's artist.
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is NamedResult && other.label == label && other.detail == detail;

  @override
  int get hashCode => Object.hash(label, detail);
}

/// Everything one query matched, grouped as `DESIGN.md` requires.
///
/// Each group is capped by the repository; [capped] marks groups where more
/// rows exist than shown, so the header can say so honestly without a count
/// query.
@immutable
class SearchResults {
  const SearchResults({
    this.songs = const <Song>[],
    this.artists = const <NamedResult>[],
    this.albums = const <NamedResult>[],
    this.playlists = const <NamedResult>[],
    this.genres = const <String>[],
    this.capped = const <String, bool>{},
  });

  /// Song matches reuse the library row model so a tap can play immediately.
  final List<Song> songs;
  final List<NamedResult> artists;
  final List<NamedResult> albums;
  final List<NamedResult> playlists;
  final List<String> genres;
  final Map<String, bool> capped;

  bool get isEmpty =>
      songs.isEmpty &&
      artists.isEmpty &&
      albums.isEmpty &&
      playlists.isEmpty &&
      genres.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is SearchResults &&
      listEquals(other.songs, songs) &&
      listEquals(other.artists, artists) &&
      listEquals(other.albums, albums) &&
      listEquals(other.playlists, playlists) &&
      listEquals(other.genres, genres) &&
      mapEquals(other.capped, capped);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(songs),
    Object.hashAll(artists),
    Object.hashAll(albums),
    Object.hashAll(playlists),
    Object.hashAll(genres),
  );
}
