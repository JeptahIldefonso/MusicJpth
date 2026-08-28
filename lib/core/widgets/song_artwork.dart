import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../services/artwork/artwork_cache_service.dart';

/// Square artwork tile with a sharp-edged dark-grey placeholder.
///
/// Resolves the relative artwork path stored in the database to an
/// absolute file via [ArtworkCacheService]. A cover already resolved once in
/// this process paints synchronously, so scrolling and rebuilds never drop
/// back to the placeholder; only a first sighting waits on the filesystem.
class SongArtwork extends ConsumerWidget {
  const SongArtwork({
    required this.size,
    super.key,
    this.artworkPath,
    this.iconSize,
    this.accent = true,
  });

  final String? artworkPath;
  final double size;
  final double? iconSize;
  final bool accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ArtworkCacheService cache =
        ref.watch(artworkCacheServiceProvider);
    final ThemeData theme = Theme.of(context);
    final MusicOasisTokens tokens = MusicOasisTokens.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: tokens.hairline,
          width: MusicOasisSpacing.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _child(context, cache),
    );
  }

  Widget _child(BuildContext context, ArtworkCacheService cache) {
    final String? path = artworkPath;
    if (path == null || path.isEmpty) return _placeholder();

    // Already resolved in this process: paint it now, no future, no flash.
    final File? memoised = ArtworkCacheService.peek(path);
    if (memoised != null) return _image(memoised, context);

    return FutureBuilder<File?>(
      future: cache.resolve(path),
      builder: (BuildContext context, AsyncSnapshot<File?> snap) {
        final File? file = snap.data;
        if (file != null) return _image(file, context);
        return _placeholder();
      },
    );
  }

  /// Decodes at the device pixel size actually painted, not a fixed multiple:
  /// a 280pt player cover on a 3× screen is 840px, and anything beyond that is
  /// memory spent on pixels the tile cannot show.
  Widget _image(File file, BuildContext context) => Image.file(
    file,
    fit: BoxFit.cover,
    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
    errorBuilder: (_, _, _) => _placeholder(),
  );

  Widget _placeholder() => _Placeholder(size: iconSize ?? size * 0.4);
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.music_note_outlined,
        size: size,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
