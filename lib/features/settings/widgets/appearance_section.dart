import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../theme_mode_controller.dart';

/// Appearance mode selection: Music Oasis Dark, AMOLED Black, Light.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeMode mode = ref.watch(themeModeProvider);
    final ThemeData theme = Theme.of(context);
    final MusicOasisTokens tokens = MusicOasisTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'APPEARANCE',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: MusicOasisSpacing.sm),
        Divider(color: tokens.hairline),
        for (final AppThemeMode candidate in AppThemeMode.values)
          _ModeTile(
            mode: candidate,
            selected: candidate == mode,
            onTap: () {
              ref.read(themeModeProvider.notifier).set(candidate);
            },
          ),
        Divider(color: tokens.hairline),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      key: ValueKey<String>('theme-mode-${mode.name}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MusicOasisSpacing.xs,
          vertical: MusicOasisSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                mode.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check,
                size: 18,
                color: theme.colorScheme.onSurface,
              ),
          ],
        ),
      ),
    );
  }
}