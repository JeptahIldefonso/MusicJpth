import 'package:flutter/material.dart';

/// Raw Luxury Monochromatic palette — Chrome Hearts inspired.
///
/// Pitch-black void, pure white text, metallic silver secondary.
/// The only accent is desaturated brick for genuine errors.
abstract final class MusicOasisPalette {
  const MusicOasisPalette._();

  /// Pitch-black void background.
  static const Color background = Color(0xFF000000);

  /// Dark surface for elevated elements.
  static const Color surface = Color(0xFF0A0A0A);

  /// Primary text — pure white.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary text — metallic silver-grey.
  static const Color textSecondary = Color(0xFFA9A9A9);

  /// Muted text — dark silver.
  static const Color textMuted = Color(0xFF555555);

  /// Hairline dividers and borders — silver.
  static const Color divider = Color(0xFF333333);

  /// Dark background for Now Playing screen.
  static const Color darkBg = Color(0xFF000000);

  /// Elevated surface on dark background.
  static const Color darkSurface = Color(0xFF111111);

  /// White text on dark backgrounds.
  static const Color white = Color(0xFFFFFFFF);

  /// Desaturated brick — the only hue permitted, for genuine errors.
  static const Color error = Color(0xFFA84B3F);

  /// Light error variant.
  static const Color errorLight = Color(0xFF8C3A30);

  /// Smoked glass background for nav and mini player.
  static const Color smokedGlass = Color(0xB3000000);
}

/// Light-mode palette per DESIGN.md — warm grey paper with near-black ink.
///
/// The only hue remains the desaturated brick reserved for genuine errors.
abstract final class MusicOasisLightPalette {
  const MusicOasisLightPalette._();

  /// Warm grey paper background.
  static const Color background = Color(0xFFF2F1ED);

  /// Card-white surface for elevated elements.
  static const Color surface = Color(0xFFFFFFFF);

  /// Primary text — near-black ink.
  static const Color textPrimary = Color(0xFF111111);

  /// Secondary text — warm grey.
  static const Color textSecondary = Color(0xFF666666);

  /// Muted text — pale grey.
  static const Color textMuted = Color(0xFF999999);

  /// Hairline dividers and borders.
  static const Color divider = Color(0xFFD2D1CD);

  /// White translucent smoked glass for nav and mini player.
  static const Color smokedGlass = Color(0xE6FFFFFF);

  /// Desaturated brick — the only hue permitted, for genuine errors.
  static const Color error = Color(0xFFA84B3F);

  /// Light error variant.
  static const Color errorLight = Color(0xFF8C3A30);
}

/// AMOLED palette — pure black everywhere, chrome dimmed to barely visible.
abstract final class MusicOasisAmoledPalette {
  const MusicOasisAmoledPalette._();

  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF000000);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8F8F8F);
  static const Color textMuted = Color(0xFF4A4A4A);

  /// Borders recede on a fully black background.
  static const Color divider = Color(0xFF262626);

  static const Color smokedGlass = Color(0xF2000000);

  static const Color error = Color(0xFFA84B3F);
}

/// Spacing rhythm.
abstract final class MusicOasisSpacing {
  const MusicOasisSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 40;
  static const double xxl = 64;

  /// Thin borders instead of cards and shadows.
  static const double hairline = 1;
}

/// Navigation constants.
abstract final class MusicOasisNav {
  const MusicOasisNav._();

  static const double mobileTabBarHeight = 56;
  static const double sidebarWidth = 220;
  static const double sidebarItemHeight = 44;
  static const double blur = 20;
  static const double tabBarOpacity = 0.85;
}

/// Artwork size constants.
abstract final class MusicOasisArtwork {
  const MusicOasisArtwork._();

  static const double listSize = 48;
  static const double playerSize = 280;
}

/// Music Oasis design tokens that Material [ThemeData] has no slot for.
///
/// Monospace metadata, hairline color, and the smoked glass effect tokens.
@immutable
class MusicOasisTokens extends ThemeExtension<MusicOasisTokens> {
  const MusicOasisTokens({
    required this.hairline,
    required this.smokedGlass,
    required this.chrome,
    required this.metadata,
    required this.metadataStrong,
  });

  /// Colour for thin dividers and borders.
  final Color hairline;

