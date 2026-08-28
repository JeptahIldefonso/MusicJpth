import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/data/database/database_platform.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi;

/// Runs [body] with the platform overridden, restoring it afterwards.
T _onPlatform<T>(TargetPlatform platform, T Function() body) {
  debugDefaultTargetPlatformOverride = platform;
  try {
    return body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  group('DatabasePlatform.resolveFactory', () {
    test('uses the FFI factory on Windows', () {
      expect(
        _onPlatform(TargetPlatform.windows, DatabasePlatform.resolveFactory),
        same(databaseFactoryFfi),
      );
    });

    test('uses the native sqflite factory on Android', () {
      expect(
        _onPlatform(TargetPlatform.android, DatabasePlatform.resolveFactory),
        same(sqflite.databaseFactorySqflitePlugin),
      );
    });
  });
}
