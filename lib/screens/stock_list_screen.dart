import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stock.dart';
import '../services/stock_service.dart';
import '../services/mock_stock_service.dart';
import '../providers/watchlist_provider.dart';
import 'stock_detail_screen.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  final StockService _stockService = StockService();
  final MockStockService _mockStockService = MockStockService();
  List<Stock> _stocks = [];
  bool _isLoading = false;

  // 預設顯示的台股清單（熱門股票）
  static const List<String> _defaultTaiwanStocks = [
    '2330', // 台積電
    '2317', // 鴻海
    '2454', // 聯發科
    '2308', // 台達電
    '2412', // 中華電
    '2882', // 國泰金
    '2881', // 富邦金
    '2303', // 聯電
  ];

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  Future<void> _loadStocks() async {
    setState(() => _isLoading = true);

    try {
      List<Stock> stocks;

      if (kIsWeb) {
        // Web 平台：使用 Mock 資料（避免 CORS 問題）
        stocks = await _mockStockService.getMockStocks();
      } else {
        // Mobile 平台：使用真實 API
        stocks = await _stockService.getTaiwanStocks(_defaultTaiwanStocks);
      }

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
          SnackBar(
            content: Text(
              kIsWeb
                  ? '載入股票資料失敗: $e（Web 版使用模擬資料）'
                  : '載入股票資料失敗: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('股票看板'),
            if (kIsWeb)
              const Text(
                'Web 版（模擬資料）',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (kIsWeb)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Web 版說明'),
                    content: const Text(
                      'Web 版本因瀏覽器 CORS 限制，目前使用模擬資料。\n\n'
                      '若需查看即時真實資料，請使用 iOS 或 Android App。\n\n'
                      'Mobile App 使用證交所官方 API，資料延遲約 20 秒。'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('了解'),
                      ),
                    ],
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStocks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildStockList(isTablet),
    );
  }

  Widget _buildStockList(bool isTablet) {
    if (_stocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.show_chart, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('尚無股票資料'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadStocks,
              child: const Text('重新載入'),
            ),
          ],
        ),
      );
    }

    if (isTablet) {
      // 平板：使用 Grid 顯示
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
      // 手機：使用 List 顯示
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
        );
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
                              final isInWatchlist = watchlist.isInWatchlist(stock.symbol);
                              return GestureDetector(
                                onTap: () async {
                                  await watchlist.toggleWatchlist(stock.symbol);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isInWatchlist
                                              ? '已從自選股移除 ${stock.symbol}'
                                              : '已加入自選股 ${stock.symbol}',
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                },
                                child: Icon(
                                  isInWatchlist ? Icons.favorite : Icons.favorite_border,
                                  color: isInWatchlist ? Colors.red : Colors.grey,
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
        );
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Consumer<WatchlistProvider>(
        builder: (context, watchlist, child) {
          final isInWatchlist = watchlist.isInWatchlist(stock.symbol);
          return GestureDetector(
            onTap: () async {
              await watchlist.toggleWatchlist(stock.symbol);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isInWatchlist
                          ? '已從自選股移除 ${stock.symbol}'
                          : '已加入自選股 ${stock.symbol}',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
            child: Icon(
              isInWatchlist ? Icons.favorite : Icons.favorite_border,
              color: isInWatchlist ? Colors.red : Colors.grey,
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
