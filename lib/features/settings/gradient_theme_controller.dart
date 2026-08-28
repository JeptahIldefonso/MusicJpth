import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gradient_theme_model.dart';

class GradientThemeState {
  const GradientThemeState({
    required this.enabled,
    required this.preset,
  });

  final bool enabled;
  final GradientThemePreset preset;

  GradientThemeState copyWith({
    bool? enabled,
    GradientThemePreset? preset,
  }) {
    return GradientThemeState(
      enabled: enabled ?? this.enabled,
      preset: preset ?? this.preset,
    );
  }
}

class GradientThemeController extends Notifier<GradientThemeState> {
  static const _enabledKey = 'gradient_theme_enabled';
  static const _presetIdKey = 'gradient_theme_preset_id';

  @override
  GradientThemeState build() {
    _load();
    return const GradientThemeState(
      enabled: false,
      preset: GradientThemePreset.none,
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    final presetId = prefs.getString(_presetIdKey);
    final preset = GradientThemePreset.fromId(presetId);
    state = GradientThemeState(enabled: enabled, preset: preset);
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<void> setPreset(GradientThemePreset preset) async {
    state = state.copyWith(preset: preset);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetIdKey, preset.id);
  }
}

final gradientThemeProvider =
    NotifierProvider<GradientThemeController, GradientThemeState>(
  GradientThemeController.new,
);
