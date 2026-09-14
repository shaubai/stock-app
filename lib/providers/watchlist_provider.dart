import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../services/storage_service_factory.dart';

/// Provider for managing watchlist state
///
/// This provider handles adding/removing stocks from the watchlist
/// and persisting the data across app sessions using StorageService.
class WatchlistProvider with ChangeNotifier {
  final StorageService _storageService = createStorageService();
  final Set<String> _watchlistSymbols = {};
  bool _isInitialized = false;
  bool _isLoading = false;

  /// Get a copy of the watchlist symbols
  List<String> get watchlistSymbols => _watchlistSymbols.toList();

  /// Check if watchlist is initialized
  bool get isInitialized => _isInitialized;

  /// Check if data is loading
  bool get isLoading => _isLoading;

  /// Get the number of symbols in watchlist
  int get count => _watchlistSymbols.length;

  /// Initialize the provider and load saved watchlist
  Future<void> init() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _storageService.init();
      final symbols = await _storageService.loadWatchlist();
      _watchlistSymbols.addAll(symbols);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing WatchlistProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if a symbol is in the watchlist
  bool isInWatchlist(String symbol) {
    return _watchlistSymbols.contains(symbol);
  }

  /// Add a symbol to the watchlist
  ///
  /// Returns true if added successfully, false if already exists
  Future<bool> addToWatchlist(String symbol) async {
    if (_watchlistSymbols.contains(symbol)) {
      return false;
    }

    _watchlistSymbols.add(symbol);
    notifyListeners();

    try {
      await _storageService.addToWatchlist(symbol);
      return true;
    } catch (e) {
      debugPrint('Error adding to watchlist: $e');
      // Revert on error
      _watchlistSymbols.remove(symbol);
      notifyListeners();
      return false;
    }
  }

  /// Remove a symbol from the watchlist
  ///
  /// Returns true if removed successfully, false if not found
  Future<bool> removeFromWatchlist(String symbol) async {
    if (!_watchlistSymbols.contains(symbol)) {
      return false;
    }

    _watchlistSymbols.remove(symbol);
    notifyListeners();

    try {
      await _storageService.removeFromWatchlist(symbol);
      return true;
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
      // Revert on error
      _watchlistSymbols.add(symbol);
      notifyListeners();
      return false;
    }
  }

  /// Toggle a symbol in the watchlist
  ///
  /// Adds if not present, removes if present
  /// Returns true if added, false if removed
  Future<bool> toggleWatchlist(String symbol) async {
    if (isInWatchlist(symbol)) {
      await removeFromWatchlist(symbol);
      return false;
    } else {
      await addToWatchlist(symbol);
      return true;
    }
  }

  /// Clear all symbols from the watchlist
  Future<void> clearWatchlist() async {
    _watchlistSymbols.clear();
    notifyListeners();

    try {
      await _storageService.clearWatchlist();
    } catch (e) {
      debugPrint('Error clearing watchlist: $e');
    }
  }

  /// Reload watchlist from storage
  Future<void> reload() async {
    _isLoading = true;
    notifyListeners();

    try {
      final symbols = await _storageService.loadWatchlist();
      _watchlistSymbols.clear();
      _watchlistSymbols.addAll(symbols);
    } catch (e) {
      debugPrint('Error reloading watchlist: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
