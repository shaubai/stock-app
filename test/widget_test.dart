// Smoke test: builds the real app widget tree (MyApp -> AuthWrapper) and
// verifies it renders the login screen for a signed-out user, without
// touching real Firebase or a real device/emulator's SQLite.
//
// Previously this called Firebase.initializeApp() and openDatabase()
// through the real AuthService/StorageServiceMobile with no test doubles,
// which always threw (no Firebase app configured, no sqflite platform
// channel in a plain `flutter test` run) — the test only "passed" in the
// sense that testWidgets didn't crash the process; it exercised no real
// app behavior. Fixed by making the two real dependencies injectable:
// MyApp.authProvider (see lib/main.dart) and the global sqflite
// databaseFactory (see setUpAll below).

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:stock_app/main.dart';
import 'package:stock_app/providers/auth_provider.dart';
import 'package:stock_app/providers/watchlist_provider.dart';
import 'package:stock_app/services/storage_service_factory.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  // WatchlistProvider.init() (via AuthWrapper._initializeAuth) goes through
  // StorageServiceMobile on non-web test runs, which calls sqflite's
  // getDatabasesPath()/openDatabase() — those only work once databaseFactory
  // is set to a real engine.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('shows the login screen for a signed-out user', (WidgetTester tester) async {
    final fakeAuthService = FakeAuthService(); // currentUserValue left null: signed out
    final watchlistProvider = WatchlistProvider(createStorageService());

    await tester.pumpWidget(MyApp(
      watchlistProvider: watchlistProvider,
      authProvider: AuthProvider(authService: fakeAuthService),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Stock App'), findsOneWidget);
    expect(find.text('使用 Google 登入'), findsOneWidget);
    expect(find.text('匿名使用'), findsOneWidget);

    fakeAuthService.dispose();
  });
}
