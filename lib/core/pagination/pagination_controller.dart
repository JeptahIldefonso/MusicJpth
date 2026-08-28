// lib/core/pagination/pagination_controller.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_error.dart';

/// Loads one page of results.
///
/// [offset] is the number of items already loaded (0-based).
/// [pageSize] is the maximum number of items to return.
/// Returns fewer than [pageSize] items to signal end-of-list.
typedef PageLoader<T> = Future<List<T>> Function(int offset, int pageSize);

enum PaginationStatus { initial, loading, ready, error }

/// Accumulated state for one paginated list.
@immutable
class PaginationState<T> {
  const PaginationState({
    this.status = PaginationStatus.initial,
    this.items = const [],
    this.hasMore = false,
    this.failure,
  });

  final PaginationStatus status;
  final List<T> items;
  final bool hasMore;
  final String? failure;

  bool get isEmpty => status == PaginationStatus.ready && items.isEmpty;
  bool get isLoading => status == PaginationStatus.loading;

  PaginationState<T> copyWith({
    PaginationStatus? status,
    List<T>? items,
    bool? hasMore,
    String? failure,
  }) {
    return PaginationState<T>(
      status: status ?? this.status,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      failure: failure ?? this.failure,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PaginationState<T> &&
      other.status == status &&
      other.items.length == items.length &&
      other.hasMore == hasMore &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(status, items.length, hasMore, failure);
}

/// Generic base class for any screen that needs offset-based pagination.
///
/// Subclass and implement [loader] and [pageSize]. Call [loadInitial] to
/// start, [loadMore] to fetch the next page, and [refresh] to restart.
///
/// Usage:
/// ```dart
/// class SongsController extends PaginationController<Song> {
///   @override
///   int get pageSize => 200;
///
///   @override
///   PageLoader<Song> get loader =>
///       (offset, size) => _repo.page(offset: offset, limit: size);
/// }
/// ```
abstract class PaginationController<T> extends Notifier<PaginationState<T>> {
  /// Returns the page-loading callback.
  PageLoader<T> get loader;

  /// Maximum items per page. Default: 200.
  int get pageSize => 200;

  @override
  PaginationState<T> build() => PaginationState<T>();

  /// Loads the first page, discarding existing items.
  Future<void> loadInitial() async {
    if (state.status == PaginationStatus.loading) return;
    state = PaginationState<T>(status: PaginationStatus.loading);
    await _fetch(reset: true);
  }

  /// Appends the next page. No-ops while a load is in flight or at end-of-list.
  Future<void> loadMore() async {
    final bool blocked =
        state.status != PaginationStatus.ready &&
        state.status != PaginationStatus.error;
    if (blocked || !state.hasMore) return;
    state = state.copyWith(status: PaginationStatus.loading, failure: null);
    await _fetch();
  }

  /// Resets to page 1 (same as [loadInitial]).
  Future<void> refresh() => loadInitial();

  Future<void> _fetch({bool reset = false}) async {
    final int offset = reset ? 0 : state.items.length;
    try {
      final List<T> page = await loader(offset, pageSize);
      final List<T> items =
          reset ? page : <T>[...state.items, ...page];
      state = PaginationState<T>(
        status: PaginationStatus.ready,
        items: items,
        hasMore: page.length == pageSize,
      );
    } catch (_) {
      state = state.copyWith(
        status: PaginationStatus.error,
        failure: AppError.message(ErrorDomain.database),
      );
    }
  }
}
