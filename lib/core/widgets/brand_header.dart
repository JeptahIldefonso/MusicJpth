import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Minimal brand header: logo icon + "MUSIC JPTH".
///
/// The single shared branding element in the app. Displayed once at the top
/// of each main screen to establish identity without displacing the
/// screen-specific title, and reused for the desktop sidebar mark.
///
/// The logo is the full 1024x1024 artwork cropped square and cached at a
/// size matched to [`size`], so small renders never decode the full image.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    this.size = 28,
    this.labelStyle,
  });

  final double size;

  /// Text style for the "MUSIC JPTH" label.
  ///
  /// Falls back to the theme's secondary text colour so the header stays
  /// legible in every appearance mode.
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final TextStyle style =
        labelStyle ??
        TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Row(
      children: <Widget>[
        ClipRect(
          child: SizedBox(
            width: size,
            height: size,
            child: Image.asset(
              'assets/MusicJpth.jpg',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              cacheWidth: (size * 4).round(),
            ),
          ),
        ),
        const SizedBox(width: MusicOasisSpacing.sm),
        Text('MUSIC JPTH', style: style),
      ],
    );
  }
}
