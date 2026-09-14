import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/stock_list_screen.dart';
import 'providers/watchlist_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize watchlist provider
  final watchlistProvider = WatchlistProvider();
  await watchlistProvider.init();

  runApp(MyApp(watchlistProvider: watchlistProvider));
}

class MyApp extends StatelessWidget {
  final WatchlistProvider watchlistProvider;

  const MyApp({super.key, required this.watchlistProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: watchlistProvider),
      ],
      child: MaterialApp(
        title: 'Stock App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const StockListScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

