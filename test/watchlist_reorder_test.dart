import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_app/models/stock.dart';
import 'package:stock_app/widgets/stock_tile.dart';

/// Verifies that ReorderableListView actually fires onReorder when a user
/// long-presses and drags a StockTile — this is the mechanism
/// WatchlistProvider.reorder() and StorageService.saveOrder() rely on to
/// ever be called from the UI. StockTile wraps a ListTile/InkWell plus a
/// favorite-icon GestureDetector, both of which compete for gestures with
/// ReorderableListView's long-press-drag recognizer, so this needs to be
/// checked against the real widget rather than a bare ListTile.
void main() {
  Stock makeStock(String symbol) => Stock(
        symbol: symbol,
        name: symbol,
        currentPrice: 100,
        changeAmount: 1,
        changePercent: 1,
        volume: 1000,
        high: 101,
        low: 99,
        open: 100,
        previousClose: 99,
        lastUpdate: DateTime.now(),
        market: 'TW',
      );

  testWidgets('long-press drag on ReorderableListView of StockTiles triggers onReorder',
      (tester) async {
    var symbols = ['2330', '2317', '2454'];
    int? capturedOldIndex;
    int? capturedNewIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReorderableListView.builder(
            itemCount: symbols.length,
            itemBuilder: (context, index) => Container(
              key: ValueKey(symbols[index]),
              child: StockTile(
                stock: makeStock(symbols[index]),
                isTablet: false,
                isFavorite: true,
                onTap: () {},
                onFavoriteTap: () {},
              ),
            ),
            onReorder: (oldIndex, newIndex) {
              capturedOldIndex = oldIndex;
              capturedNewIndex = newIndex;
            },
          ),
        ),
      ),
    );

    expect(find.text('2330'), findsWidgets);

    final firstItem = find.text('2330').first;
    final gesture = await tester.startGesture(tester.getCenter(firstItem));
    await tester.pump(const Duration(milliseconds: 500)); // trigger long-press
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      capturedOldIndex,
      isNotNull,
      reason:
          'onReorder was never called — StockTile\'s internal gestures (favorite '
          'icon, tap-to-open) are blocking the long-press-drag recognizer',
    );
    expect(capturedNewIndex, isNotNull);
  });
}
