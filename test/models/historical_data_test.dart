import 'package:flutter_test/flutter_test.dart';
import 'package:stock_app/models/historical_data.dart';

void main() {
  group('HistoricalData.fromJson', () {
    test('parses all fields from a well-formed JSON object', () {
      final data = HistoricalData.fromJson({
        'date': '2026-09-16T00:00:00.000',
        'open': 582.0,
        'high': 588.0,
        'low': 580.0,
        'close': 585.0,
        'volume': 25000000,
      });

      expect(data.date, DateTime.parse('2026-09-16T00:00:00.000'));
      expect(data.open, 582.0);
      expect(data.high, 588.0);
      expect(data.low, 580.0);
      expect(data.close, 585.0);
      expect(data.volume, 25000000);
    });

    test('defaults missing numeric fields to 0', () {
      final data = HistoricalData.fromJson({
        'date': '2026-09-16T00:00:00.000',
      });

      expect(data.open, 0.0);
      expect(data.high, 0.0);
      expect(data.low, 0.0);
      expect(data.close, 0.0);
      expect(data.volume, 0);
    });

    test('accepts int values for double-typed fields', () {
      final data = HistoricalData.fromJson({
        'date': '2026-09-16T00:00:00.000',
        'open': 582, // int, not 582.0
      });

      expect(data.open, 582.0);
    });

    test('throws when date is missing (no fallback — a malformed record should surface loudly)', () {
      expect(
        () => HistoricalData.fromJson({'open': 100}),
        throwsA(anything),
      );
    });
  });
}
