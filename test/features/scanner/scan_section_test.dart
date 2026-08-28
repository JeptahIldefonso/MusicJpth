import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/app/theme.dart';
import 'package:music_oasis/features/scanner/scanner_controller.dart';
import 'package:music_oasis/features/scanner/widgets/scan_section.dart';
import 'package:music_oasis/services/permissions/media_permission_service.dart';
import 'package:music_oasis/services/scanner/music_scanner_service.dart';

class _FakeGate implements MediaPermissionGate {
  int settingsOpened = 0;

  @override
  Future<MediaAccess> ensureAudioAccess() async => MediaAccess.granted;

  @override
  Future<bool> openSystemSettings() async {
    settingsOpened++;
    return true;
  }
}

/// Publishes whatever the test asks for; the real scan is covered elsewhere.
class _FakeController extends ScannerController {
  _FakeController(this.initial);

  final ScannerState initial;
  int scans = 0;
  int cancels = 0;

  @override
  ScannerState build() => initial;

  @override
  Future<void> scan() async => scans++;

  @override
  Future<void> cancel() async {
    cancels++;
    state = const ScannerState(status: ScanStatus.cancelled);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required ScannerState state,
  MediaPermissionGate? gate,
  _FakeController? controller,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        scannerProvider.overrideWith(
          () => controller ?? _FakeController(state),
        ),
        if (gate != null) mediaPermissionGateProvider.overrideWithValue(gate),
      ],
      child: MaterialApp(
        theme: MusicOasisTheme.dark,
        home: const Scaffold(body: ScanSection()),
      ),
    ),
  );
  // LinearProgressIndicator animates continuously; pumpAndSettle would
  // time out while scanning. Use pump() for scanning states.
  if (state.isScanning) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
}

Finder _byKey(String key) => find.byKey(ValueKey<String>(key));

String _statusText(WidgetTester tester) =>
    tester.widget<Text>(_byKey('scan-status')).data!;

Future<void> _withPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  group('ScanSection', () {
    testWidgets('offers a scan when idle', (WidgetTester tester) async {
      await _withPlatform(TargetPlatform.android, () async {
        await _pump(tester, state: const ScannerState());

        expect(find.text('SCAN LIBRARY'), findsOneWidget);
        expect(
          _statusText(tester),
          'READY TO SCAN — Music Jpth will ask to read your audio files.',
        );
        expect(_byKey('open-permission-settings'), findsNothing);
      });
    });

    testWidgets('does not mention an Android prompt on desktop', (
      WidgetTester tester,
    ) async {
      await _withPlatform(TargetPlatform.windows, () async {
        await _pump(tester, state: const ScannerState());

        expect(_statusText(tester), 'NOT SCANNED YET');
      });
    });

    testWidgets('starts a scan when tapped', (WidgetTester tester) async {
      final _FakeController controller = _FakeController(const ScannerState());
      await _pump(tester, state: const ScannerState(), controller: controller);

      await tester.tap(_byKey('scan-library'));
      await tester.pumpAndSettle();

      expect(controller.scans, 1);
    });

    testWidgets('shows grouped progress while scanning', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        state: const ScannerState(
          status: ScanStatus.scanning,
          found: 1284,
          added: 1284,
        ),
      );

      expect(_statusText(tester), 'SCANNING — 1,284 FILES FOUND');
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('SCAN LIBRARY'), findsNothing);
    });

    testWidgets('cancels a running scan when tapped', (
      WidgetTester tester,
    ) async {
      final _FakeController controller = _FakeController(
        const ScannerState(status: ScanStatus.scanning, found: 3),
      );
      await _pump(
        tester,
        state: const ScannerState(status: ScanStatus.scanning),
        controller: controller,
      );

      await tester.tap(_byKey('scan-library'));
      await tester.pumpAndSettle();

      expect(controller.cancels, 1);
      expect(controller.scans, 0);
    });

    testWidgets('summarises a finished scan', (WidgetTester tester) async {
      await _pump(
        tester,
        state: const ScannerState(
          status: ScanStatus.completed,
          found: 1284,
          added: 20,
          updated: 3,
          missing: 2,
        ),
      );

      expect(
        _statusText(tester),
        '1,284 SCANNED · 20 ADDED · 3 UPDATED · 2 MISSING',
      );
    });

    testWidgets('reports a cancelled scan', (WidgetTester tester) async {
      await _pump(
        tester,
        state: const ScannerState(status: ScanStatus.cancelled, found: 40),
      );

      expect(_statusText(tester), 'SCAN CANCELLED — 40 FILES FOUND');
      expect(find.text('SCAN LIBRARY'), findsOneWidget);
    });

    testWidgets('uses the setup microcopy when no folder is watched', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        state: const ScannerState(
          status: ScanStatus.error,
          reason: ScanBlockReason.noFolders,
        ),
      );

      expect(
        _statusText(tester),
        'MUSIC ACCESS REQUIRED — Choose a music folder to build your library.',
      );
      expect(_byKey('open-permission-settings'), findsNothing);
    });

    testWidgets('a runtime denial asks for the toggle, not settings', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        state: const ScannerState(
          status: ScanStatus.error,
          reason: ScanBlockReason.permissionDenied,
        ),
      );

      expect(
        _statusText(tester),
        'MUSIC ACCESS REQUIRED — Allow Music Jpth to read your audio files, '
        'then scan again.',
      );
      expect(_byKey('open-permission-settings'), findsNothing);
    });

    testWidgets('a permanent denial points at system settings', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        state: const ScannerState(
          status: ScanStatus.error,
          reason: ScanBlockReason.permissionPermanentlyDenied,
        ),
      );

      expect(
        _statusText(tester),
        'MUSIC ACCESS REQUIRED — Open system settings and allow audio access.',
      );
      expect(_byKey('open-permission-settings'), findsOneWidget);
    });

    testWidgets('offers the system settings only for a permanent denial', (
      WidgetTester tester,
    ) async {
      final _FakeGate gate = _FakeGate();
      await _pump(
        tester,
        state: const ScannerState(
          status: ScanStatus.error,
          reason: ScanBlockReason.permissionPermanentlyDenied,
        ),
        gate: gate,
      );

      expect(_byKey('open-permission-settings'), findsOneWidget);
      await tester.tap(_byKey('open-permission-settings'));
      await tester.pumpAndSettle();

      expect(gate.settingsOpened, 1);
    });

    testWidgets('reports unreadable folders with the folder microcopy', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        state: const ScannerState(
          status: ScanStatus.error,
          reason: ScanBlockReason.foldersUnreadable,
        ),
      );

      expect(
        _statusText(tester),
        'FOLDER UNAVAILABLE — This folder may have been moved or deleted.',
      );
    });

    testWidgets('reports a failure without technical detail', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        state: const ScannerState(
          status: ScanStatus.error,
          failure: 'FileDiscoveryException: boom',
        ),
      );

      expect(
        _statusText(tester),
        'SCAN UNAVAILABLE — Music Jpth could not finish scanning.',
      );
      expect(find.textContaining('boom'), findsNothing);
    });
  });
}
