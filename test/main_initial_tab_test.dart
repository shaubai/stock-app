import 'package:flutter_test/flutter_test.dart';
import 'package:stock_app/main.dart';

/// Unit tests for resolveInitialTabIndex — the logic behind "open the app
/// straight into the watchlist tab if the user has any watched stocks,
/// otherwise the stock board tab (index 0)".
///
/// This is tested as a standalone pure function rather than through
/// MainScreen because MainScreen's tabs (StockListScreen/WatchlistScreen)
/// construct their own StockService internally and issue real network
/// requests from initState — there's no seam to inject a fake for a widget
/// test, and resolveInitialTabIndex captures 100% of the actual decision
/// logic anyway (see its doc comment in lib/main.dart).
void main() {
  group('resolveInitialTabIndex', () {
    test('returns null (no decision yet) while watchlist is not initialized', () {
      final result = resolveInitialTabIndex(
        hasSetInitialTab: false,
        isInitialized: false,
        watchlistCount: 0,
      );

      expect(result, isNull,
          reason: 'WatchlistProvider.init() is async; MainScreen must not guess before it resolves');
    });

    test('resolves to the watchlist tab (1) once initialized with a non-empty watchlist', () {
      final result = resolveInitialTabIndex(
        hasSetInitialTab: false,
        isInitialized: true,
        watchlistCount: 3,
      );

      expect(result, 1);
    });

    test('resolves to the stock board tab (0) once initialized with an empty watchlist', () {
      final result = resolveInitialTabIndex(
        hasSetInitialTab: false,
        isInitialized: true,
        watchlistCount: 0,
      );

      expect(result, 0,
          reason: 'a new/empty-watchlist user should land on the stock board, not a blank watchlist page');
    });

    test('returns null once a decision has already been made, regardless of count', () {
      final result = resolveInitialTabIndex(
        hasSetInitialTab: true,
        isInitialized: true,
        watchlistCount: 5,
      );

      expect(result, isNull,
          reason: 'the initial-tab decision must fire exactly once per app session, '
              'so later watchlist changes (or manual tab switches) are never overridden');
    });
  });
}
