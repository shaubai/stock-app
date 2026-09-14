/// Abstract interface for local storage operations
///
/// This interface provides a platform-agnostic way to store and retrieve
/// watchlist data. Different platforms (Mobile, Web) will have different
/// implementations.
abstract class StorageService {
  /// Initialize the storage service
  /// Must be called before any other operations
  Future<void> init();

  /// Save the entire watchlist
  ///
  /// [symbols] List of stock symbols to save
  Future<void> saveWatchlist(List<String> symbols);

  /// Load the watchlist
  ///
  /// Returns list of stock symbols, empty list if none saved
  Future<List<String>> loadWatchlist();

  /// Add a symbol to the watchlist
  ///
  /// [symbol] Stock symbol to add (e.g., "2330.TW", "AAPL")
  /// Returns true if added successfully, false if already exists
  Future<bool> addToWatchlist(String symbol);

  /// Remove a symbol from the watchlist
  ///
  /// [symbol] Stock symbol to remove
  /// Returns true if removed successfully, false if not found
  Future<bool> removeFromWatchlist(String symbol);

  /// Check if a symbol is in the watchlist
  ///
  /// [symbol] Stock symbol to check
  Future<bool> isInWatchlist(String symbol);

  /// Clear all watchlist data
  Future<void> clearWatchlist();

  /// Get the number of symbols in the watchlist
  Future<int> getWatchlistCount();
}
