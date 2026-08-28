import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/services/permissions/media_permission_service.dart';

void main() {
  group('MediaPermissionService', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test(
      'grants immediately on Windows, without touching the plugin',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;

        expect(
          await const MediaPermissionService().ensureAudioAccess(),
          MediaAccess.granted,
        );
      },
    );

    test('grants immediately on the other desktop targets', () async {
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          await const MediaPermissionService().ensureAudioAccess(),
          MediaAccess.granted,
          reason: platform.name,
        );
      }
    });

    test(
      'grants immediately on iOS, where the picker carries the grant',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        expect(
          await const MediaPermissionService().ensureAudioAccess(),
          MediaAccess.granted,
        );
      },
    );

    test('implements the gate the scanner depends on', () {
      expect(const MediaPermissionService(), isA<MediaPermissionGate>());
    });
  });
}
