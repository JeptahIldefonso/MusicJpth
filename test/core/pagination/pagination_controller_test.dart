import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:music_oasis/core/errors/app_error.dart';
import 'package:music_oasis/core/pagination/pagination_controller.dart';

class TestController<T> extends PaginationController<T> {
  TestController(this._loader, {this.size = 3});
  final PageLoader<T> _loader;
  final int size;
  @override
  PageLoader<T> get loader => _loader;
  @override
  int get pageSize => size;
}

void main() {
  group('PaginationController', () {
    test('1. First page loads', () async {
      final container = ProviderContainer();
      final provider = NotifierProvider<TestController<String>, PaginationState<String>>(
        () => TestController<String>((offset, size) async => ['a', 'b', 'c']),
      );
      
      final controller = container.read(provider.notifier);
      await controller.loadInitial();
      
      final state = container.read(provider);
      expect(state.status, PaginationStatus.ready);
      expect(state.items, ['a', 'b', 'c']);
      expect(state.hasMore, true);
    });

    test('2. Second page appended', () async {
      final container = ProviderContainer();
      final provider = NotifierProvider<TestController<String>, PaginationState<String>>(
        () => TestController<String>((offset, size) async {
          if (offset == 0) return ['a', 'b', 'c'];
          return ['d', 'e', 'f'];
        }),
      );
      
      final controller = container.read(provider.notifier);
      await controller.loadInitial();
      await controller.loadMore();
      
      final state = container.read(provider);
      expect(state.items, ['a', 'b', 'c', 'd', 'e', 'f']);
      expect(state.hasMore, true);
    });

    test('3. Multiple pages accumulate', () async {
      final container = ProviderContainer();
      final provider = NotifierProvider<TestController<int>, PaginationState<int>>(
        () => TestController<int>((offset, size) async {
          return List.generate(size, (index) => offset + index);
        }, size: 2),
      );
      
      final controller = container.read(provider.notifier);
      await controller.loadInitial(); // 0, 1
      await controller.loadMore();    // 2, 3
      await controller.loadMore();    // 4, 5
      
      final state = container.read(provider);
      expect(state.items, [0, 1, 2, 3, 4, 5]);
    });

    test('4. hasMore=false on short page', () async {
      final container = ProviderContainer();
      final provider = NotifierProvider<TestController<String>, PaginationState<String>>(
        () => TestController<String>((offset, size) async => ['a', 'b']), // size is 3
      );
      
      final controller = container.read(provider.notifier);
      await controller.loadInitial();
      
      final state = container.read(provider);
      expect(state.items, ['a', 'b']);
      expect(state.hasMore, false);
    });

    test('5. Empty result', () async {
      final container = ProviderContainer();
      final provider = NotifierProvider<TestController<String>, PaginationState<String>>(
        () => TestController<String>((offset, size) async => []),
      );
      
      final controller = container.read(provider.notifier);
      await controller.loadInitial();
      
      final state = container.read(provider);
      expect(state.isEmpty, true);
      expect(state.hasMore, false);
    });

    test('6. Duplicate loadMore prevention', () async {
      final completer = Completer<List<String>>();
      final container = ProviderContainer();
      int callCount = 0;
      final provider = NotifierProvider<TestController<String>, PaginationState<String>>(
        () => TestController<String>((offset, size) async {
          callCount++;
          if (offset == 0) return ['a', 'b', 'c'];
          return completer.future;
        }),
      );
      
      final controller = container.read(provider.notifier);
      await controller.loadInitial(); // callCount = 1
      
      controller.loadMore(); // callCount = 2, blocked
      controller.loadMore(); // blocked
      controller.loadMore(); // blocked
      
      expect(callCount, 2);
      completer.complete(['d', 'e', 'f']);
      await Future.delayed(Duration.zero);
      
      final state = container.read(provider);
      expect(state.items, ['a', 'b', 'c', 'd', 'e', 'f']);
    });

    test('7. refresh resets', () async {
      final container = ProviderContainer();
      int callCount = 0;
      final provider = NotifierProvider<TestController<String>, PaginationState<String>>(
        () => TestController<String>((offset, size) async {
          callCount++;
          if (callCount == 1) return ['a', 'b', 'c'];
          if (callCount == 2) return ['d', 'e', 'f'];
          return ['x', 'y', 'z']; // refresh
        }),
      );
      
      final controller = container.read(provider.notifier);
      await controller.loadInitial();
      await controller.loadMore();
      await controller.refresh();
      
      final state = container.read(provider);
      expect(state.items, ['x', 'y', 'z']);
    });

    test('8. Works with different types (String, int)', () async {
      final container = ProviderContainer();
      final provider = NotifierProvider<TestController<double>, PaginationState<double>>(
        () => TestController<double>((offset, size) async => [1.1, 2.2]),
      );
      
      final controller = container.read(provider.notifier);
      await controller.loadInitial();
      
      final state = container.read(provider);
      expect(state.items, [1.1, 2.2]);
      expect(state.hasMore, false); // size is 3
    });

    test('9. PaginationState is independent of LibraryScreen (Failure propagation)', () async {
      final container = ProviderContainer();
      final provider = NotifierProvider<TestController<String>, PaginationState<String>>(
        () => TestController<String>((offset, size) async {
          throw Exception('Failed');
        }),
      );
      
      final controller = container.read(provider.notifier);
      await controller.loadInitial();
      
      final state = container.read(provider);
      expect(state.status, PaginationStatus.error);
      expect(state.failure, AppError.message(ErrorDomain.database));
    });

    test('10. loadInitial while loading is no-op', () async {
      final completer = Completer<List<String>>();
      final container = ProviderContainer();
      int callCount = 0;
      final provider = NotifierProvider<TestController<String>, PaginationState<String>>(
        () => TestController<String>((offset, size) async {
          callCount++;
          return completer.future;
        }),
      );
      
      final controller = container.read(provider.notifier);
      controller.loadInitial(); // Starts loading, callCount 1
      controller.loadInitial(); // Blocked
      
      expect(callCount, 1);
      completer.complete(['a', 'b', 'c']);
      await Future.delayed(Duration.zero);
      
      final state = container.read(provider);
      expect(state.items, ['a', 'b', 'c']);
    });
    
    test('11. copyWith and equality', () {
      final state1 = PaginationState<String>(
        status: PaginationStatus.ready,
        items: ['a'],
        hasMore: true,
        failure: null,
      );
      
      final state2 = state1.copyWith(hasMore: false);
      expect(state2.hasMore, false);
      expect(state2.items, ['a']);
      
      final state3 = PaginationState<String>(
        status: PaginationStatus.ready,
        items: ['a'],
        hasMore: true,
      );
      expect(state1, state3);
      expect(state1.hashCode, state3.hashCode);
    });
  });
}
