// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:stock_app/main.dart';
import 'package:stock_app/providers/watchlist_provider.dart';
import 'package:stock_app/services/storage_service_factory.dart';

void main() {
  testWidgets('Stock App smoke test', (WidgetTester tester) async {
    // Initialize watchlist provider with local storage
    final watchlistProvider = WatchlistProvider(createStorageService());
    await watchlistProvider.init();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(watchlistProvider: watchlistProvider));

    // Wait for the app to load
    await tester.pumpAndSettle();

    // Note: With Firebase auth, the app will show login screen first
    // This is just a basic smoke test to ensure the app builds
  });
}
