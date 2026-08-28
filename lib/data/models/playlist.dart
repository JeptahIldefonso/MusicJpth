import 'package:flutter/foundation.dart';

/// One row of the playlists list: identity plus what a list row shows.
@immutable
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.songCount,
    required this.dateModified,
  });

  final int id;
  final String name;
  final int songCount;

  /// Epoch milliseconds; drives recency ordering of the list.
  final int dateModified;

  @override
  bool operator ==(Object other) =>
      other is Playlist &&
      other.id == id &&
      other.name == name &&
      other.songCount == songCount &&
      other.dateModified == dateModified;

  @override
  int get hashCode => Object.hash(id, name, songCount, dateModified);
}
