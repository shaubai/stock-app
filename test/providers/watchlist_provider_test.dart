import 'package:flutter_test/flutter_test.dart';
import 'package:stock_app/providers/watchlist_provider.dart';
import 'package:stock_app/services/storage_service.dart';

/// In-memory fake StorageService for testing WatchlistProvider without a
/// real sqflite/Firestore/SharedPreferences backend.
class FakeStorageService implements StorageService {
  List<String> symbols = [];
  bool throwOnNextWrite = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> saveWatchlist(List<String> newSymbols) async {
    if (throwOnNextWrite) {
      throwOnNextWrite = false;
      throw Exception('simulated storage failure');
    }
    symbols = List.from(newSymbols);
  }

  @override
  Future<List<String>> loadWatchlist() async => List.from(symbols);

  @override
  Future<void> saveOrder(List<String> orderedSymbols) async {
    if (throwOnNextWrite) {
      throwOnNextWrite = false;
      throw Exception('simulated storage failure');
    }
    symbols = List.from(orderedSymbols);
  }

  @override
  Future<bool> addToWatchlist(String symbol) async {
    if (throwOnNextWrite) {
      throwOnNextWrite = false;
      throw Exception('simulated storage failure');
    }
    if (symbols.contains(symbol)) return false;
    symbols.add(symbol);
    return true;
  }

  @override
  Future<bool> removeFromWatchlist(String symbol) async {
    if (throwOnNextWrite) {
      throwOnNextWrite = false;
      throw Exception('simulated storage failure');
    }
    return symbols.remove(symbol);
  }

  @override
  Future<bool> isInWatchlist(String symbol) async => symbols.contains(symbol);

  @override
  Future<void> clearWatchlist() async => symbols.clear();

  @override
  Future<int> getWatchlistCount() async => symbols.length;
}

void main() {
  late FakeStorageService storage;
  late WatchlistProvider provider;

  setUp(() {
    storage = FakeStorageService();
    provider = WatchlistProvider(storage);
  });

  group('init', () {
    test('loads existing symbols from storage in order', () async {
      storage.symbols = ['2330', '2317'];

      await provider.init();

      expect(provider.watchlistSymbols, ['2330', '2317']);
      expect(provider.isInitialized, isTrue);
      expect(provider.isLoading, isFalse);
    });

    test('is a no-op on second call (does not reload)', () async {
      storage.symbols = ['2330'];
      await provider.init();

      storage.symbols = ['2330', '2317']; // simulate storage changing externally
      await provider.init();

      expect(provider.watchlistSymbols, ['2330'],
          reason: 'second init() should be a no-op since _isInitialized is already true');
    });
  });

  group('addToWatchlist', () {
    test('adds a new symbol and persists it', () async {
      final added = await provider.addToWatchlist('2330');

      expect(added, isTrue);
      expect(provider.isInWatchlist('2330'), isTrue);
      expect(storage.symbols, ['2330']);
    });

    test('returns false and does not duplicate when already present', () async {
      await provider.addToWatchlist('2330');

      final added = await provider.addToWatchlist('2330');

      expect(added, isFalse);
      expect(provider.watchlistSymbols, ['2330']);
    });

    test('reverts optimistic update when storage write fails', () async {
      storage.throwOnNextWrite = true;

      final added = await provider.addToWatchlist('2330');

      expect(added, isFalse);
      expect(provider.isInWatchlist('2330'), isFalse,
          reason: 'in-memory state should roll back after the storage failure');
    });
  });

  group('removeFromWatchlist', () {
    test('removes an existing symbol', () async {
      await provider.addToWatchlist('2330');

      final removed = await provider.removeFromWatchlist('2330');

      expect(removed, isTrue);
      expect(provider.isInWatchlist('2330'), isFalse);
      expect(storage.symbols, isEmpty);
    });

    test('returns false when symbol is not present', () async {
      final removed = await provider.removeFromWatchlist('2330');

      expect(removed, isFalse);
    });

    test('reverts optimistic update when storage write fails', () async {
      await provider.addToWatchlist('2330');
      storage.throwOnNextWrite = true;

      final removed = await provider.removeFromWatchlist('2330');

      expect(removed, isFalse);
      expect(provider.isInWatchlist('2330'), isTrue,
          reason: 'symbol should still be present after failed removal');
    });
  });

  group('toggleWatchlist', () {
    test('adds when not present, returns true', () async {
      final result = await provider.toggleWatchlist('2330');

      expect(result, isTrue);
      expect(provider.isInWatchlist('2330'), isTrue);
    });

    test('removes when present, returns false', () async {
      await provider.addToWatchlist('2330');

      final result = await provider.toggleWatchlist('2330');

      expect(result, isFalse);
      expect(provider.isInWatchlist('2330'), isFalse);
    });
  });

  group('reorder', () {
    setUp(() async {
      await provider.addToWatchlist('2330');
      await provider.addToWatchlist('2317');
      await provider.addToWatchlist('2454');
    });

    test('moves an item and persists the new order', () async {
      // Drag first item (2330) to the end, ReorderableListView convention:
      // newIndex is the index before removal.
      await provider.reorder(0, 3);

      expect(provider.watchlistSymbols, ['2317', '2454', '2330']);
      expect(storage.symbols, ['2317', '2454', '2330']);
    });

    test('reverts to previous order when storage write fails', () async {
      storage.throwOnNextWrite = true;

      await provider.reorder(0, 3);

      expect(provider.watchlistSymbols, ['2330', '2317', '2454'],
          reason: 'order should roll back to what it was before the failed reorder');
    });
  });

  group('clearWatchlist', () {
    test('removes all symbols', () async {
      await provider.addToWatchlist('2330');
      await provider.addToWatchlist('2317');

      await provider.clearWatchlist();

      expect(provider.watchlistSymbols, isEmpty);
      expect(provider.count, 0);
    });
  });

  group('updateStorageService', () {
    test('resets state and requires re-init (e.g. on login/logout)', () async {
      await provider.addToWatchlist('2330');
      await provider.init();

      final newStorage = FakeStorageService()..symbols = ['AAPL'];
      provider.updateStorageService(newStorage);

      expect(provider.watchlistSymbols, isEmpty,
          reason: 'symbols should be cleared until init() is called again');
      expect(provider.isInitialized, isFalse);

      await provider.init();
      expect(provider.watchlistSymbols, ['AAPL']);
    });
  });

  group('notifyListeners', () {
    test('notifies on add, remove, and clear', () async {
      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.addToWatchlist('2330');
      await provider.removeFromWatchlist('2330');
      await provider.clearWatchlist();

      expect(notifyCount, greaterThanOrEqualTo(3));
    });
  });
}
