import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../models/stock.dart';
import '../services/stock_service.dart';
import '../providers/watchlist_provider.dart';
import '../widgets/stock_tile.dart';
import 'stock_detail_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  final StockService _stockService = StockService();
  List<Stock> _stocks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWatchlistStocks();
  }

  Future<void> _loadWatchlistStocks() async {
    setState(() => _isLoading = true);

    try {
      final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
      final symbols = watchlistProvider.watchlistSymbols.toList();

      if (symbols.isEmpty) {
        setState(() {
          _stocks = [];
          _isLoading = false;
        });
        return;
      }

      // 載入台股資料
      // 不依賴 API 回傳順序，依照使用者自訂的 symbols 順序重新排列，
      // 讓拖拉排序的 index 與畫面顯示順序保持一致
      final stocks = await _stockService.getTaiwanStocks(symbols);
      final stocksBySymbol = {for (var s in stocks) s.symbol: s};
      final orderedStocks = symbols
          .map((symbol) => stocksBySymbol[symbol])
          .whereType<Stock>()
          .toList();

      if (mounted) {
        setState(() {
          _stocks = orderedStocks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入自選股失敗: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final watchlistProvider = Provider.of<WatchlistProvider>(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('自選股'),
            Text(
              '${watchlistProvider.count} 支股票',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWatchlistStocks,
          ),
        ],
      ),
      body: _buildBody(isTablet, watchlistProvider),
    );
  }

  Widget _buildBody(bool isTablet, WatchlistProvider watchlistProvider) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (watchlistProvider.watchlistSymbols.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '尚無自選股',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '在股票列表或詳情頁點擊愛心圖標加入自選股',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_stocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('無法載入股票資料'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadWatchlistStocks,
              child: const Text('重試'),
            ),
          ],
        ),
      );
    }

    if (isTablet) {
      return ReorderableGridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _stocks.length,
        itemBuilder: (context, index) => KeyedSubtree(
          key: ValueKey(_stocks[index].symbol),
          child: _buildStockTile(_stocks[index], true),
        ),
        onReorder: _handleReorder,
      );
    } else {
      return ReorderableListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _stocks.length,
        itemBuilder: (context, index) => Container(
          key: ValueKey(_stocks[index].symbol),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.black12)),
          ),
          child: _buildStockTile(_stocks[index], false),
        ),
        onReorder: _handleReorder,
      );
    }
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);

    setState(() {
      final adjustedNewIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
      final stock = _stocks.removeAt(oldIndex);
      _stocks.insert(adjustedNewIndex, stock);
    });

    await watchlistProvider.reorder(oldIndex, newIndex);
  }

  Widget _buildStockTile(Stock stock, bool isTablet) {
    return Consumer<WatchlistProvider>(
      builder: (context, watchlist, child) {
        return StockTile(
          stock: stock,
          isTablet: isTablet,
          isFavorite: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StockDetailScreen(stock: stock),
              ),
            ).then((_) => _loadWatchlistStocks());
          },
          onFavoriteTap: () async {
            await watchlist.removeFromWatchlist(stock.symbol);
            _loadWatchlistStocks();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已從自選股移除 ${stock.symbol}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
        );
      },
    );
  }

}
