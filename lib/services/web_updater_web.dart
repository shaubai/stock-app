import 'package:web/web.dart' as web;

/// Web implementation, selected by the conditional import in
/// web_updater.dart when compiling for Web (dart.library.js_interop).
class WebUpdater {
  const WebUpdater();

  static const _sessionKey = 'stock_app_reloaded_for_version';

  /// Guards against a reload loop: if version detection is ever wrong (e.g.
  /// version.json itself served stale, or a future bug), reloading would
  /// otherwise re-detect "a newer version" every time and reload forever.
  /// sessionStorage persists across the reload but not across a real new
  /// tab/session, so a genuinely new session still checks again.
  bool hasAlreadyReloadedFor(String version) {
    return web.window.sessionStorage.getItem(_sessionKey) == version;
  }

  void markReloadedFor(String version) {
    web.window.sessionStorage.setItem(_sessionKey, version);
  }

  void reloadPage() {
    web.window.location.reload();
  }
}
