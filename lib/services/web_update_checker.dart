import 'package:http/http.dart' as http;
import 'dart:convert';

import 'update_service.dart' show isNewerVersion;
import 'web_updater.dart';

/// The app version baked in at Web build time via
/// `--dart-define=APP_VERSION=...` (see tool/build_web.sh).
///
/// This can't use PackageInfo.fromPlatform() the way Android/iOS do:
/// package_info_plus's own Web implementation fetches web/version.json to
/// answer "what's the current version", which is the exact same source
/// UpdateService compares against for "what's the latest version" — so on
/// Web, "current" and "latest" would always be identical and no update
/// would ever be detected. Empty string if the app wasn't built with
/// --dart-define set (e.g. `flutter run` in development).
const String webAppVersion = String.fromEnvironment('APP_VERSION');

/// Checks whether a newer Web build is available and, if so, reloads the
/// page once (see WebUpdater.hasAlreadyReloadedFor for the loop guard).
///
/// Intended to run once at Web app startup — see main.dart. No-op (via
/// WebUpdater's stub implementation) on non-Web platforms.
///
/// [currentVersion] defaults to the real build-time constant [webAppVersion]
/// for production callers; overridable so tests can exercise the version
/// comparison without needing a --dart-define-built test binary (webAppVersion
/// is a compile-time const and can't be swapped at test time otherwise).
Future<void> checkForWebUpdateAndReload({
  http.Client? httpClient,
  WebUpdater updater = const WebUpdater(),
  String currentVersion = webAppVersion,
}) async {
  if (currentVersion.isEmpty) return;

  final client = httpClient ?? http.Client();
  try {
    // version.json is always served from the same origin as the app itself
    // (see firebase.json — it's part of build/web), so resolving it
    // relative to the current page avoids hardcoding a domain here.
    final versionUrl = Uri.base.resolve('version.json');
    final response =
        await client.get(versionUrl).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body);
    final latestVersion = data['version'] as String?;
    if (latestVersion == null) return;

    if (!isNewerVersion(currentVersion, latestVersion)) return;
    if (updater.hasAlreadyReloadedFor(latestVersion)) return;

    updater.markReloadedFor(latestVersion);
    updater.reloadPage();
  } catch (_) {
    // Network hiccup or malformed JSON: silently skip. Same failure
    // philosophy as UpdateService.checkForUpdate — a broken update check
    // must never block the app from loading normally.
  } finally {
    if (httpClient == null) client.close();
  }
}
