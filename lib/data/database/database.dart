import 'package:sqflite/sqflite.dart';

import 'database_platform.dart';
import 'migrations/migrations.dart';

/// Resolves where the database file lives. Overridden in tests.
typedef DatabasePathResolver = Future<String> Function();

/// The single managed SQLite connection for the whole application.
///
/// Owns opening, schema creation and migration; owns no queries. Repositories
/// (`data/repositories/`) call [open] and issue their own statements, so this
/// class never grows into a god object.
///
/// Opening is asynchronous and happens off the UI's critical path: the caller
/// awaits [open] once, and concurrent callers share that single in-flight
/// future rather than opening the file repeatedly.
class AppDatabase {
  /// The overrides exist for tests; production passes neither and gets the
  /// platform factory plus the application support directory.
  AppDatabase({
    DatabaseFactory? factoryOverride,
    DatabasePathResolver? pathResolverOverride,
  }) : _factory = factoryOverride,
       _pathResolver = pathResolverOverride;

  final DatabaseFactory? _factory;
  final DatabasePathResolver? _pathResolver;

  Database? _database;
  Future<Database>? _opening;

  /// The open connection, or `null` before the first successful [open].
  Database? get databaseOrNull => _database;

  /// Opens the database, creating or migrating the schema as needed.
  ///
  /// Idempotent: repeated calls return the same [Database] instance.
  Future<Database> open() async {
    final Database? existing = _database;
    if (existing != null) return existing;

    final Future<Database> pending = _opening ??= _open();
    try {
      return await pending;
    } catch (_) {
      // A failed attempt must not be cached, or the app could never recover
      // from a transient failure (locked file, missing directory).
      if (identical(_opening, pending)) _opening = null;
      rethrow;
    }
  }

  /// Closes the connection. Safe to call when not open; [open] may follow.
  Future<void> close() async {
    final Database? database = _database;
    _database = null;
    _opening = null;
    await database?.close();
  }

  Future<Database> _open() async {
    final DatabaseFactory factory =
        _factory ?? DatabasePlatform.resolveFactory();
    final String path = await (_pathResolver ?? DatabasePlatform.resolvePath)();

    final Database database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    // Write-ahead logging: a long scan writing does not block the library
    // reading, and an interrupted write leaves the database consistent
    // (`REQUIREMENTS.md` §06, §43). Must run outside a transaction.
    await database.rawQuery('PRAGMA journal_mode = WAL');

    _database = database;
    return database;
  }

  /// Runs before every open, including upgrades.
  static Future<void> _onConfigure(Database db) async {
    // Off by default in SQLite; the schema's cascades depend on it.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Fresh install: apply every migration from zero.
  static Future<void> _onCreate(Database db, int version) =>
      _apply(db, from: 0, to: version);

  /// Existing install: apply only the migrations it has not seen.
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) =>
      _apply(db, from: oldVersion, to: newVersion);

  /// sqflite already wraps `onCreate`/`onUpgrade` in a transaction, so this
  /// batch either lands whole or not at all — an interrupted upgrade cannot
  /// leave a half-built schema.
  static Future<void> _apply(
    Database db, {
    required int from,
    required int to,
  }) async {
    final Batch batch = db.batch();
    for (final String statement in statementsBetween(from: from, to: to)) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }
}
