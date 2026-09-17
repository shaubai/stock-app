import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_app/services/http_retry_client.dart';

void main() {
  group('HttpRetryClient', () {
    test('returns immediately on 200 without retrying', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('ok', 200);
      });

      final retryClient = HttpRetryClient(
        client: client,
        delay: (_) async {}, // no-op: don't actually wait in tests
      );

      final response = await retryClient.get(Uri.parse('https://example.com'));

      expect(response.statusCode, 200);
      expect(callCount, 1);
    });

    test('does not retry on non-retryable 4xx (e.g. 404)', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('not found', 404);
      });

      final retryClient = HttpRetryClient(
        client: client,
        delay: (_) async {},
      );

      final response = await retryClient.get(Uri.parse('https://example.com'));

      expect(response.statusCode, 404);
      expect(callCount, 1, reason: '404 should not be retried');
    });

    test('retries on 429 and succeeds on second attempt', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('rate limited', 429);
        }
        return http.Response('ok', 200);
      });

      final retryClient = HttpRetryClient(
        client: client,
        delay: (_) async {},
      );

      final response = await retryClient.get(Uri.parse('https://example.com'));

      expect(response.statusCode, 200);
      expect(callCount, 2);
    });

    test('retries on 503 up to max attempts then returns last response', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('unavailable', 503);
      });

      final retryClient = HttpRetryClient(
        client: client,
        delay: (_) async {},
      );

      final response = await retryClient.get(Uri.parse('https://example.com'));

      expect(response.statusCode, 503);
      expect(callCount, 3, reason: 'should attempt exactly 3 times total');
    });

    test('honors Retry-After header on 429', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('rate limited', 429, headers: {
            'retry-after': '7',
          });
        }
        return http.Response('ok', 200);
      });

      final capturedDelays = <Duration>[];
      final retryClient = HttpRetryClient(
        client: client,
        delay: (d) async {
          capturedDelays.add(d);
        },
      );

      await retryClient.get(Uri.parse('https://example.com'));

      expect(capturedDelays, hasLength(1));
      expect(capturedDelays.first, const Duration(seconds: 7),
          reason: 'Retry-After should override exponential backoff');
    });

    test('uses exponential backoff without Retry-After', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('unavailable', 503);
      });

      final capturedDelays = <Duration>[];
      final retryClient = HttpRetryClient(
        client: client,
        random: Random(42), // deterministic jitter for the assertion below
        delay: (d) async {
          capturedDelays.add(d);
        },
      );

      await retryClient.get(Uri.parse('https://example.com'));

      expect(capturedDelays, hasLength(2), reason: '3 attempts -> 2 delays between them');
      // 1st retry delay ~1s (+jitter 0-300ms), 2nd retry delay ~2s (+jitter)
      expect(capturedDelays[0].inMilliseconds, greaterThanOrEqualTo(1000));
      expect(capturedDelays[0].inMilliseconds, lessThan(1300));
      expect(capturedDelays[1].inMilliseconds, greaterThanOrEqualTo(2000));
      expect(capturedDelays[1].inMilliseconds, lessThan(2300));
    });

    test('retries on TimeoutException and eventually rethrows it', () async {
      final client = MockClient((request) async {
        // Simulate a request that never completes — the retry client's own
        // (short, injected) timeout will fire and cut this off.
        return Completer<http.Response>().future;
      });

      final retryClient = HttpRetryClient(
        client: client,
        delay: (_) async {},
        timeout: const Duration(milliseconds: 20),
      );

      await expectLater(
        retryClient.get(Uri.parse('https://example.com')),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
