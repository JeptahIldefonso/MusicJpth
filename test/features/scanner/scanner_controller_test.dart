import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/core/errors/app_error.dart';
import 'package:music_oasis/data/database/database.dart';
import 'package:music_oasis/data/database/database_provider.dart';
import 'package:music_oasis/data/models/track_metadata.dart';
import 'package:music_oasis/data/repositories/music_folder_repository.dart';
import 'package:music_oasis/data/repositories/music_folder_repository_provider.dart';
import 'package:music_oasis/features/scanner/scanner_controller.dart';
import 'package:music_oasis/features/settings/music_folders_controller.dart'
    show storageAccessServiceProvider;
import 'package:music_oasis/services/metadata/metadata_service.dart';
import 'package:music_oasis/services/permissions/media_permission_service.dart';
import 'package:music_oasis/services/permissions/storage_access_service.dart';
import 'package:music_oasis/services/scanner/music_scanner_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeGate implements MediaPermissionGate {
  _FakeGate(this.access);

  final MediaAccess access;
  int settingsOpened = 0;

  @override
  Future<MediaAccess> ensureAudioAccess() async => access;

  @override
  Future<bool> openSystemSettings() async {
    settingsOpened++;
    return true;
  }
}

class _FakeAccess implements StorageAccessService {
  const _FakeAccess([this.result = FolderAccess.readable]);

  final FolderAccess result;

  @override
  Future<FolderAccess> check(String path) async => result;
}

/// A scanner whose stream the test drives by hand.
class _ManualScanner implements MusicScanner {
  final StreamController<ScanUpdate> controller =
      StreamController<ScanUpdate>();
  bool cancelled = false;

  @override
  Stream<ScanUpdate> scan() {
    controller.onCancel = () => cancelled = true;
    return controller.stream;
  }
}

File _write(Directory root, String relative, {int bytes = 3}) {
  final File file = File(p.join(root.path, relative));
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(List<int>.filled(bytes, 0));
  return file;
}

Directory _tempDir() {
  final Directory directory = Directory.systemTemp.createTempSync(
    'music_oasis_scan_controller',
  );
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return directory;
}

ProviderContainer _container({
  MediaPermissionGate? gate,
  FolderAccess access = FolderAccess.readable,
  MusicScanner? scanner,
  MetadataRunner? reader,
}) {
  final AppDatabase database = AppDatabase(
    factoryOverride: databaseFactoryFfi,
    pathResolverOverride: () async => inMemoryDatabasePath,
  );
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      appDatabaseProvider.overrideWithValue(database),
      mediaPermissionGateProvider.overrideWithValue(
        gate ?? _FakeGate(MediaAccess.granted),
      ),
      storageAccessServiceProvider.overrideWithValue(_FakeAccess(access)),
      // No isolate and no real encoded file: what the parser returns is the
      // metadata service's own test, not the controller's.
      metadataServiceProvider.overrideWithValue(
        MetadataService(runnerOverride: reader ?? _noTags),
      ),
      if (scanner != null)
        musicScannerServiceProvider.overrideWith((Ref ref) async => scanner),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(database.close);
  return container;
}

Future<List<TrackMetadata>> _noTags(List<String> paths) async =>
    paths.map(TrackMetadata.unknown).toList(growable: false);

Future<void> _watch(ProviderContainer container, String path) async {
  final MusicFolderRepository repository = await container.read(
    musicFolderRepositoryProvider.future,
  );
  await repository.add(path);
}

