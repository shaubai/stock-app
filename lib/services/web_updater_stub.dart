/// No-op implementation used on non-Web platforms (Android/iOS/desktop).
///
/// Selected via a conditional import in web_updater.dart based on
/// dart.library.js_interop — kIsWeb is a runtime check and can't gate which
/// file gets compiled, so this stub exists purely so the app still compiles
/// on platforms where package:web (Web-only) isn't available.
class WebUpdater {
  const WebUpdater();

  /// Whether this app session has already reloaded once for [version].
  /// Always false off-Web — there's nothing to guard against.
  bool hasAlreadyReloadedFor(String version) => false;

  /// Records that a reload for [version] happened. No-op off-Web.
  void markReloadedFor(String version) {}

  /// Reloads the page. No-op off-Web.
  void reloadPage() {}
}