  /// Smoked glass background for nav and mini player.
  final Color smokedGlass;

  /// Chromatic background for shell chrome (sidebar, tab backdrop).
  final Color chrome;

  /// Monospace style for technical metadata.
  final TextStyle metadata;

  /// Monospace style for emphasised metadata, e.g. the currently playing row.
  final TextStyle metadataStrong;

  /// Monospace stack resolved from the platform, so no bundled font asset.
  static const List<String> monoFamilyFallback = <String>[
    'Consolas',
    'Cascadia Mono',
    'SF Mono',
    'DejaVu Sans Mono',
    'Roboto Mono',
    'monospace',
  ];

  /// Sans-serif stack for body text — sharp, brutalist.
  static const List<String> bodyFamilyFallback = <String>[
    'Inter',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  static MusicOasisTokens of(BuildContext context) =>
      Theme.of(context).extension<MusicOasisTokens>()!;

  @override
  MusicOasisTokens copyWith({
    Color? hairline,
    Color? smokedGlass,
    Color? chrome,
    TextStyle? metadata,
    TextStyle? metadataStrong,
  }) {
    return MusicOasisTokens(
      hairline: hairline ?? this.hairline,
      smokedGlass: smokedGlass ?? this.smokedGlass,
      chrome: chrome ?? this.chrome,
      metadata: metadata ?? this.metadata,
      metadataStrong: metadataStrong ?? this.metadataStrong,
    );
  }

  @override
  MusicOasisTokens lerp(ThemeExtension<MusicOasisTokens>? other, double t) {
    if (other is! MusicOasisTokens) return this;
    return MusicOasisTokens(
      hairline: Color.lerp(hairline, other.hairline, t)!,
      smokedGlass: Color.lerp(smokedGlass, other.smokedGlass, t)!,
      chrome: Color.lerp(chrome, other.chrome, t)!,
      metadata: TextStyle.lerp(metadata, other.metadata, t)!,
      metadataStrong: TextStyle.lerp(metadataStrong, other.metadataStrong, t)!,
    );
  }
}

/// Builds the Music Oasis theme — Raw Luxury Monochromatic.
abstract final class MusicOasisTheme {
  const MusicOasisTheme._();

  static ThemeData get dark => _build(
        darkScheme,
        darkTokens,
        _darkChrome,
        Brightness.dark,
      );

  /// Light theme per DESIGN.md — warm grey paper, near-black ink.
  static ThemeData get light => _build(
        lightScheme,
        lightTokens,
        _lightChrome,
        Brightness.light,
      );

  /// Pure-black AMOLED variant — identical chrome, all surfaces black.
  static ThemeData get amoled => _build(
        amoledScheme,
        amoledTokens,
        _amoledChrome,
        Brightness.dark,
      );

