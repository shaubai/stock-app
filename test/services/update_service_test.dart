import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stock_app/services/update_service.dart';

void main() {
  // PackageInfo.fromPlatform() (used internally by checkForUpdate) needs
  // both the test binding and a mocked platform channel value, or it throws
  // before ever reaching the HTTP call — checkForUpdate's try/catch would
  // otherwise mask that as a plain "returns null", making these tests pass
  // for the wrong reason. All tests below run with a fixed "current
  // version" of 1.0.0, set here.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'stock_app',
      packageName: 'com.example.stock_app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  group('isNewerVersion', () {
    test('returns true when latest has a higher patch version', () {
      expect(isNewerVersion('1.0.0', '1.0.1'), isTrue);
    });

    test('returns true when latest has a higher minor version', () {
      expect(isNewerVersion('1.0.9', '1.1.0'), isTrue);
    });

    test('returns true when latest has a higher major version', () {
      expect(isNewerVersion('1.9.9', '2.0.0'), isTrue);
    });

    test('returns false when versions are identical', () {
      expect(isNewerVersion('1.0.8', '1.0.8'), isFalse);
    });

    test('returns false when latest is older than current', () {
      expect(isNewerVersion('1.0.8', '1.0.7'), isFalse,
          reason:
              'guards against a stale/misconfigured version.json ever prompting a downgrade');
    });

    test('treats a missing patch segment as 0 (e.g. "1.0" == "1.0.0")', () {
      expect(isNewerVersion('1.0', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0', '1.0.1'), isTrue);
    });

    test('higher major outweighs a lower minor/patch', () {
      // e.g. 2.0.0 is newer than 1.9.9 even though 9 > 0 in the later segments
      expect(isNewerVersion('1.9.9', '2.0.0'), isTrue);
      expect(isNewerVersion('2.0.0', '1.9.9'), isFalse);
    });
  });

  group('UpdateService.checkForUpdate', () {
    UpdateService serviceReturning(String body, {int statusCode = 200}) {
      // releaseNotes can contain Chinese characters, so the mock response
      // must be encoded as UTF-8 — http.Response defaults to Latin-1, which
      // throws when given non-Latin-1 bytes (see stock_service_test.dart
      // for the same pattern).
      final client = MockClient(
        (request) async => http.Response(body, statusCode, headers: {
          'content-type': 'application/json; charset=utf-8',
        }),
      );
      return UpdateService(httpClient: client);
    }

    test('returns UpdateInfo when the server reports a newer version', () async {
      final service = serviceReturning(jsonEncode({
        'version': '9.9.9',
        'downloadUrl': 'https://example.com/app.apk',
        'releaseNotes': '重大更新',
        'forceUpdate': true,
      }));

      final info = await service.checkForUpdate();

      expect(info, isNotNull);
      expect(info!.latestVersion, '9.9.9');
      expect(info.downloadUrl, 'https://example.com/app.apk');
      expect(info.releaseNotes, '重大更新');
      expect(info.forceUpdate, isTrue);
    });

    test('returns null when the server version is not newer', () async {
      final service = serviceReturning(jsonEncode({
        'version': '0.0.1',
        'downloadUrl': 'https://example.com/app.apk',
        'forceUpdate': false,
      }));

      final info = await service.checkForUpdate();

      expect(info, isNull);
    });

    test('defaults releaseNotes when the field is missing', () async {
      final service = serviceReturning(jsonEncode({
        'version': '9.9.9',
        'downloadUrl': 'https://example.com/app.apk',
      }));

      final info = await service.checkForUpdate();

      expect(info!.releaseNotes, '有新版本可用');
    });

    test('defaults forceUpdate to false when the field is missing', () async {
      final service = serviceReturning(jsonEncode({
        'version': '9.9.9',
        'downloadUrl': 'https://example.com/app.apk',
      }));

      final info = await service.checkForUpdate();

      expect(info!.forceUpdate, isFalse);
    });

    test('returns null on a non-200 response instead of throwing', () async {
      final service = serviceReturning('Not Found', statusCode: 404);

      final info = await service.checkForUpdate();

      expect(info, isNull);
    });

    test('returns null on malformed JSON instead of throwing', () async {
      final service = serviceReturning('not json');

      final info = await service.checkForUpdate();

      expect(info, isNull);
    });

    test('returns null when the client throws (e.g. network error)', () async {
      final client = MockClient((request) async => throw Exception('network unreachable'));
      final service = UpdateService(httpClient: client);

      final info = await service.checkForUpdate();

      expect(info, isNull);
    });
  });
}
