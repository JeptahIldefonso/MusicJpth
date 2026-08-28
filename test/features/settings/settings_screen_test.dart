import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/app/theme.dart';
import 'package:music_oasis/data/models/music_folder.dart';
import 'package:music_oasis/features/settings/music_folders_controller.dart';
import 'package:music_oasis/features/settings/settings_screen.dart';

final MusicFolder _folder = MusicFolder(
  id: 1,
  path: r'C:\Music',
  dateAdded: DateTime.fromMillisecondsSinceEpoch(0),
);

/// Stands in for the real controller so the widget test stays about rendering:
/// the picker, the access probe and SQLite are covered by their own tests.
class _FakeController extends MusicFoldersController {
  _FakeController({
    required this.outcome,
    this.initial = const <MusicFolder>[],
  });

  final AddFolderOutcome outcome;
  final List<MusicFolder> initial;

  @override
  Future<List<MusicFolder>> build() async => initial;

  @override
  Future<AddFolderOutcome> addFolder() async {
    if (outcome == AddFolderOutcome.added) {
      state = AsyncValue<List<MusicFolder>>.data(<MusicFolder>[
        ...state.requireValue,
        _folder,
      ]);
    }
    return outcome;
  }

  @override
  Future<void> removeFolder(int id) async {
    state = AsyncValue<List<MusicFolder>>.data(
      state.requireValue
          .where((MusicFolder folder) => folder.id != id)
          .toList(growable: false),
    );
  }
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required AddFolderOutcome outcome,
  List<MusicFolder> initial = const <MusicFolder>[],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        musicFoldersProvider.overrideWith(
          () => _FakeController(outcome: outcome, initial: initial),
        ),
      ],
      child: MaterialApp(
        theme: MusicOasisTheme.dark,
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _byKey(String key) => find.byKey(ValueKey<String>(key));

void main() {
  group('SettingsScreen music folders', () {
    testWidgets('prompts for a folder when none are watched', (
      WidgetTester tester,
    ) async {
      await _pumpSettings(tester, outcome: AddFolderOutcome.cancelled);

      expect(_byKey('music-folders-empty'), findsOneWidget);
      expect(_byKey('add-folder'), findsOneWidget);
    });

    testWidgets('shows a picked folder as a row', (WidgetTester tester) async {
      await _pumpSettings(tester, outcome: AddFolderOutcome.added);

      await tester.tap(_byKey('add-folder'));
      await tester.pumpAndSettle();

      expect(_byKey('music-folder-1'), findsOneWidget);
      expect(find.text(r'C:\Music'), findsOneWidget);
      expect(_byKey('music-folders-empty'), findsNothing);
      expect(_byKey('music-folders-message'), findsNothing);
    });

    testWidgets('cancelling the picker says nothing and changes nothing', (
      WidgetTester tester,
    ) async {
      await _pumpSettings(tester, outcome: AddFolderOutcome.cancelled);

      await tester.tap(_byKey('add-folder'));
      await tester.pumpAndSettle();

      expect(_byKey('music-folders-empty'), findsOneWidget);
      expect(_byKey('music-folders-message'), findsNothing);
    });

    testWidgets('reports a duplicate pick', (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        outcome: AddFolderOutcome.duplicate,
        initial: <MusicFolder>[_folder],
      );

      await tester.tap(_byKey('add-folder'));
      await tester.pumpAndSettle();

      expect(_byKey('music-folders-message'), findsOneWidget);
      expect(_byKey('music-folder-1'), findsOneWidget);
    });

    testWidgets('reports an unreadable folder with the access microcopy', (
      WidgetTester tester,
    ) async {
      await _pumpSettings(tester, outcome: AddFolderOutcome.denied);

      await tester.tap(_byKey('add-folder'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'MUSIC ACCESS REQUIRED — Choose a music folder to build your '
          'library.',
        ),
        findsWidgets,
      );
    });

    testWidgets('removing the last folder restores the prompt', (
      WidgetTester tester,
    ) async {
      await _pumpSettings(
        tester,
        outcome: AddFolderOutcome.cancelled,
        initial: <MusicFolder>[_folder],
      );

      await tester.tap(_byKey('remove-folder-1'));
      await tester.pumpAndSettle();

      expect(_byKey('music-folders-empty'), findsOneWidget);
    });
  });
}
