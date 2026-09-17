import 'package:flutter_test/flutter_test.dart';
import 'package:stock_app/models/stock.dart';

void main() {
  group('Stock.fromJson', () {
    test('parses Yahoo Finance-style US stock fields', () {
      final stock = Stock.fromJson({
        'symbol': 'AAPL',
        'longName': 'Apple Inc.',
        'regularMarketPrice': 178.25,
        'regularMarketChange': 2.15,
        'regularMarketChangePercent': 1.22,
        'regularMarketVolume': 55000000,
        'regularMarketDayHigh': 179.50,
        'regularMarketDayLow': 176.80,
        'regularMarketOpen': 177.00,
        'regularMarketPreviousClose': 176.10,
      }, 'US');

      expect(stock.symbol, 'AAPL');
      expect(stock.name, 'Apple Inc.');
      expect(stock.currentPrice, 178.25);
      expect(stock.changeAmount, 2.15);
      expect(stock.changePercent, 1.22);
      expect(stock.volume, 55000000);
      expect(stock.high, 179.50);
      expect(stock.low, 176.80);
      expect(stock.open, 177.00);
      expect(stock.previousClose, 176.10);
      expect(stock.market, 'US');
    });

    test('falls back to alternate field names (name/price/change/...)', () {
      final stock = Stock.fromJson({
        'symbol': '2330',
        'name': '台積電',
        'price': 585.0,
        'change': 5.0,
        'changePercent': 0.86,
        'volume': 25000000,
        'high': 588.0,
        'low': 580.0,
        'open': 582.0,
        'previousClose': 580.0,
      }, 'TW');

      expect(stock.name, '台積電');
      expect(stock.currentPrice, 585.0);
      expect(stock.changeAmount, 5.0);
      expect(stock.market, 'TW');
    });

    test('defaults missing numeric fields to 0 and strings to empty', () {
      final stock = Stock.fromJson({}, 'TW');

      expect(stock.symbol, '');
      expect(stock.name, '');
      expect(stock.currentPrice, 0.0);
      expect(stock.changeAmount, 0.0);
      expect(stock.changePercent, 0.0);
      expect(stock.volume, 0);
      expect(stock.high, 0.0);
      expect(stock.low, 0.0);
      expect(stock.open, 0.0);
      expect(stock.previousClose, 0.0);
    });

    test('accepts int values for fields typed as double (JSON has no float/int distinction)', () {
      final stock = Stock.fromJson({
        'regularMarketPrice': 100, // int, not 100.0
      }, 'TW');

      expect(stock.currentPrice, 100.0);
    });
  });

  group('Stock.isPositive', () {
    Stock stockWithChange(double changeAmount) => Stock(
          symbol: 'TEST',
          name: 'Test',
          currentPrice: 100,
          changeAmount: changeAmount,
          changePercent: 0,
          volume: 0,
          high: 0,
          low: 0,
          open: 0,
          previousClose: 0,
          lastUpdate: DateTime.now(),
          market: 'TW',
        );

    test('true when change is positive', () {
      expect(stockWithChange(1.5).isPositive, isTrue);
    });

    test('true when change is exactly zero (unchanged counts as "not down")', () {
      expect(stockWithChange(0).isPositive, isTrue);
    });

    test('false when change is negative', () {
      expect(stockWithChange(-1.5).isPositive, isFalse);
    });
  });

  group('Stock formatted getters', () {
    Stock stockWith({
      required double price,
      required double change,
      required double changePercent,
    }) =>
        Stock(
          symbol: 'TEST',
          name: 'Test',
          currentPrice: price,
          changeAmount: change,
          changePercent: changePercent,
          volume: 0,
          high: 0,
          low: 0,
          open: 0,
          previousClose: 0,
          lastUpdate: DateTime.now(),
          market: 'TW',
        );

    test('formattedPrice always shows 2 decimal places, no sign', () {
      final stock = stockWith(price: 585, change: 0, changePercent: 0);
      expect(stock.formattedPrice, '585.00');
    });

    test('formattedChange prefixes + for positive change', () {
      final stock = stockWith(price: 100, change: 5.5, changePercent: 1.2);
      expect(stock.formattedChange, '+5.50');
    });

    test('formattedChange has no extra sign for negative change (toStringAsFixed keeps the -)', () {
      final stock = stockWith(price: 100, change: -5.5, changePercent: -1.2);
      expect(stock.formattedChange, '-5.50');
    });

    test('formattedChangePercent prefixes + and appends % for positive change', () {
      final stock = stockWith(price: 100, change: 5.5, changePercent: 1.2);
      expect(stock.formattedChangePercent, '+1.20%');
    });

    test('formattedChangePercent for negative change', () {
      final stock = stockWith(price: 100, change: -5.5, changePercent: -1.2);
      expect(stock.formattedChangePercent, '-1.20%');
    });

    test('formattedChange for exactly zero change shows +0.00 (sign follows isPositive convention)', () {
      final stock = stockWith(price: 100, change: 0, changePercent: 0);
      expect(stock.formattedChange, '+0.00');
    });
  });
}
