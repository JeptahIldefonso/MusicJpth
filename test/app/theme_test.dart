import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/app/theme.dart';

void main() {
  group('MusicOasisTheme', () {
    test('exposes a dark theme with correct brightness', () {
      expect(MusicOasisTheme.dark.brightness, Brightness.dark);
    });

    test('scaffold background follows the scheme surface', () {
      expect(
        MusicOasisTheme.dark.scaffoldBackgroundColor,
        MusicOasisPalette.background,
      );
    });

    test('palette stays monochrome outside the error role', () {
      final ColorScheme scheme = MusicOasisTheme.darkScheme;
      for (final Color color in <Color>[
        scheme.surface,
        scheme.onSurface,
        scheme.onSurfaceVariant,
        scheme.primary,
        scheme.onPrimary,
        scheme.secondary,
        scheme.outline,
        scheme.outlineVariant,
      ]) {
        final double spread =
            <double>[color.r, color.g, color.b].reduce(max) -
            <double>[color.r, color.g, color.b].reduce(min);
        expect(spread, lessThan(0.05), reason: '$color should be monochrome');
      }
    });

    test('carries MusicOasisTokens with a monospace metadata style', () {
      final MusicOasisTokens? tokens =
          MusicOasisTheme.dark.extension<MusicOasisTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.metadata.fontFamilyFallback, contains('monospace'));
      expect(tokens.metadataStrong.fontFamilyFallback, contains('monospace'));
    });

    test('uses hairline borders and no elevation', () {
      final ThemeData theme = MusicOasisTheme.dark;
      expect(theme.dividerTheme.thickness, MusicOasisSpacing.hairline);
      expect(theme.cardTheme.elevation, 0);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
    });

    test('tokens lerp correctly', () {
      final MusicOasisTokens mid = MusicOasisTheme.darkTokens.lerp(
        MusicOasisTheme.darkTokens,
        0.5,
      );
      expect(mid.hairline, MusicOasisPalette.divider);
    });
  });
}
