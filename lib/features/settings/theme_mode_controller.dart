import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';

/// Persisted appearance mode, resolved immediately on launch.
class ThemeModeController extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    _load();
    return AppThemeMode.dark;
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppThemeMode saved =
        AppThemeMode.fromName(prefs.getString(AppThemeMode.prefsKey));
    if (saved != state) state = saved;
  }

  /// Applies a new mode immediately and persists it.
  Future<void> set(AppThemeMode mode) async {
    if (mode != state) state = mode;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppThemeMode.prefsKey, mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, AppThemeMode>(
  ThemeModeController.new,
);