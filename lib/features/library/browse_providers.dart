import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/song.dart';
import '../../data/repositories/song_repository_provider.dart'
    show availableSongsProvider;
import 'browse_models.dart';

/// One album's display name for files the scanner never tagged.
const String unknownAlbumName = 'Unknown Album';

/// One artist's display name for files the scanner never tagged.
const String unknownArtistName = 'Unknown Artist';

/// Every album in the library, derived once from the existing full-library read.
///
/// No database change and no second data source: the repository's `all()`
/// already resolves artist and album names, and this provider groups that list
/// in place. A future is cached, so switching chips never re-reads songs.
final FutureProvider<List<AlbumItem>> albumsProvider =
    FutureProvider<List<AlbumItem>>((Ref ref) async {
  final List<Song> songs = await ref.watch(availableSongsProvider.future);
  final Map<String, ({String title, String artist, List<Song> songs})>
  buckets = <String, ({String title, String artist, List<Song> songs})>{};
  for (final Song song in songs) {
    final String title = _displayName(song.albumTitle, unknownAlbumName);
    final String artist = _displayName(song.artistName, unknownArtistName);
    final String key = '$artist\u0000$title';
    final record = buckets.putIfAbsent(
      key,
      () => (title: title, artist: artist, songs: <Song>[]),
    );
    record.songs.add(song);
  }

  final List<AlbumItem> items = <AlbumItem>[
    for (final MapEntry<String, ({String title, String artist, List<Song> songs})>
        entry in buckets.entries)
      AlbumItem(
        key: entry.key,
        title: entry.value.title,
        artistName: entry.value.artist,
        songs: _albumOrder(entry.value.songs),
      ),
  ];
  items.sort(
    (AlbumItem a, AlbumItem b) => a.title.toLowerCase().compareTo(
      b.title.toLowerCase(),
    ),
  );
  return List<AlbumItem>.unmodifiable(items);
});

/// Every artist in the library, derived once from the existing full-library read.
final FutureProvider<List<ArtistItem>> artistsProvider =
    FutureProvider<List<ArtistItem>>((Ref ref) async {
  final List<Song> songs = await ref.watch(availableSongsProvider.future);
  final Map<String, List<Song>> buckets = <String, List<Song>>{};
  for (final Song song in songs) {
    final String name = _displayName(song.artistName, unknownArtistName);
    (buckets[name] ??= <Song>[]).add(song);
  }

  final List<ArtistItem> items = <ArtistItem>[
    for (final MapEntry<String, List<Song>> entry in buckets.entries)
      ArtistItem(name: entry.key, songs: List.unmodifiable(entry.value)),
  ];
  items.sort((ArtistItem a, ArtistItem b) {
    final int rank = _artistRank(a.name).compareTo(_artistRank(b.name));
    if (rank != 0) return rank;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return List<ArtistItem>.unmodifiable(items);
});

String _displayName(String? value, String fallback) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
}

/// Albums play in track order when tags carry a number; untagged entries sort
/// by title so the order is still deterministic.
List<Song> _albumOrder(List<Song> songs) {
  final List<Song> sorted = <Song>[...songs];
  sorted.sort((Song a, Song b) {
    final int aTrack = a.trackNumber ?? -1;
    final int bTrack = b.trackNumber ?? -1;
    if (aTrack != bTrack) return aTrack.compareTo(bTrack);
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return List<Song>.unmodifiable(sorted);
}

int _artistRank(String name) =>
    name.toLowerCase() == unknownArtistName.toLowerCase() ? 1 : 0;