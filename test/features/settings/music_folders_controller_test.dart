import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/data/database/database.dart';
import 'package:music_oasis/data/database/database_provider.dart';
import 'package:music_oasis/data/models/music_folder.dart';
import 'package:music_oasis/features/settings/music_folders_controller.dart';
import 'package:music_oasis/services/permissions/storage_access_service.dart';
import 'package:music_oasis/services/scanner/folder_picker_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Returns queued paths in order; `null` stands for a cancelled picker.
class _FakePicker {
  _FakePicker(this._paths);

  final List<String?> _paths;
  int calls = 0;

  Future<String?> pick({String? dialogTitle}) async {
    calls++;
    return _paths.isEmpty ? null : _paths.removeAt(0);
  }
}

class _FakeAccess implements StorageAccessService {
  const _FakeAccess(this.result);

  final FolderAccess result;

  @override
  Future<FolderAccess> check(String path) async => result;
}

ProviderContainer _container({
  required _FakePicker picker,
  FolderAccess access = FolderAccess.readable,
}) {
  final AppDatabase database = AppDatabase(
    factoryOverride: databaseFactoryFfi,
    pathResolverOverride: () async => inMemoryDatabasePath,
  );
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      appDatabaseProvider.overrideWithValue(database),
      folderPickerServiceProvider.overrideWithValue(
        FolderPickerService(pickerOverride: picker.pick),
      ),
      storageAccessServiceProvider.overrideWithValue(_FakeAccess(access)),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(database.close);
  return container;
}

Future<List<MusicFolder>> _folders(ProviderContainer container) =>
    container.read(musicFoldersProvider.future);

void main() {
  setUpAll(sqfliteFfiInit);

  group('MusicFoldersController', () {
    test('starts with no folders', () async {
      final ProviderContainer container = _container(
        picker: _FakePicker(<String?>[]),
      );

      expect(await _folders(container), isEmpty);
    });

    test('adds the picked folder and republishes the list', () async {
      final ProviderContainer container = _container(
        picker: _FakePicker(<String?>['/music']),
      );
      await _folders(container);

      final AddFolderOutcome outcome = await container
          .read(musicFoldersProvider.notifier)
          .addFolder();

      expect(outcome, AddFolderOutcome.added);
      final List<MusicFolder> folders = container
          .read(musicFoldersProvider)
          .requireValue;
      expect(folders, hasLength(1));
      expect(p.equals(folders.single.path, '/music'), isTrue);
    });

    test('a cancelled picker changes nothing', () async {
      final _FakePicker picker = _FakePicker(<String?>[null]);
      final ProviderContainer container = _container(picker: picker);
      await _folders(container);

      final AddFolderOutcome outcome = await container
          .read(musicFoldersProvider.notifier)
          .addFolder();

      expect(outcome, AddFolderOutcome.cancelled);
      expect(picker.calls, 1);
      expect(container.read(musicFoldersProvider).requireValue, isEmpty);
    });

    test('reports a duplicate without adding a second row', () async {
      final ProviderContainer container = _container(
        picker: _FakePicker(<String?>['/music', '/music/rock']),
      );
      await _folders(container);
      final MusicFoldersController controller = container.read(
        musicFoldersProvider.notifier,
      );

      expect(await controller.addFolder(), AddFolderOutcome.added);
      expect(await controller.addFolder(), AddFolderOutcome.duplicate);
      expect(container.read(musicFoldersProvider).requireValue, hasLength(1));
    });

    test('reports an unreadable folder and stores nothing', () async {
      final ProviderContainer container = _container(
        picker: _FakePicker(<String?>['/music']),
        access: FolderAccess.denied,
      );
      await _folders(container);

      final AddFolderOutcome outcome = await container
          .read(musicFoldersProvider.notifier)
          .addFolder();

      expect(outcome, AddFolderOutcome.denied);
      expect(container.read(musicFoldersProvider).requireValue, isEmpty);
    });

    test('reports a folder that no longer exists', () async {
      final ProviderContainer container = _container(
        picker: _FakePicker(<String?>['/gone']),
        access: FolderAccess.missing,
      );
      await _folders(container);

      expect(
        await container.read(musicFoldersProvider.notifier).addFolder(),
        AddFolderOutcome.missing,
      );
      expect(container.read(musicFoldersProvider).requireValue, isEmpty);
    });

    test('removes a folder', () async {
      final ProviderContainer container = _container(
        picker: _FakePicker(<String?>['/music']),
      );
      await _folders(container);
      final MusicFoldersController controller = container.read(
        musicFoldersProvider.notifier,
      );
      await controller.addFolder();
      final MusicFolder added = container
          .read(musicFoldersProvider)
          .requireValue
          .single;

      await controller.removeFolder(added.id);

      expect(container.read(musicFoldersProvider).requireValue, isEmpty);
    });
  });
}
