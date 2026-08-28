import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/app/theme.dart';
import 'package:music_oasis/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeModeController', () {
    test('defaults to dark when nothing was saved', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), AppThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(themeModeProvider), AppThemeMode.dark);
    });

    test('loads the persisted mode', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppThemeMode.prefsKey: AppThemeMode.amoled.name,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), AppThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(themeModeProvider), AppThemeMode.amoled);
    });

    test('set() persists and applies immediately', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).set(AppThemeMode.light);

      expect(container.read(themeModeProvider), AppThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppThemeMode.prefsKey), AppThemeMode.light.name);
    });

    test('unknown saved value falls back to dark', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppThemeMode.prefsKey: 'no-such-mode',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await Future<void>.delayed(Duration.zero);
      expect(container.read(themeModeProvider), AppThemeMode.dark);
    });
  });
}