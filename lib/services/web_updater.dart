library;

/// Reloads the page on Web when a newer version is detected at startup, and
/// guards against reload loops via sessionStorage.
///
/// kIsWeb is a runtime check and can't gate which file the compiler includes
/// — a non-Web build would fail to compile if it tried to include
/// package:web unconditionally. This conditional import selects the real
/// implementation (web_updater_web.dart) only when compiling for Web
/// (dart.library.js_interop), and a no-op stub (web_updater_stub.dart)
/// everywhere else, so callers can use WebUpdater unconditionally without
/// needing their own kIsWeb checks around every call site.
export 'web_updater_stub.dart'
    if (dart.library.js_interop) 'web_updater_web.dart';
