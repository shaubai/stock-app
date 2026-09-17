import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_app/services/http_retry_client.dart';
import 'package:stock_app/services/stock_service.dart';

/// Regression coverage for StockService's TWSE realtime-quote parsing
/// (_parseTaiwanStock), reached indirectly via getTaiwanStock/getTaiwanStocks
/// since it's private. This is the exact logic that caused the "price shows
/// 0 during market hours" bug fixed on 2026-09-16: TWSE's outer `z` field is
/// often "-" during market hours, with the real price nested in `trade.z`.
void main() {
  StockService serviceReturning(String body, {int statusCode = 200}) {
    // TWSE responses contain Chinese characters, so the mock response must
    // be encoded as UTF-8 — http.Response defaults to Latin-1, which throws
    // when given non-Latin-1 bytes.
    final client = MockClient(
      (request) async => http.Response(body, statusCode, headers: {
        'content-type': 'application/json; charset=utf-8',
      }),
    );
    // HttpRetryClient treats 5xx as retryable and would otherwise wait out
    // real exponential-backoff delays here; no-op the delay so these stay
    // fast unit tests rather than accidentally exercising real timing.
    return StockService(
      httpClient: HttpRetryClient(client: client, delay: (_) async {}),
    );
  }

  group('StockService.getTaiwanStock — TWSE response parsing', () {
    test('parses a normal post-market response (outer z has the price)', () async {
      final service = serviceReturning(jsonEncode({
        'msgArray': [
          {
            'c': '2330',
            'n': '台積電',
            'z': '585.0000',
            'y': '580.0000',
            'o': '582.0000',
            'h': '588.0000',
            'l': '580.0000',
            'v': '25000',
          }
        ],
      }));

      final stock = await service.getTaiwanStock('2330');

      expect(stock, isNotNull);
      expect(stock!.symbol, '2330');
      expect(stock.name, '台積電');
      expect(stock.currentPrice, 585.0);
      expect(stock.previousClose, 580.0);
      expect(stock.changeAmount, 5.0);
      expect(stock.volume, 25000000, reason: 'TWSE reports 張 (lots); should be *1000 for shares');
      expect(stock.market, 'TW');
    });

    test('falls back to nested trade.z when outer z is "-" (the intraday bug)', () async {
      // This is the exact shape TWSE returns during market hours: outer z is
      // "-" but the real latest trade price is nested under trade.z.
      final service = serviceReturning(jsonEncode({
        'msgArray': [
          {
            'c': '2330',
            'n': '台積電',
            'z': '-',
            'y': '2380.0000',
            'o': '2375.0000',
            'h': '2385.0000',
            'l': '2375.0000',
            'v': '3304',
            'trade': {'t': '09:43:25', 'v': 2, 'z': '2385.0000', 'ft': 20},
          }
        ],
      }));

      final stock = await service.getTaiwanStock('2330');

      expect(stock, isNotNull);
      expect(stock!.currentPrice, 2385.0,
          reason: 'should read trade.z, not fall back to 0 or previousClose');
      expect(stock.changeAmount, 5.0);
    });

    test('falls back to previousClose when both z and trade.z are unavailable', () async {
      final service = serviceReturning(jsonEncode({
        'msgArray': [
          {
            'c': '2330',
            'n': '台積電',
            'z': '-',
            'y': '2380.0000',
            'o': '2375.0000',
            'h': '2375.0000',
            'l': '2375.0000',
            'v': '0',
          }
        ],
      }));

      final stock = await service.getTaiwanStock('2330');

      expect(stock, isNotNull);
      expect(stock!.currentPrice, 2380.0, reason: 'last-resort fallback to previous close, not 0');
      expect(stock.changeAmount, 0.0);
    });

    test('returns null when msgArray is empty (symbol not found)', () async {
      final service = serviceReturning(jsonEncode({'msgArray': []}));

      final stock = await service.getTaiwanStock('0000');

      expect(stock, isNull);
    });

    test('returns null on non-200 response', () async {
      final service = serviceReturning('', statusCode: 500);

      final stock = await service.getTaiwanStock('2330');

      expect(stock, isNull);
    });

    test('returns null on malformed JSON rather than throwing', () async {
      final service = serviceReturning('not json');

      final stock = await service.getTaiwanStock('2330');

      expect(stock, isNull);
    });
  });

  group('StockService.getTaiwanStocks — batch parsing', () {
    test('parses multiple stocks preserving API response order', () async {
      final service = serviceReturning(jsonEncode({
        'msgArray': [
          {'c': '2330', 'n': '台積電', 'z': '585.0', 'y': '580.0', 'o': '582.0', 'h': '588.0', 'l': '580.0', 'v': '100'},
          {'c': '2317', 'n': '鴻海', 'z': '105.0', 'y': '104.0', 'o': '104.5', 'h': '106.0', 'l': '104.0', 'v': '200'},
        ],
      }));

      final stocks = await service.getTaiwanStocks(['2330', '2317']);

      expect(stocks, hasLength(2));
      expect(stocks[0].symbol, '2330');
      expect(stocks[1].symbol, '2317');
    });

    test('returns empty list for empty symbol list without making a request', () async {
      var requestMade = false;
      final client = MockClient((request) async {
        requestMade = true;
        return http.Response('{}', 200);
      });
      final service = StockService(httpClient: HttpRetryClient(client: client));

      final stocks = await service.getTaiwanStocks([]);

      expect(stocks, isEmpty);
      expect(requestMade, isFalse);
    });
  });

  group('StockService.getIdList', () {
    test('parses idList from a successful response', () async {
      final service = serviceReturning(jsonEncode({
        'idList': ['2330', '2317', '2454'],
        'cached': true,
        'updatedAt': 1234567890000,
      }));

      final idList = await service.getIdList();

      expect(idList, ['2330', '2317', '2454']);
    });

    test('returns null when idList field is missing', () async {
      final service = serviceReturning(jsonEncode({'error': 'not ready'}));

      final idList = await service.getIdList();

      expect(idList, isNull);
    });

    test('returns null on non-200 response (e.g. endpoint not deployed yet)', () async {
      final service = serviceReturning('Not Found', statusCode: 404);

      final idList = await service.getIdList();

      expect(idList, isNull);
    });
  });
}
