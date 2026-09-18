import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_app/services/web_update_checker.dart';
import 'package:stock_app/services/web_updater_stub.dart';

/// Fake WebUpdater to observe/control reload behavior without a real
/// browser. Reuses the exact same interface as the stub (WebUpdater) that
/// ships on non-Web platforms — checkForWebUpdateAndReload() only depends
/// on that interface, not on package:web directly, so this is a faithful
/// substitute for testing the decision logic in isolation.
class _FakeWebUpdater extends WebUpdater {
  final Set<String> _reloadedVersions = {};
  int reloadCallCount = 0;

  @override
  bool hasAlreadyReloadedFor(String version) => _reloadedVersions.contains(version);

  @override
  void markReloadedFor(String version) => _reloadedVersions.add(version);

  @override
  void reloadPage() => reloadCallCount++;
}

void main() {
  group('checkForWebUpdateAndReload', () {
    test('reloads when the server reports a newer version', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'version': '2.0.0'}), 200),
      );
      final updater = _FakeWebUpdater();

      await checkForWebUpdateAndReload(
        httpClient: client,
        updater: updater,
        currentVersion: '1.0.0',
      );

      expect(updater.reloadCallCount, 1);
      expect(updater.hasAlreadyReloadedFor('2.0.0'), isTrue);
    });

    test('does not reload when the server version is not newer', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'version': '1.0.0'}), 200),
      );
      final updater = _FakeWebUpdater();

      await checkForWebUpdateAndReload(
        httpClient: client,
        updater: updater,
        currentVersion: '1.0.0',
      );

      expect(updater.reloadCallCount, 0);
    });

    test('does not reload twice for the same version (loop guard)', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'version': '2.0.0'}), 200),
      );
      final updater = _FakeWebUpdater();

      await checkForWebUpdateAndReload(
        httpClient: client,
        updater: updater,
        currentVersion: '1.0.0',
      );
      // Simulates a second startup check within the same session (e.g. the
      // reload hadn't actually taken effect yet, or checkForWebUpdateAndReload
      // somehow ran twice) — must not call reloadPage() again for a version
      // already marked as reloaded-for.
      await checkForWebUpdateAndReload(
        httpClient: client,
        updater: updater,
        currentVersion: '1.0.0',
      );

      expect(updater.reloadCallCount, 1,
          reason: 'a version already reloaded-for must not trigger reloadPage() again, '
              'or a broken version check would reload forever');
    });

    test('is a no-op when currentVersion is empty (e.g. flutter run in dev, no --dart-define)', () async {
      expect(webAppVersion, isEmpty,
          reason: 'sanity check: flutter test does not pass --dart-define=APP_VERSION, '
              'so the real production default argument is empty here too');

      var requestMade = false;
      final client = MockClient((request) async {
        requestMade = true;
        return http.Response(jsonEncode({'version': '99.0.0'}), 200);
      });
      final updater = _FakeWebUpdater();

      await checkForWebUpdateAndReload(httpClient: client, updater: updater, currentVersion: '');

      expect(requestMade, isFalse,
          reason: 'should never fetch version.json without a current version to compare against');
      expect(updater.reloadCallCount, 0);
    });

    test('does not throw and does not reload when the HTTP request fails', () async {
      final client = MockClient((request) async => throw Exception('network error'));
      final updater = _FakeWebUpdater();

      await checkForWebUpdateAndReload(
        httpClient: client,
        updater: updater,
        currentVersion: '1.0.0',
      );

      expect(updater.reloadCallCount, 0);
    });

    test('does not throw and does not reload on a non-200 response', () async {
      final client = MockClient((request) async => http.Response('Not Found', 404));
      final updater = _FakeWebUpdater();

      await checkForWebUpdateAndReload(
        httpClient: client,
        updater: updater,
        currentVersion: '1.0.0',
      );

      expect(updater.reloadCallCount, 0);
    });

    test('does not throw and does not reload on malformed JSON', () async {
      final client = MockClient((request) async => http.Response('not json', 200));
      final updater = _FakeWebUpdater();

      await checkForWebUpdateAndReload(
        httpClient: client,
        updater: updater,
        currentVersion: '1.0.0',
      );

      expect(updater.reloadCallCount, 0);
    });

    test('does not throw and does not reload when the version field is missing', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'downloadUrl': 'x'}), 200),
      );
      final updater = _FakeWebUpdater();

      await checkForWebUpdateAndReload(
        httpClient: client,
        updater: updater,
        currentVersion: '1.0.0',
      );

      expect(updater.reloadCallCount, 0);
    });
  });

  group('WebUpdater stub (non-Web platforms)', () {
    // Confirms the no-op stub's contract directly, since it's what
    // Android/iOS actually compile against.
    test('hasAlreadyReloadedFor always returns false', () {
      const updater = WebUpdater();
      expect(updater.hasAlreadyReloadedFor('1.0.0'), isFalse);
    });

    test('markReloadedFor and reloadPage do nothing (no exception)', () {
      const updater = WebUpdater();
      expect(() => updater.markReloadedFor('1.0.0'), returnsNormally);
      expect(() => updater.reloadPage(), returnsNormally);
    });
  });
}
