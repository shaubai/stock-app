import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'storage_service.dart';

/// Mobile implementation of StorageService using SQLite (sqflite)
///
/// This implementation is used for iOS and Android platforms.
/// Data is stored in a local SQLite database.
class StorageServiceMobile implements StorageService {
  Database? _database;
  static const String _tableName = 'watchlist';
  static const String _columnSymbol = 'symbol';
  static const String _columnAddedAt = 'added_at';

  @override
  Future<void> init() async {
    if (_database != null) return;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'stock_app.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            $_columnSymbol TEXT PRIMARY KEY,
            $_columnAddedAt INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Database get _db {
    if (_database == null) {
      throw StateError('StorageService not initialized. Call init() first.');
    }
    return _database!;
  }

  @override
  Future<void> saveWatchlist(List<String> symbols) async {
    await clearWatchlist();
    final batch = _db.batch();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (final symbol in symbols) {
      batch.insert(
        _tableName,
        {
          _columnSymbol: symbol,
          _columnAddedAt: timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  @override
  Future<List<String>> loadWatchlist() async {
    final List<Map<String, dynamic>> maps = await _db.query(
      _tableName,
      columns: [_columnSymbol],
      orderBy: '$_columnAddedAt DESC',
    );

    return maps.map((map) => map[_columnSymbol] as String).toList();
  }

  @override
  Future<bool> addToWatchlist(String symbol) async {
    final exists = await isInWatchlist(symbol);
    if (exists) return false;

    try {
      await _db.insert(
        _tableName,
        {
          _columnSymbol: symbol,
          _columnAddedAt: DateTime.now().millisecondsSinceEpoch,
        },
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> removeFromWatchlist(String symbol) async {
    final count = await _db.delete(
      _tableName,
      where: '$_columnSymbol = ?',
      whereArgs: [symbol],
    );
    return count > 0;
  }

  @override
  Future<bool> isInWatchlist(String symbol) async {
    final List<Map<String, dynamic>> maps = await _db.query(
      _tableName,
      columns: [_columnSymbol],
      where: '$_columnSymbol = ?',
      whereArgs: [symbol],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  @override
  Future<void> clearWatchlist() async {
    await _db.delete(_tableName);
  }

  @override
  Future<int> getWatchlistCount() async {
    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    );
    return count ?? 0;
  }

  /// Close the database connection
  /// Should be called when the app is closing
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
