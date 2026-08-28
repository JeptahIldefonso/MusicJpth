import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/history/playback_history_controller.dart'
    show playbackHistoryRecorderProvider;
import '../features/settings/gradient_theme_controller.dart';
import '../features/settings/theme_mode_controller.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget of Music Oasis.
class MusicOasisApp extends ConsumerWidget {
  const MusicOasisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    ref.watch(playbackHistoryRecorderProvider);
    final AppThemeMode mode = ref.watch(themeModeProvider);
    final GradientThemeState gradientState = ref.watch(gradientThemeProvider);

    final bool gradientActive =
        gradientState.enabled && gradientState.preset.colors.isNotEmpty;

    // When gradient is active, make every Scaffold transparent so the
    // gradient behind them (applied via the MaterialApp builder) shows through.
    final ThemeData theme = gradientActive
        ? mode.theme.copyWith(scaffoldBackgroundColor: Colors.transparent)
        : mode.theme;

    return MaterialApp.router(
      title: 'Music Jpth',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (BuildContext ctx, Widget? child) {
        if (gradientActive) {
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientState.preset.colors,
              ),
            ),
            child: child!,
          );
        }
        return child!;
      },
    );
  }
}