void main() {
  setUpAll(sqfliteFfiInit);

  group('ScannerController', () {
    test('starts idle without touching the database', () {
      final ProviderContainer container = _container();

      expect(container.read(scannerProvider), const ScannerState());
      expect(container.read(scannerProvider).status, ScanStatus.idle);
    });

    test('reports no folders as a blocked scan', () async {
      final ProviderContainer container = _container();

      await container.read(scannerProvider.notifier).scan();

      final ScannerState state = container.read(scannerProvider);
      expect(state.status, ScanStatus.error);
      expect(state.reason, ScanBlockReason.noFolders);
      expect(state.needsSystemSettings, isFalse);
    });

    test('reports a denied permission', () async {
      final ProviderContainer container = _container(
        gate: _FakeGate(MediaAccess.denied),
      );
      await _watch(container, _tempDir().path);

      await container.read(scannerProvider.notifier).scan();

      final ScannerState state = container.read(scannerProvider);
      expect(state.reason, ScanBlockReason.permissionDenied);
      expect(state.needsSystemSettings, isFalse);
    });

    test('flags a permanent denial as needing the settings screen', () async {
      final ProviderContainer container = _container(
        gate: _FakeGate(MediaAccess.permanentlyDenied),
      );
      await _watch(container, _tempDir().path);

      await container.read(scannerProvider.notifier).scan();

      expect(container.read(scannerProvider).needsSystemSettings, isTrue);
    });

    test('scans a real folder and publishes the totals', () async {
      final ProviderContainer container = _container();
      final Directory root = _tempDir();
      _write(root, 'a.mp3');
      _write(root, p.join('album', 'b.flac'));
      _write(root, 'cover.jpg');
      await _watch(container, root.path);

      await container.read(scannerProvider.notifier).scan();

      final ScannerState state = container.read(scannerProvider);
      expect(state.status, ScanStatus.completed);
      expect(state.found, 2);
      expect(state.added, 2);
      expect(state.missing, 0);
      expect(state.reason, isNull);
    });

    test('a second scan of the same folder adds nothing', () async {
      final ProviderContainer container = _container();
      final Directory root = _tempDir();
      _write(root, 'a.mp3');
      await _watch(container, root.path);
      await container.read(scannerProvider.notifier).scan();

      await container.read(scannerProvider.notifier).scan();

      final ScannerState state = container.read(scannerProvider);
      expect(state.status, ScanStatus.completed);
      expect(state.found, 1);
      expect(state.added, 0);
      expect(state.updated, 0);
      expect(state.missing, 0);
    });

    test('a file that disappeared is reported as missing', () async {
      final ProviderContainer container = _container();
      final Directory root = _tempDir();
      _write(root, 'a.mp3');
      final File gone = _write(root, 'b.mp3');
      await _watch(container, root.path);
      await container.read(scannerProvider.notifier).scan();

      gone.deleteSync();
      await container.read(scannerProvider.notifier).scan();

      expect(container.read(scannerProvider).missing, 1);
    });

    test('publishes progress while scanning', () async {
      final _ManualScanner scanner = _ManualScanner();
      final ProviderContainer container = _container(scanner: scanner);
      final List<ScannerState> seen = <ScannerState>[];
      container.listen(
        scannerProvider,
        (ScannerState? _, ScannerState next) => seen.add(next),
      );

      final Future<void> running = container
          .read(scannerProvider.notifier)
          .scan();
      await Future<void>.delayed(Duration.zero);
      scanner.controller.add(
        const ScanProgress(found: 2, added: 2, updated: 0),
      );
      await Future<void>.delayed(Duration.zero);

      expect(container.read(scannerProvider).isScanning, isTrue);
      expect(container.read(scannerProvider).found, 2);

      scanner.controller.add(
        const ScanFinished(found: 2, added: 2, updated: 0, missing: 0),
      );
      await scanner.controller.close();
      await running;

      expect(container.read(scannerProvider).status, ScanStatus.completed);
      expect(seen.map((ScannerState s) => s.status), <ScanStatus>[
        ScanStatus.scanning,
        ScanStatus.scanning,
        ScanStatus.completed,
      ]);
    });

    test('publishes the tagged count through to completion', () async {
      final _ManualScanner scanner = _ManualScanner();
      final ProviderContainer container = _container(scanner: scanner);

      final Future<void> running = container
          .read(scannerProvider.notifier)
          .scan();
      await Future<void>.delayed(Duration.zero);
      scanner.controller.add(
        const ScanProgress(found: 3, added: 3, updated: 0, tagged: 2),
      );
      await Future<void>.delayed(Duration.zero);

      expect(container.read(scannerProvider).tagged, 2);

      scanner.controller.add(
        const ScanFinished(
          found: 3,
          added: 3,
          updated: 0,
          missing: 0,
          tagged: 3,
        ),
      );
      await scanner.controller.close();
      await running;

      expect(container.read(scannerProvider).tagged, 3);
    });

    test('cancelling stops the scan and keeps the counts so far', () async {
      final _ManualScanner scanner = _ManualScanner();
      final ProviderContainer container = _container(scanner: scanner);

      final Future<void> running = container
          .read(scannerProvider.notifier)
          .scan();
      await Future<void>.delayed(Duration.zero);
      scanner.controller.add(
        const ScanProgress(found: 4, added: 3, updated: 1),
      );
      await Future<void>.delayed(Duration.zero);

      await container.read(scannerProvider.notifier).cancel();
      await running;

      final ScannerState state = container.read(scannerProvider);
      expect(scanner.cancelled, isTrue);
      expect(state.status, ScanStatus.cancelled);
      expect(state.found, 4);
      expect(state.added, 3);
      expect(state.updated, 1);
    });

    test('cancelling when nothing runs is a no-op', () async {
      final ProviderContainer container = _container();

      await container.read(scannerProvider.notifier).cancel();

      expect(container.read(scannerProvider).status, ScanStatus.idle);
    });

    test('a second scan while one runs is ignored', () async {
      final _ManualScanner scanner = _ManualScanner();
      final ProviderContainer container = _container(scanner: scanner);

      final Future<void> running = container
          .read(scannerProvider.notifier)
          .scan();
      await Future<void>.delayed(Duration.zero);
      await container.read(scannerProvider.notifier).scan();

      expect(container.read(scannerProvider).isScanning, isTrue);

      await scanner.controller.close();
      await running;
    });

    test('a failing scan is reported as an error, not a crash', () async {
      final _ManualScanner scanner = _ManualScanner();
      final ProviderContainer container = _container(scanner: scanner);

      final Future<void> running = container
          .read(scannerProvider.notifier)
          .scan();
      await Future<void>.delayed(Duration.zero);
      scanner.controller.addError(const FormatException('boom'));
      await running;

      final ScannerState state = container.read(scannerProvider);
      expect(state.status, ScanStatus.error);
      // Raw exception text must not reach state; only the safe copy does.
      expect(state.failure, AppError.message(ErrorDomain.filesystem));
      expect(state.failure, isNot(contains('boom')));
      expect(state.reason, isNull);
    });
  });

  group('ScannerState', () {
    test('is a value', () {
      expect(
        const ScannerState(status: ScanStatus.completed, found: 2),
        const ScannerState(status: ScanStatus.completed, found: 2),
      );
      expect(
        const ScannerState(found: 1).hashCode,
        const ScannerState(found: 1).hashCode,
      );
      expect(const ScannerState(found: 1), isNot(const ScannerState(found: 2)));
    });
  });
}
