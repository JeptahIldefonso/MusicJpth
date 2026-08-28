import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/app/theme.dart';
import 'package:music_oasis/core/widgets/song_artwork.dart';
import 'package:music_oasis/features/playlists/playlists_screen.dart';

/// The playlist cover is the regressions canary for the yellow/black flex
/// stripe: any count of artworks must lay out inside the square at every size
/// the app uses (list 48, grid ~128-192, detail up to 280) — fractions and
/// all — with never a single pixel of overflow.
void main() {
  Widget cover(List<String?> paths, double size) => ProviderScope(
    child: MaterialApp(
      theme: MusicOasisTheme.dark,
      home: Scaffold(
        body: Center(child: PlaylistCover(paths: paths, size: size)),
      ),
    ),
  );

  testWidgets('zero artworks show the note placeholder, not a collage', (
    tester,
  ) async {
    await tester.pumpWidget(cover(const <String?>[], 192));
    await tester.pumpAndSettle();

    expect(find.byType(PlaylistCover), findsOneWidget);
    expect(find.byType(SongArtwork), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final int count in <int>[1, 2, 3, 4]) {
    testWidgets('$count artworks render one collage tile each, no overflow', (
      tester,
    ) async {
      final List<String?> paths = <String?>[
        for (int i = 0; i < count; i++)
          i.isEven ? '/art/$i.jpg' : null,
      ];

      for (final double size in <double>[48, 136.5, 192, 280]) {
        await tester.pumpWidget(cover(paths, size));
        await tester.pumpAndSettle();

        expect(find.byType(SongArtwork), findsNWidgets(count), reason: 'size $size');
        expect(tester.takeException(), isNull, reason: 'size $size');
      }
    });
  }
}