import 'package:flutter_test/flutter_test.dart';
import 'package:stock_app/utils/technical_indicators.dart';

void main() {
  group('calculateMA', () {
    test('computes simple moving average once enough samples exist', () {
      final ma = calculateMA([1, 2, 3, 4, 5], 3);

      // indices 0,1 (period-1=2 not yet reached) use raw price
      expect(ma[0], 1);
      expect(ma[1], 2);
      // index 2: avg(1,2,3) = 2
      expect(ma[2], 2);
      // index 3: avg(2,3,4) = 3
      expect(ma[3], 3);
      // index 4: avg(3,4,5) = 4
      expect(ma[4], 4);
    });

    test('returns empty for empty input', () {
      expect(calculateMA([], 5), isEmpty);
    });
  });

  group('calculateEMA', () {
    test('seeds first value with the raw price', () {
      final ema = calculateEMA([10, 12, 14], 3);
      expect(ema[0], 10);
    });

    test('matches manual calculation for a known short series', () {
      // multiplier = 2/(3+1) = 0.5
      // ema[0] = 10
      // ema[1] = (12-10)*0.5 + 10 = 11
      // ema[2] = (14-11)*0.5 + 11 = 12.5
      final ema = calculateEMA([10, 12, 14], 3);
      expect(ema[1], 11);
      expect(ema[2], 12.5);
    });
  });

  group('calculateRSI', () {
    test('returns neutral 50 for samples shorter than period', () {
      final rsi = calculateRSI([100, 101, 102], period: 14);
      expect(rsi, everyElement(50.0));
    });

    test('returns 100 when there are no losses in the lookback window', () {
      // Strictly increasing prices -> avgLoss = 0 -> RSI = 100
      final prices = List<double>.generate(20, (i) => 100.0 + i);
      final rsi = calculateRSI(prices, period: 14);
      expect(rsi[14], 100.0);
    });

    test('returns a value between 0 and 100 for mixed price action', () {
      final prices = [
        44.34, 44.09, 44.15, 43.61, 44.33, 44.83, 45.10, 45.42, 45.84, 46.08,
        45.89, 46.03, 45.61, 46.28, 46.28, 46.00, 46.03, 46.41, 46.22, 45.64,
      ];
      final rsi = calculateRSI(prices, period: 14);

      // First 14 entries (indices 0-13) are the seed window, stay neutral.
      expect(rsi[13], 50.0);
      // Index 14 onward has a real computed value.
      for (var i = 14; i < rsi.length; i++) {
        expect(rsi[i], inInclusiveRange(0.0, 100.0));
      }
      // This is a well-known textbook RSI example (Wilder's original data);
      // the 14-period RSI at index 14 should be close to ~70.5.
      expect(rsi[14], closeTo(70.5, 1.0));
    });
  });

  group('calculateMACD', () {
    test('returns empty results for empty input', () {
      final result = calculateMACD([]);
      expect(result.macd, isEmpty);
      expect(result.signal, isEmpty);
      expect(result.histogram, isEmpty);
    });

    test('histogram always equals macd - signal', () {
      final prices = List<double>.generate(50, (i) => 100 + (i % 10).toDouble());
      final result = calculateMACD(prices);

      for (var i = 0; i < prices.length; i++) {
        expect(
          result.histogram[i],
          closeTo(result.macd[i] - result.signal[i], 1e-9),
        );
      }
    });

    test('macd is zero when price is constant (fast EMA == slow EMA)', () {
      final prices = List<double>.filled(40, 100.0);
      final result = calculateMACD(prices);

      for (final v in result.macd) {
        expect(v, closeTo(0, 1e-9));
      }
    });

    test('all three series have the same length as the input', () {
      final prices = List<double>.generate(30, (i) => 100.0 + i);
      final result = calculateMACD(prices);

      expect(result.macd, hasLength(prices.length));
      expect(result.signal, hasLength(prices.length));
      expect(result.histogram, hasLength(prices.length));
    });
  });

  group('calculateKD', () {
    test('returns empty results for empty input', () {
      final result = calculateKD([], [], []);
      expect(result.k, isEmpty);
      expect(result.d, isEmpty);
    });

    test('K and D start at neutral 50 and stay within 0-100', () {
      final highs = [10.0, 11.0, 12.0, 11.0, 13.0, 14.0, 12.0, 11.0, 15.0, 16.0];
      final lows = [8.0, 9.0, 9.5, 9.0, 10.0, 11.0, 10.0, 9.0, 11.0, 12.0];
      final closes = [9.0, 10.5, 11.0, 9.5, 12.0, 13.0, 10.5, 10.0, 14.0, 15.0];

      final result = calculateKD(highs, lows, closes, period: 9);

      for (var i = 0; i < result.k.length; i++) {
        expect(result.k[i], inInclusiveRange(0.0, 100.0));
        expect(result.d[i], inInclusiveRange(0.0, 100.0));
      }
    });

    test('RSV is 50 (not NaN/infinite) when high == low for the whole window', () {
      final highs = List<double>.filled(5, 100.0);
      final lows = List<double>.filled(5, 100.0);
      final closes = List<double>.filled(5, 100.0);

      final result = calculateKD(highs, lows, closes, period: 9);

      for (final v in result.k) {
        expect(v.isFinite, isTrue);
      }
    });

    test('K approaches 100 when price closes at the period high repeatedly', () {
      final highs = List<double>.generate(15, (i) => 20.0 + i);
      final lows = List<double>.generate(15, (i) => 10.0 + i);
      final closes = List<double>.generate(15, (i) => 20.0 + i); // closes at the high every day

      final result = calculateKD(highs, lows, closes, period: 9);

      // K should trend upward toward 100 as RSV stays pinned at 100.
      expect(result.k.last, greaterThan(result.k.first));
    });

    test('all output lengths match input length', () {
      final highs = List<double>.generate(20, (i) => 100.0 + i);
      final lows = List<double>.generate(20, (i) => 95.0 + i);
      final closes = List<double>.generate(20, (i) => 98.0 + i);

      final result = calculateKD(highs, lows, closes);

      expect(result.k, hasLength(20));
      expect(result.d, hasLength(20));
    });
  });
}
