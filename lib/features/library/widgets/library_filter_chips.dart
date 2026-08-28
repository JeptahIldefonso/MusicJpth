import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Horizontally scrollable pill chips for switching between library views.
///
/// Reusable presentation: the caller owns the tab [T] and its selection
/// state, so the same strip can drive the LIBRARY tabs, a browse filter, or
/// any other single-select category row without duplicating layout or styling.
class LibraryFilterChips<T> extends StatelessWidget {
  const LibraryFilterChips({
    required this.tabs,
    required this.selected,
    required this.onSelected,
    required this.labelOf,
    super.key,
  });

  /// Available categories, in display order.
  final List<T> tabs;

  /// The currently selected category — the caller's state, kept here.
  final T selected;

  final ValueChanged<T> onSelected;

  /// Display label for a category, e.g. 'SONGS'.
  final String Function(T tab) labelOf;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: MusicOasisSpacing.lg),
        itemCount: tabs.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: MusicOasisSpacing.sm),
        itemBuilder: (BuildContext context, int index) {
          final T tab = tabs[index];
          return _Chip(
            label: labelOf(tab),
            selected: tab == selected,
            onTap: () => onSelected(tab),
          );
        },
      ),
    );
  }
}

/// One pill: selected is a high-contrast white chip with black ink, the rest
/// recede into the dark grey of the page.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.onSurface : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MusicOasisSpacing.md,
            vertical: MusicOasisSpacing.sm,
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}