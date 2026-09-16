import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

/// Web implementation of StorageService using localStorage (shared_preferences)
///
/// This implementation is used for Web platform.
/// Data is stored in browser's localStorage as a JSON string.
class StorageServiceWeb implements StorageService {
  SharedPreferences? _prefs;
  static const String _watchlistKey = 'watchlist';

  @override
  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw StateError('StorageService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  @override
  Future<void> saveWatchlist(List<String> symbols) async {
    await _preferences.setStringList(_watchlistKey, symbols);
  }

  @override
  Future<List<String>> loadWatchlist() async {
    return _preferences.getStringList(_watchlistKey) ?? [];
  }

  @override
  Future<void> saveOrder(List<String> orderedSymbols) async {
    await saveWatchlist(orderedSymbols);
  }

  @override
  Future<bool> addToWatchlist(String symbol) async {
    final watchlist = await loadWatchlist();

    if (watchlist.contains(symbol)) {
      return false; // Already exists
    }

    watchlist.add(symbol);
    await saveWatchlist(watchlist);
    return true;
  }

  @override
  Future<bool> removeFromWatchlist(String symbol) async {
    final watchlist = await loadWatchlist();

    final removed = watchlist.remove(symbol);
    if (removed) {
      await saveWatchlist(watchlist);
    }

    return removed;
  }

  @override
  Future<bool> isInWatchlist(String symbol) async {
    final watchlist = await loadWatchlist();
    return watchlist.contains(symbol);
  }

  @override
  Future<void> clearWatchlist() async {
    await _preferences.remove(_watchlistKey);
  }

  @override
  Future<int> getWatchlistCount() async {
    final watchlist = await loadWatchlist();
    return watchlist.length;
  }
}
