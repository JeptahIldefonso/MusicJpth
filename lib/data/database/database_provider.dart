import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' show Database;

import 'database.dart';

/// The application's single [AppDatabase]. Closed with the provider scope.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((
  Ref ref,
) {
  final AppDatabase database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// The opened connection.
///
/// A [FutureProvider] so the first frame renders while the file opens, per
/// `PROJECT.md` §17/§27 — nothing waits synchronously on startup. Repositories
/// depend on this; widgets never do.
final FutureProvider<Database> databaseProvider = FutureProvider<Database>(
  (Ref ref) => ref.watch(appDatabaseProvider).open(),
);
