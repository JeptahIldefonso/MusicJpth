import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/app/theme.dart';
import 'package:music_oasis/features/library/widgets/paged_list_view.dart';

void main() {
  Widget host({
    required PagedListView list,
  }) => MaterialApp(
    theme: MusicOasisTheme.dark,
    home: Scaffold(body: list),
  );

  testWidgets('asks for the next page as the end scrolls into view', (
    tester,
  ) async {
    int reachEndCalls = 0;

    await tester.pumpWidget(
      host(
        list: PagedListView(
          itemCount: 40,
          itemBuilder: (BuildContext context, int index) =>
              ListTile(title: Text('Row $index')),
          onReachEnd: () => reachEndCalls++,
          hadMore: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(reachEndCalls, 0);
    await tester.drag(
      find.byType(ListView),
      const Offset(0, -4000),
    );
    await tester.pumpAndSettle();

    expect(reachEndCalls, greaterThan(0));
  });

  testWidgets('a page in flight appends a spinner footer', (tester) async {
    await tester.pumpWidget(
      host(
        list: PagedListView(
          itemCount: 20,
          itemBuilder: (BuildContext context, int index) =>
              ListTile(title: Text('Row $index')),
          loading: true,
          hadMore: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // pumpAndSettle would never settle while the spinner animates.
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed fetch shows an error footer with a working retry', (
    tester,
  ) async {
    int retries = 0;

    await tester.pumpWidget(
      host(
        list: PagedListView(
          itemCount: 20,
          itemBuilder: (BuildContext context, int index) =>
              ListTile(title: Text('Row $index')),
          hadMore: true,
          error: 'The library could not be loaded.',
          onRetry: () => retries++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    expect(find.text('The library could not be loaded.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey<String>('paged-retry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('paged-retry')));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('the end of the list has no footer at all', (tester) async {
    await tester.pumpWidget(
      host(
        list: PagedListView(
          itemCount: 20,
          itemBuilder: (BuildContext context, int index) =>
              ListTile(title: Text('Row $index')),
          hadMore: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}