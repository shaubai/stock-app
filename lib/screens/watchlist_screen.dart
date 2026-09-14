import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stock.dart';
import '../services/stock_service.dart';
import '../providers/watchlist_provider.dart';
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
      final stocks = await _stockService.getTaiwanStocks(symbols);

      if (mounted) {
        setState(() {
          _stocks = stocks;
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
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _stocks.length,
        itemBuilder: (context, index) => _buildStockCard(_stocks[index]),
      );
    } else {
      return ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _stocks.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) => _buildStockListTile(_stocks[index]),
      );
    }
  }

  Widget _buildStockCard(Stock stock) {
    final color = stock.isPositive ? Colors.red : Colors.green;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StockDetailScreen(stock: stock),
          ),
        ).then((_) => _loadWatchlistStocks());
      },
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                stock.symbol,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Consumer<WatchlistProvider>(
                              builder: (context, watchlist, child) {
                                return GestureDetector(
                                  onTap: () async {
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
                                  child: const Icon(
                                    Icons.favorite,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        Text(
                          stock.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withAlpha((255 * 0.1).round()),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      stock.market,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stock.formattedPrice,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        stock.formattedChange,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        stock.formattedChangePercent,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockListTile(Stock stock) {
    final color = stock.isPositive ? Colors.red : Colors.green;

    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StockDetailScreen(stock: stock),
          ),
        ).then((_) => _loadWatchlistStocks());
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Consumer<WatchlistProvider>(
        builder: (context, watchlist, child) {
          return GestureDetector(
            onTap: () async {
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
            child: const Icon(
              Icons.favorite,
              color: Colors.red,
            ),
          );
        },
      ),
      title: Row(
        children: [
          Text(
            stock.symbol,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha((255 * 0.1).round()),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              stock.market,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        stock.name,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            stock.formattedPrice,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                stock.isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: color,
                size: 20,
              ),
              Text(
                stock.formattedChangePercent,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
