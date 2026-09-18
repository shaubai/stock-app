import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock_app/services/storage_service_mobile.dart';

void main() {
  // Overriding the global sqflite databaseFactory with the FFI
  // implementation redirects StorageServiceMobile's own openDatabase()/
  // getDatabasesPath() calls to a real SQLite engine backed by a temp file —
  // no changes needed to production code, and this exercises init() and all
  // CRUD methods exactly as written, not a reimplementation of them.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('StorageServiceMobile', () {
    // StorageServiceMobile.init() hardcodes its database to a fixed file
    // (stock_app.db under the platform's databases directory), so every
    // instance in this test file shares the same on-disk SQLite file —
    // sqflite_common_ffi persists to a real file, it isn't an isolated
    // in-memory instance per test. Deleting that file before each test is
    // required for tests to be independent of each other and of run order
    // (verified: without this, half these tests failed depending on what
    // earlier tests had left behind).
    setUp(() async {
      final dir = await databaseFactory.getDatabasesPath();
      await databaseFactory.deleteDatabase('$dir/stock_app.db');
    });

    test('init creates the watchlist table and starts empty', () async {
      final storage = StorageServiceMobile();
      await storage.init();

      expect(await storage.loadWatchlist(), isEmpty);
      expect(await storage.getWatchlistCount(), 0);
    });

    test('add, save order, and load round-trip correctly', () async {
      final storage = StorageServiceMobile();
      await storage.init();

      await storage.addToWatchlist('2330');
      await storage.addToWatchlist('2317');
      await storage.addToWatchlist('2454');

      expect(await storage.loadWatchlist(), ['2330', '2317', '2454']);

      await storage.saveOrder(['2454', '2330', '2317']);
      expect(await storage.loadWatchlist(), ['2454', '2330', '2317']);
    });

    test('addToWatchlist is a no-op (returns false) for a symbol already present', () async {
      final storage = StorageServiceMobile();
      await storage.init();
      await storage.addToWatchlist('2330');

      final added = await storage.addToWatchlist('2330');

      expect(added, isFalse);
      expect(await storage.loadWatchlist(), ['2330']);
    });

    test('new symbols are appended after the current max sort order', () async {
      // Regression coverage for the `(maxOrder ?? -1) + 1` computation in
      // addToWatchlist: reorder first so sort_order values are no longer
      // aligned with insertion order, then verify a freshly-added symbol
      // lands at the end rather than at whatever the row count happens to be.
      final storage = StorageServiceMobile();
      await storage.init();
      await storage.addToWatchlist('2330');
      await storage.addToWatchlist('2317');
      await storage.saveOrder(['2317', '2330']);

      await storage.addToWatchlist('2454');

      expect(await storage.loadWatchlist(), ['2317', '2330', '2454']);
    });

    test('removeFromWatchlist removes the symbol and reports success', () async {
      final storage = StorageServiceMobile();
      await storage.init();
      await storage.addToWatchlist('2330');

      final removed = await storage.removeFromWatchlist('2330');

      expect(removed, isTrue);
      expect(await storage.loadWatchlist(), isEmpty);
    });

    test('removeFromWatchlist reports false for a symbol not present', () async {
      final storage = StorageServiceMobile();
      await storage.init();

      final removed = await storage.removeFromWatchlist('9999');

      expect(removed, isFalse);
    });

    test('isInWatchlist reflects current membership', () async {
      final storage = StorageServiceMobile();
      await storage.init();
      await storage.addToWatchlist('2330');

      expect(await storage.isInWatchlist('2330'), isTrue);
      expect(await storage.isInWatchlist('9999'), isFalse);
    });

    test('clearWatchlist removes all symbols', () async {
      final storage = StorageServiceMobile();
      await storage.init();
      await storage.addToWatchlist('2330');
      await storage.addToWatchlist('2317');

      await storage.clearWatchlist();

      expect(await storage.loadWatchlist(), isEmpty);
      expect(await storage.getWatchlistCount(), 0);
    });

    test('saveWatchlist replaces the entire list and preserves the given order', () async {
      final storage = StorageServiceMobile();
      await storage.init();
      await storage.addToWatchlist('9999'); // should be wiped by saveWatchlist

      await storage.saveWatchlist(['2330', '2317', '2454']);

      expect(await storage.loadWatchlist(), ['2330', '2317', '2454']);
    });

    test('init is idempotent: calling it twice does not recreate/reset the database', () async {
      final storage = StorageServiceMobile();
      await storage.init();
      await storage.addToWatchlist('2330');

      await storage.init(); // second call should be a no-op per the `if (_database != null) return;` guard

      expect(await storage.loadWatchlist(), ['2330']);
    });
  });

  group('watchlist v1 -> v2 schema migration', () {
    // Exercises StorageServiceMobile's real onCreate/onUpgrade callbacks
    // (not a reimplementation) by writing a pre-existing v1 database
    // directly via databaseFactory, then opening that same file through a
    // real StorageServiceMobile.init() — reproducing exactly what happens
    // when an existing installed app updates. This is possible because
    // StorageServiceMobile takes an injectable databaseFileName (default
    // 'stock_app.db'; production callers never override it) purely so
    // tests can point two instances at the same file within one process.
    late String dbFileName;
    late String dbPath;

    setUp(() async {
      dbFileName = 'migration_test_${DateTime.now().microsecondsSinceEpoch}.db';
      final dir = await databaseFactory.getDatabasesPath();
      dbPath = '$dir/$dbFileName';
    });

    tearDown(() async {
      await databaseFactory.deleteDatabase(dbPath);
    });

    test('backfills sort_order ranking rows by added_at DESC', () async {
      // Simulate a pre-existing v1 install: no sort_order column, rows
      // inserted deliberately out of chronological order to prove the
      // backfill sorts by added_at rather than by insertion/rowid order.
      //
      // version: 1 must be set explicitly here — opening without a version
      // leaves sqflite treating the file as version 0/unversioned, so
      // reopening it at version 2 runs onCreate (CREATE TABLE, which then
      // fails with "table already exists") instead of onUpgrade. Verified
      // by hitting exactly that failure while writing this test.
      final v1Db = await databaseFactory.openDatabase(dbPath, options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => db.execute('''
          CREATE TABLE watchlist(
            symbol TEXT PRIMARY KEY,
            added_at INTEGER NOT NULL
          )
        '''),
      ));
      await v1Db.insert('watchlist', {'symbol': '2317', 'added_at': 2000});
      await v1Db.insert('watchlist', {'symbol': '2330', 'added_at': 1000});
      await v1Db.insert('watchlist', {'symbol': '2454', 'added_at': 3000});
      await v1Db.close();

      // Real production code path: hardcoded to schema version 2, so
      // opening this v1 file triggers the real onUpgrade(db, 1, 2).
      final storage = StorageServiceMobile(databaseFileName: dbFileName);
      await storage.init();

      expect(await storage.loadWatchlist(), ['2454', '2317', '2330'],
          reason: 'backfilled sort_order must rank newest added_at first, '
              'matching the pre-migration (added_at DESC) display order '
              'those rows had — a regression here would silently reshuffle '
              'every existing user\'s watchlist on upgrade');
    });

    test('backfill on an empty v1 table produces no rows and does not throw', () async {
      final v1Db = await databaseFactory.openDatabase(dbPath, options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => db.execute('''
          CREATE TABLE watchlist(
            symbol TEXT PRIMARY KEY,
            added_at INTEGER NOT NULL
          )
        '''),
      ));
      await v1Db.close();

      final storage = StorageServiceMobile(databaseFileName: dbFileName);
      await storage.init(); // must not throw

      expect(await storage.loadWatchlist(), isEmpty);
    });
  });
}
