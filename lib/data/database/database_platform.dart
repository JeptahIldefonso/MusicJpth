import 'dart:io' show Directory;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart'
    show DatabaseFactory, databaseFactorySqflitePlugin;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;

import '../../core/platform/app_platform.dart';

/// Platform-specific database wiring, kept out of the UI and out of
/// [AppDatabase] itself so both stay testable.
abstract final class DatabasePlatform {
  const DatabasePlatform._();

  /// Database file name, inside the application support directory.
  static const String fileName = 'music.db';

  /// `sqflite` on Android/iOS (native), `sqflite_common_ffi` on desktop —
  /// Windows has no native sqflite implementation.
  ///
  /// The factory is named explicitly rather than read from sqflite's mutable
  /// `databaseFactory` global, which is only set by plugin registration.
  /// [sqfliteFfiInit] is idempotent, so no init latch is kept here.
  static DatabaseFactory resolveFactory() {
    if (!AppPlatform.isDesktop) return databaseFactorySqflitePlugin;
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }

  /// Application support directory, not documents: the library index is app
  /// data, not a user-facing file. The user's music is never stored here.
  static Future<String> resolvePath() async {
    final Directory directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return p.join(directory.path, fileName);
  }
}
