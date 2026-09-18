import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

/// Provider for managing watchlist state
///
/// This provider handles adding/removing stocks from the watchlist
/// and persisting the data across app sessions using StorageService.
class WatchlistProvider with ChangeNotifier {
  StorageService _storageService;
  // Ordered list, not a Set: user-defined sort order must be preserved.
  final List<String> _watchlistSymbols = [];
  bool _isInitialized = false;
  bool _isLoading = false;

  WatchlistProvider(this._storageService);

  /// Get a copy of the watchlist symbols, in user-defined sort order
  List<String> get watchlistSymbols => List.unmodifiable(_watchlistSymbols);

  /// Check if watchlist is initialized
  bool get isInitialized => _isInitialized;

  /// Check if data is loading
  bool get isLoading => _isLoading;

  /// Get the number of symbols in watchlist
  int get count => _watchlistSymbols.length;

  /// Update storage service (e.g., when user logs in/out)
  void updateStorageService(StorageService newService) {
    _storageService = newService;
    _isInitialized = false;
    _watchlistSymbols.clear();
    notifyListeners();
  }

  /// Initialize the provider and load saved watchlist
  Future<void> init() async {
    if (_isInitialized) return;

    // Guarantees a real async boundary before the first notifyListeners().
    // Without this, a caller that invokes init() synchronously from
    // initState() (as AuthWrapper does — see main.dart) could have this
    // notifyListeners() fire while Flutter is still in the middle of the
    // current build phase, which throws ("setState() or markNeedsBuild()
    // called during build"). On a real device this was masked by
    // StorageService's own I/O (a real platform channel call) guaranteeing
    // that gap; it surfaced only under sqflite_common_ffi in tests, where
    // storage calls can resolve fast enough to stay within the same
    // microtask/build phase. See test/widget_test.dart.
    await Future.microtask(() {});

    _isLoading = true;
    notifyListeners();

    try {
      await _storageService.init();
      final symbols = await _storageService.loadWatchlist();
      _watchlistSymbols.clear();
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

  /// Reorder the watchlist (e.g. after a drag-and-drop in the UI)
  ///
  /// [oldIndex] and [newIndex] follow Flutter's ReorderableListView /
  /// ReorderableGridView convention: newIndex is the index in the list
  /// *before* the item at oldIndex is removed.
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final previousOrder = List<String>.from(_watchlistSymbols);

    final symbol = _watchlistSymbols.removeAt(oldIndex);
    _watchlistSymbols.insert(newIndex, symbol);
    notifyListeners();

    try {
      await _storageService.saveOrder(_watchlistSymbols);
    } catch (e) {
      debugPrint('Error saving watchlist order: $e');
      // Revert on error
      _watchlistSymbols
        ..clear()
        ..addAll(previousOrder);
      notifyListeners();
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
