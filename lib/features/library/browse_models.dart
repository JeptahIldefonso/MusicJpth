import 'package:flutter/foundation.dart';

import '../../data/models/song.dart';

/// One album as the Library shows it: a group of songs sharing an album title
/// and artist. Read model derived in the UI layer from the existing library —
/// the album table is not duplicated here.
@immutable
class AlbumItem {
  const AlbumItem({
    required this.key,
    required this.title,
    required this.artistName,
    required this.songs,
  });

  /// Artist + title composite, unique within the derived list.
  final String key;
  final String title;

  /// May be 'Unknown Artist' for untagged files.
  final String artistName;
  final List<Song> songs;

  int get songCount => songs.length;

  /// The first cover actually extracted for any song in the album; `null` when
  /// none has artwork, so the placeholder is honest.
  String? get artworkPath {
    for (final Song song in songs) {
      final String? path = song.artworkPath;
      if (path != null && path.isNotEmpty) return path;
    }
    return null;
  }
}

/// One artist as the Library shows it: a group of songs sharing an artist name.
@immutable
class ArtistItem {
  const ArtistItem({required this.name, required this.songs});

  /// May be 'Unknown Artist' for untagged files.
  final String name;
  final List<Song> songs;

  int get songCount => songs.length;

  String? get artworkPath {
    for (final Song song in songs) {
      final String? path = song.artworkPath;
      if (path != null && path.isNotEmpty) return path;
    }
    return null;
  }
}