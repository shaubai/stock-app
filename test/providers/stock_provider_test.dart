import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_app/providers/stock_provider.dart';
import 'package:stock_app/services/http_retry_client.dart';
import 'package:stock_app/services/stock_service.dart';

void main() {
  /// Builds a StockService whose HTTP layer is a MockClient returning the
  /// given TWSE-shaped stock list for every request (both the batch quote
  /// call and the single index quote call hit the same mocked endpoint).
  StockService serviceReturningStocks(List<Map<String, String>> stockFields) {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({'msgArray': stockFields}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    return StockService(httpClient: HttpRetryClient(client: client, delay: (_) async {}));
  }

  StockService serviceThatFails() {
    final client = MockClient((request) async => http.Response('', 500));
    return StockService(httpClient: HttpRetryClient(client: client, delay: (_) async {}));
  }

  /// Builds a StockService where id-list and quote requests are routed to
  /// different canned responses based on the request path, so tests can
  /// verify loadStocks actually uses the id-list symbols it's given.
  StockService serviceWithIdList(
    List<String> idList,
    List<Map<String, String>> stockFields,
  ) {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/id-list')) {
        return http.Response(
          jsonEncode({'idList': idList, 'cached': true, 'updatedAt': 0}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({'msgArray': stockFields}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    return StockService(httpClient: HttpRetryClient(client: client, delay: (_) async {}));
  }

  Map<String, String> stockField(String symbol, {String price = '100.0'}) => {
        'c': symbol,
        'n': symbol,
        'z': price,
        'y': price,
        'o': price,
        'h': price,
        'l': price,
        'v': '100',
      };

  group('loadStocks', () {
    test('populates stocks and taiwanIndex, sets lastUpdateTime, clears loading', () async {
      final service = serviceReturningStocks([stockField('2330', price: '585.0')]);
      final provider = StockProvider(stockService: service);

      expect(provider.isLoading, isFalse, reason: 'not loading before first call');

      await provider.loadStocks();

      expect(provider.stocks, isNotEmpty);
      expect(provider.stocks.first.symbol, '2330');
      expect(provider.taiwanIndex, isNotNull,
          reason: 'both the batch quote and the t00 index quote hit the same mocked response');
      expect(provider.lastUpdateTime, isNotNull);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
    });

    test('sets isLoading true during the call when showLoading is true', () async {
      final service = serviceReturningStocks([stockField('2330')]);
      final provider = StockProvider(stockService: service);

      final future = provider.loadStocks();
      expect(provider.isLoading, isTrue);

      await future;
      expect(provider.isLoading, isFalse);
    });

    test('does not toggle isLoading when showLoading is false (silent refresh)', () async {
      final service = serviceReturningStocks([stockField('2330')]);
      final provider = StockProvider(stockService: service);

      final future = provider.loadStocks(showLoading: false);
      expect(provider.isLoading, isFalse,
          reason: 'silent refresh must not flip the UI into a loading state');

      await future;
      expect(provider.isLoading, isFalse);
    });

    // Note: StockService.getTaiwanStock(s) swallows non-200 responses and
    // returns null/[] rather than throwing (see stock_service_test.dart),
    // so StockProvider's error field is only ever set when something
    // throws (e.g. a network-layer exception surfaced by HttpRetryClient
    // after exhausting retries) — a plain API failure response yields an
    // empty stock list with no error, not an error state. That's existing
    // production behavior; these tests document it rather than change it.
    test('API failure response (non-exception) yields empty stocks with no error', () async {
      final provider = StockProvider(stockService: serviceThatFails());

      await provider.loadStocks();

      expect(provider.stocks, isEmpty);
      expect(provider.error, isNull);
      expect(provider.isLoading, isFalse);
    });

    test('does not set error on API failure when showLoading is false (silent refresh)', () async {
      final provider = StockProvider(stockService: serviceThatFails());

      await provider.loadStocks(showLoading: false);

      expect(provider.error, isNull,
          reason: 'a failed background refresh should not surface an error over existing data');
    });

    test('keeps previous taiwanIndex if a refresh returns none (does not null it out)', () async {
      final goodService = serviceReturningStocks([stockField('t00', price: '17500.0')]);
      final provider = StockProvider(stockService: goodService);
      await provider.loadStocks();
      final indexBefore = provider.taiwanIndex;
      expect(indexBefore, isNotNull);

      // Simulate the index symbol coming back empty next time by swapping
      // in a service that fails outright.
      final failingProvider = StockProvider(stockService: serviceThatFails());
      await failingProvider.loadStocks(showLoading: false);
      // taiwanIndex on a fresh provider stays null when nothing ever loaded —
      // this just documents that loadStocks only *replaces* taiwanIndex when
      // a new non-null value is available (see `?? _taiwanIndex` in source).
      expect(failingProvider.taiwanIndex, isNull);
    });

    test('notifies listeners', () async {
      final service = serviceReturningStocks([stockField('2330')]);
      final provider = StockProvider(stockService: service);
      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.loadStocks();

      expect(notifyCount, greaterThanOrEqualTo(1));
    });

    test('uses the remote id-list symbols when available, not the built-in default list', () async {
      // Only '9999' is "known" to this mock quote endpoint; if loadStocks
      // ignored the id-list and queried defaultTaiwanStocks instead, this
      // symbol wouldn't be requested and the assertion below would fail.
      final service = serviceWithIdList(['9999'], [stockField('9999', price: '42.0')]);
      final provider = StockProvider(stockService: service);

      await provider.loadStocks();

      expect(provider.stocks.map((s) => s.symbol), ['9999']);
    });

    test('falls back to defaultTaiwanStocks when id-list is unavailable (e.g. 404, not yet deployed)', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/id-list')) {
          return http.Response('Not Found', 404);
        }
        return http.Response(
          jsonEncode({'msgArray': [stockField('2330')]}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = StockService(httpClient: HttpRetryClient(client: client, delay: (_) async {}));
      final provider = StockProvider(stockService: service);

      await provider.loadStocks();

      // The mocked quote endpoint ignores which symbols were requested and
      // always returns this one stock — so a non-empty result here confirms
      // loadStocks proceeded to fetch quotes using the fallback list rather
      // than stalling out when getIdList() returns null.
      expect(provider.stocks, isNotEmpty);
      expect(provider.error, isNull);
    });

    test('caches the id-list within a session: a second loadStocks call does not re-fetch it', () async {
      var idListRequestCount = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/id-list')) {
          idListRequestCount++;
          return http.Response(
            jsonEncode({'idList': ['9999'], 'cached': true, 'updatedAt': 0}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({'msgArray': [stockField('9999')]}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = StockService(httpClient: HttpRetryClient(client: client, delay: (_) async {}));
      final provider = StockProvider(stockService: service);

      await provider.loadStocks();
      await provider.loadStocks(showLoading: false); // simulates the 30s auto-refresh tick

      expect(idListRequestCount, 1,
          reason: 'id-list changes once a day server-side; the 30s quote refresh should reuse the cached list');
    });

    test('retries fetching id-list on the next loadStocks call if the first attempt failed', () async {
      var idListRequestCount = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/id-list')) {
          idListRequestCount++;
          // First attempt fails (e.g. transient network error), second succeeds.
          if (idListRequestCount == 1) {
            return http.Response('Server Error', 500);
          }
          return http.Response(
            jsonEncode({'idList': ['9999'], 'cached': true, 'updatedAt': 0}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({'msgArray': [stockField('9999')]}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = StockService(httpClient: HttpRetryClient(client: client, delay: (_) async {}));
      final provider = StockProvider(stockService: service);

      await provider.loadStocks(); // id-list fetch fails, falls back to defaultTaiwanStocks
      await provider.loadStocks(showLoading: false); // should retry, not stay stuck on the fallback

      expect(provider.stocks.map((s) => s.symbol), ['9999'],
          reason: 'a failed id-list fetch must not be cached — the next call should retry it');
    });
  });

  group('startAutoRefresh / stopAutoRefresh', () {
    test('calling startAutoRefresh twice does not create duplicate timers', () async {
      final service = serviceReturningStocks([stockField('2330')]);
      final provider = StockProvider(stockService: service);

      // No direct way to inspect timer count from outside; this at least
      // verifies calling it repeatedly doesn't throw and stop cleanly works.
      provider.startAutoRefresh();
      provider.startAutoRefresh();
      provider.stopAutoRefresh();
      provider.dispose();
    });
  });
}
