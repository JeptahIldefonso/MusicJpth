import 'package:flutter/painting.dart';

enum GradientThemePreset {
  none(
    id: 'none',
    label: 'Off',
    colors: [],
  ),
  bronze(
    id: 'bronze',
    label: 'Bronze Glow',
    colors: [Color(0xFF2E170E), Color(0xFF0F0704)],
  ),
  royalBlue(
    id: 'royalblue',
    label: 'Royal Blue',
    colors: [Color(0xFF0E223D), Color(0xFF040B14)],
  ),
  mysticPurple(
    id: 'mysticpurple',
    label: 'Mystic Purple',
    colors: [Color(0xFF2B143D), Color(0xFF0C0412)],
  ),
  warmTaupe(
    id: 'warmtaupe',
    label: 'Warm Taupe',
    colors: [Color(0xFF2B221E), Color(0xFF0E0B0A)],
  ),
  deepTeal(
    id: 'deepteal',
    label: 'Deep Teal',
    colors: [Color(0xFF0E2E2A), Color(0xFF040F0D)],
  ),
  velvetBurgundy(
    id: 'velvetburgundy',
    label: 'Velvet Burgundy',
    colors: [Color(0xFF330E1E), Color(0xFF0F0308)],
  ),
  midnightSlate(
    id: 'midnightslate',
    label: 'Midnight Slate',
    colors: [Color(0xFF1E2633), Color(0xFF0A0D12)],
  ),
  emeraldForest(
    id: 'emeraldforest',
    label: 'Emerald Forest',
    colors: [Color(0xFF112E1B), Color(0xFF050F08)],
  );

  const GradientThemePreset({
    required this.id,
    required this.label,
    required this.colors,
  });

  final String id;
  final String label;
  final List<Color> colors;

  static GradientThemePreset fromId(String? id) {
    return GradientThemePreset.values.firstWhere(
      (p) => p.id == id,
      orElse: () => GradientThemePreset.none,
    );
  }
}
