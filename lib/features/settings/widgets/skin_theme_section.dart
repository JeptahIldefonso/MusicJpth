import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../gradient_theme_controller.dart';
import '../gradient_theme_model.dart';

class SkinThemeSection extends ConsumerWidget {
  const SkinThemeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gradientThemeProvider);
    final theme = Theme.of(context);
    final tokens = MusicOasisTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SKIN THEME',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: MusicOasisSpacing.sm),
        Divider(color: tokens.hairline),
        SwitchListTile(
          title: Text(
            'Enable Gradient Background',
            style: theme.textTheme.labelLarge,
          ),
          value: state.enabled,
          onChanged: (val) {
            ref.read(gradientThemeProvider.notifier).setEnabled(val);
          },
          contentPadding: const EdgeInsets.symmetric(
            horizontal: MusicOasisSpacing.xs,
          ),
        ),
        if (state.enabled) ...[
          const SizedBox(height: MusicOasisSpacing.sm),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: GradientThemePreset.values.length,
              itemBuilder: (context, index) {
                final preset = GradientThemePreset.values[index];
                if (preset == GradientThemePreset.none) return const SizedBox.shrink();

                final isSelected = state.preset == preset;
                return GestureDetector(
                  onTap: () {
                    ref.read(gradientThemeProvider.notifier).setPreset(preset);
                  },
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: MusicOasisSpacing.sm),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: preset.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: MusicOasisSpacing.md),
      ],
    );
  }
}
