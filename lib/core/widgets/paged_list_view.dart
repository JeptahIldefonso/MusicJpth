import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Lazily built list that pages on demand.
///
/// Reusable pagination chrome: the caller provides rows and the page state
/// (`hadMore`, `loading`, `error`), and the widget appends the appropriate
/// footer — a spinner while a page is in flight, an error row with retry when
/// the last fetch failed — and asks for the next page as the end approaches.
///
/// Row assembly stays with the caller via [itemBuilder], so the same paging
/// behaviour serves song lists, history, or any future feed without each
/// screen hand-rolling a scroll listener.
class PagedListView extends StatelessWidget {
  const PagedListView({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
    this.onReachEnd,
    this.hadMore = false,
    this.loading = false,
    this.error,
    this.onRetry,
    this.prefetchAhead = 10,
  });

  /// Number of data rows — the footer rows are appended automatically.
  final int itemCount;

  /// Builds one data row.
  final IndexedWidgetBuilder itemBuilder;

  /// Called once the last [prefetchAhead] rows become visible, so the next
  /// page has already arrived by the time the user scrolls there. Callers
  /// should make this idempotent — it can fire repeatedly for the same page.
  final VoidCallback? onReachEnd;

  /// Whether the caller can produce another page.
  final bool hadMore;

  /// A page fetch is in flight: the footer becomes a spinner.
  final bool loading;

  /// Last fetch failed: the footer becomes an error row with [onRetry].
  final String? error;

  /// Re-fetches after an error.
  final VoidCallback? onRetry;

  /// How many rows before the end trigger [onReachEnd].
  final int prefetchAhead;

  @override
  Widget build(BuildContext context) {
    final bool showError = error != null && !loading && itemCount > 0;
    final bool showSpinner = loading && itemCount > 0;
    final int footerRows = (showError || showSpinner) ? 1 : 0;

    return ListView.builder(
      itemCount: itemCount + footerRows,
      itemBuilder: (BuildContext context, int index) {
        if (index >= itemCount) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: MusicOasisSpacing.md),
            child: showError
                ? _ErrorFooter(message: error!, onRetry: onRetry)
                : const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
          );
        }

        if (index >= itemCount - prefetchAhead) {
          final VoidCallback? reachEnd = onReachEnd;
          if (reachEnd != null) scheduleMicrotask(reachEnd);
        }
        return itemBuilder(context, index);
      },
    );
  }
}

class _ErrorFooter extends StatelessWidget {
  const _ErrorFooter({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.error,
          ),
        ),
        if (onRetry != null) ...<Widget>[
          const SizedBox(height: MusicOasisSpacing.xs),
          TextButton(
            key: const ValueKey<String>('paged-retry'),
            onPressed: onRetry,
            child: const Text('RETRY'),
          ),
        ],
      ],
    );
  }
}