  /// Resolves the theme for a persisted mode.
  static ThemeData themeFor(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.light => light,
      AppThemeMode.amoled => amoled,
      AppThemeMode.dark => dark,
    };
  }

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: MusicOasisPalette.white,
    onPrimary: MusicOasisPalette.background,
    primaryContainer: MusicOasisPalette.surface,
    onPrimaryContainer: MusicOasisPalette.white,
    secondary: MusicOasisPalette.textSecondary,
    onSecondary: MusicOasisPalette.white,
    secondaryContainer: MusicOasisPalette.background,
    onSecondaryContainer: MusicOasisPalette.white,
    tertiary: MusicOasisPalette.white,
    onTertiary: MusicOasisPalette.background,
    error: MusicOasisPalette.error,
    onError: MusicOasisPalette.white,
    surface: MusicOasisPalette.surface,
    onSurface: MusicOasisPalette.textPrimary,
    onSurfaceVariant: MusicOasisPalette.textSecondary,
    surfaceContainerLowest: MusicOasisPalette.background,
    surfaceContainerLow: MusicOasisPalette.surface,
    surfaceContainer: MusicOasisPalette.background,
    surfaceContainerHigh: MusicOasisPalette.darkSurface,
    surfaceContainerHighest: MusicOasisPalette.darkSurface,
    outline: MusicOasisPalette.textSecondary,
    outlineVariant: MusicOasisPalette.divider,
    inverseSurface: MusicOasisPalette.white,
    onInverseSurface: MusicOasisPalette.background,
    shadow: MusicOasisPalette.background,
    scrim: MusicOasisPalette.background,
  );

  /// Light scheme — monochrome, warm grey paper.
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: MusicOasisLightPalette.textPrimary,
    onPrimary: MusicOasisLightPalette.surface,
    primaryContainer: MusicOasisLightPalette.background,
    onPrimaryContainer: MusicOasisLightPalette.textPrimary,
    secondary: MusicOasisLightPalette.textSecondary,
    onSecondary: MusicOasisLightPalette.surface,
    secondaryContainer: MusicOasisLightPalette.background,
    onSecondaryContainer: MusicOasisLightPalette.textPrimary,
    tertiary: MusicOasisLightPalette.textPrimary,
    onTertiary: MusicOasisLightPalette.surface,
    error: MusicOasisLightPalette.error,
    onError: MusicOasisLightPalette.surface,
    surface: MusicOasisLightPalette.surface,
    onSurface: MusicOasisLightPalette.textPrimary,
    onSurfaceVariant: MusicOasisLightPalette.textSecondary,
    surfaceContainerLowest: MusicOasisLightPalette.background,
    surfaceContainerLow: MusicOasisLightPalette.surface,
    surfaceContainer: MusicOasisLightPalette.background,
    surfaceContainerHigh: MusicOasisLightPalette.surface,
    surfaceContainerHighest: MusicOasisLightPalette.surface,
    outline: MusicOasisLightPalette.textSecondary,
    outlineVariant: MusicOasisLightPalette.divider,
    inverseSurface: MusicOasisLightPalette.textPrimary,
    onInverseSurface: MusicOasisLightPalette.surface,
    shadow: MusicOasisLightPalette.background,
    scrim: MusicOasisPalette.background,
  );

  /// AMOLED scheme — pure black surfaces, dimmed chrome.
  static const ColorScheme amoledScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: MusicOasisAmoledPalette.textPrimary,
    onPrimary: MusicOasisAmoledPalette.background,
    primaryContainer: MusicOasisAmoledPalette.surface,
    onPrimaryContainer: MusicOasisAmoledPalette.textPrimary,
    secondary: MusicOasisAmoledPalette.textSecondary,
    onSecondary: MusicOasisAmoledPalette.textPrimary,
    secondaryContainer: MusicOasisAmoledPalette.background,
    onSecondaryContainer: MusicOasisAmoledPalette.textPrimary,
    tertiary: MusicOasisAmoledPalette.textPrimary,
    onTertiary: MusicOasisAmoledPalette.background,
    error: MusicOasisAmoledPalette.error,
    onError: MusicOasisAmoledPalette.textPrimary,
    surface: MusicOasisAmoledPalette.surface,
    onSurface: MusicOasisAmoledPalette.textPrimary,
    onSurfaceVariant: MusicOasisAmoledPalette.textSecondary,
    surfaceContainerLowest: MusicOasisAmoledPalette.background,
    surfaceContainerLow: MusicOasisAmoledPalette.surface,
    surfaceContainer: MusicOasisAmoledPalette.background,
    surfaceContainerHigh: MusicOasisAmoledPalette.surface,
    surfaceContainerHighest: MusicOasisAmoledPalette.surface,
    outline: MusicOasisAmoledPalette.textSecondary,
    outlineVariant: MusicOasisAmoledPalette.divider,
    inverseSurface: MusicOasisAmoledPalette.textPrimary,
    onInverseSurface: MusicOasisAmoledPalette.background,
    shadow: MusicOasisAmoledPalette.background,
    scrim: MusicOasisAmoledPalette.background,
  );

  static const MusicOasisTokens darkTokens = MusicOasisTokens(
    hairline: MusicOasisPalette.divider,
    smokedGlass: MusicOasisPalette.smokedGlass,
    chrome: MusicOasisPalette.background,
    metadata: TextStyle(
      fontFamilyFallback: MusicOasisTokens.monoFamilyFallback,
      fontSize: 12,
      height: 1.3,
      letterSpacing: 0.4,
      color: MusicOasisPalette.textSecondary,
    ),
    metadataStrong: TextStyle(
      fontFamilyFallback: MusicOasisTokens.monoFamilyFallback,
      fontSize: 12,
      height: 1.3,
      letterSpacing: 0.4,
      fontWeight: FontWeight.w600,
      color: MusicOasisPalette.white,
    ),
  );

  static const MusicOasisTokens lightTokens = MusicOasisTokens(
    hairline: MusicOasisLightPalette.divider,
    smokedGlass: MusicOasisLightPalette.smokedGlass,
    chrome: MusicOasisLightPalette.background,
    metadata: TextStyle(
      fontFamilyFallback: MusicOasisTokens.monoFamilyFallback,
      fontSize: 12,
      height: 1.3,
      letterSpacing: 0.4,
      color: MusicOasisLightPalette.textMuted,
    ),
    metadataStrong: TextStyle(
      fontFamilyFallback: MusicOasisTokens.monoFamilyFallback,
      fontSize: 12,
      height: 1.3,
      letterSpacing: 0.4,
      fontWeight: FontWeight.w600,
      color: MusicOasisLightPalette.textPrimary,
    ),
  );

  static const MusicOasisTokens amoledTokens = MusicOasisTokens(
    hairline: MusicOasisAmoledPalette.divider,
    smokedGlass: MusicOasisAmoledPalette.smokedGlass,
    chrome: MusicOasisAmoledPalette.background,
    metadata: TextStyle(
      fontFamilyFallback: MusicOasisTokens.monoFamilyFallback,
      fontSize: 12,
      height: 1.3,
      letterSpacing: 0.4,
      color: MusicOasisAmoledPalette.textSecondary,
    ),
    metadataStrong: TextStyle(
      fontFamilyFallback: MusicOasisTokens.monoFamilyFallback,
      fontSize: 12,
      height: 1.3,
      letterSpacing: 0.4,
      fontWeight: FontWeight.w600,
      color: MusicOasisAmoledPalette.textPrimary,
    ),
  );

  /// Theme chrome colours (no dedicated ColorScheme role).
  static const _Chrome _darkChrome = _Chrome(
    scaffold: MusicOasisPalette.background,
    appBar: MusicOasisPalette.background,
    inputFill: MusicOasisPalette.background,
    sliderAccent: MusicOasisPalette.white,
  );

  static const _Chrome _lightChrome = _Chrome(
    scaffold: MusicOasisLightPalette.background,
    appBar: MusicOasisLightPalette.background,
    inputFill: MusicOasisLightPalette.surface,
    sliderAccent: MusicOasisLightPalette.textPrimary,
  );

  static const _Chrome _amoledChrome = _Chrome(
    scaffold: MusicOasisAmoledPalette.background,
    appBar: MusicOasisAmoledPalette.background,
    inputFill: MusicOasisAmoledPalette.background,
    sliderAccent: MusicOasisAmoledPalette.textPrimary,
  );

  /// Clean sans-serif typography per user mandate — no gothic or serif.
  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamilyFallback: MusicOasisTokens.bodyFamilyFallback,
      fontSize: 48,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.5,
      height: 1.1,
      color: MusicOasisPalette.white,
    ),
    displayMedium: TextStyle(
      fontFamilyFallback: MusicOasisTokens.bodyFamilyFallback,
      fontSize: 38,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
      height: 1.1,
      color: MusicOasisPalette.white,
    ),
    displaySmall: TextStyle(
      fontFamilyFallback: MusicOasisTokens.bodyFamilyFallback,
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      height: 1.15,
      color: MusicOasisPalette.white,
    ),
    headlineLarge: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      height: 1.15,
      fontFamilyFallback: MusicOasisTokens.bodyFamilyFallback,
      color: MusicOasisPalette.white,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      height: 1.2,
      fontFamilyFallback: MusicOasisTokens.bodyFamilyFallback,
      color: MusicOasisPalette.white,
    ),
    headlineSmall: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.25,
      fontFamilyFallback: MusicOasisTokens.bodyFamilyFallback,
      color: MusicOasisPalette.white,
    ),
    titleLarge: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.3,
      fontFamilyFallback: MusicOasisTokens.bodyFamilyFallback,
      color: MusicOasisPalette.white,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.3,
      fontFamilyFallback: MusicOasisTokens.bodyFamilyFallback,
      color: MusicOasisPalette.white,
    ),
    titleSmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      height: 1.3,
      fontFamilyFallback: MusicOasisTokens.bodyFamilyFallback,
      color: MusicOasisPalette.white,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      height: 1.45,
      fontFamilyFallback: MusicOasisTokens.bodyFamilyFallback,
      color: MusicOasisPalette.white,
    ),
    bodyMedium: TextStyle(
      fontSize: 13.5,
      height: 1.45,
      fontFamilyFallback: MusicOasisTokens.bodyFamilyFallback,
      color: MusicOasisPalette.white,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.4,
      fontFamilyFallback: MusicOasisTokens.bodyFamilyFallback,
      color: MusicOasisPalette.textSecondary,
    ),
    labelLarge: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      fontFamilyFallback: MusicOasisTokens.bodyFamilyFallback,
      color: MusicOasisPalette.white,
    ),
    labelMedium: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.0,
      fontFamilyFallback: MusicOasisTokens.monoFamilyFallback,
      color: MusicOasisPalette.textSecondary,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      fontFamilyFallback: MusicOasisTokens.monoFamilyFallback,
      color: MusicOasisPalette.textSecondary,
    ),
  );

  static ThemeData _build(
    ColorScheme scheme,
    MusicOasisTokens tokens,
    _Chrome chrome,
    Brightness brightness,
  ) {
    final TextTheme text = textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: chrome.scaffold,
      canvasColor: chrome.scaffold,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[tokens],
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkRipple.splashFactory,
      dividerTheme: DividerThemeData(
        color: tokens.hairline,
        thickness: MusicOasisSpacing.hairline,
        space: 0,
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: chrome.appBar,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        horizontalTitleGap: MusicOasisSpacing.md,
        minVerticalPadding: MusicOasisSpacing.sm,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MusicOasisSpacing.md,
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 20),
      textButtonTheme: TextButtonThemeData(style: _flatButtonStyle(text)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _flatButtonStyle(text).copyWith(
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(
              color: tokens.hairline,
              width: MusicOasisSpacing.hairline,
            ),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _flatButtonStyle(text)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: chrome.inputFill,
        border: UnderlineInputBorder(
          borderSide: BorderSide(
            color: tokens.hairline,
            width: MusicOasisSpacing.hairline,
          ),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: tokens.hairline,
            width: MusicOasisSpacing.hairline,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: scheme.onSurface,
            width: MusicOasisSpacing.hairline,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 0,
          vertical: MusicOasisSpacing.sm + MusicOasisSpacing.xs,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 2,
        activeTrackColor: chrome.sliderAccent,
        inactiveTrackColor: chrome.sliderAccent.withValues(alpha: 0.15),
        thumbColor: chrome.sliderAccent,
        overlayColor: chrome.sliderAccent.withValues(alpha: 0.08),
        showValueIndicator: ShowValueIndicator.never,
      ),
    );
  }

  /// Square, flat, wide-tracked: buttons read as purposeful, not decorative.
  static ButtonStyle _flatButtonStyle(TextTheme text) {
    return ButtonStyle(
      elevation: const WidgetStatePropertyAll<double>(0),
      textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(
          horizontal: MusicOasisSpacing.md,
          vertical: MusicOasisSpacing.sm + MusicOasisSpacing.xs,
        ),
      ),
    );
  }
}

/// Chromatic chrome colours used outside the Material roles.
@immutable
class _Chrome {
  const _Chrome({
    required this.scaffold,
    required this.appBar,
    required this.inputFill,
    required this.sliderAccent,
  });

  final Color scaffold;
  final Color appBar;
  final Color inputFill;
  final Color sliderAccent;
}

/// Persisted appearance modes the theme system resolves.
enum AppThemeMode {
  /// Current Raw Luxury Monochromatic look.
  dark('MUSIC OASIS DARK'),

  /// Pure black backgrounds, dimmed chrome.
  amoled('AMOLED BLACK'),

  /// Warm paper per DESIGN.md.
  light('LIGHT');

  const AppThemeMode(this.label);

  /// Menu label shown in Settings.
  final String label;

  /// Resolves the matching [ThemeData].
  ThemeData get theme => MusicOasisTheme.themeFor(this);

  static const String prefsKey = 'music_oasis_theme_mode';

  static AppThemeMode fromName(String? name) => AppThemeMode.values.firstWhere(
        (AppThemeMode mode) => mode.name == name,
        orElse: () => AppThemeMode.dark,
      );
}
