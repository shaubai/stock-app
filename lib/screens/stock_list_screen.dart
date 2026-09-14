import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stock.dart';
import '../services/stock_service.dart';
import '../providers/watchlist_provider.dart';
import '../data/stock_list.dart';
import 'stock_detail_screen.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  final StockService _stockService = StockService();
  final TextEditingController _searchController = TextEditingController();
  List<Stock> _stocks = [];
  List<StockListItem> _searchResults = [];
  Stock? _searchedStock;
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isSearchingApi = false;

  // 自動更新相關
  Timer? _autoRefreshTimer;
  DateTime? _lastUpdateTime;
  static const Duration _refreshInterval = Duration(seconds: 30);

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
    _searchController.addListener(_onSearchChanged);
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (timer) {
      // 只在不搜尋時自動刷新
      if (!_isSearching && mounted) {
        _loadStocks(showLoading: false); // 靜默刷新，不顯示 loading
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _isSearching = query.isNotEmpty;
      _searchResults = TaiwanStockList.search(query);
      _searchedStock = null;
    });

    // 如果輸入看起來像股票代號（純數字），直接去 API 查詢
    if (query.isNotEmpty && RegExp(r'^\d+$').hasMatch(query)) {
      _searchStockFromApi(query);
    }
  }

  Future<void> _searchStockFromApi(String symbol) async {
    setState(() => _isSearchingApi = true);

    try {
      final stock = await _stockService.getTaiwanStock(symbol);
      if (mounted && _searchController.text.trim() == symbol) {
        setState(() {
          _searchedStock = stock;
          _isSearchingApi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearchingApi = false);
      }
    }
  }

  Future<void> _loadStocks({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }

    try {
      // 使用真實 API（所有平台）
      final stocks = await _stockService.getTaiwanStocks(_defaultTaiwanStocks);

      if (mounted) {
        setState(() {
          _stocks = stocks;
          _lastUpdateTime = DateTime.now();
          if (showLoading) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        if (showLoading) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('載入股票資料失敗: $e'),
            ),
          );
        }
        // 靜默刷新失敗時不顯示錯誤，避免打斷用戶
      }
    }
  }

  String _formatUpdateTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 10) {
      return '剛剛';
    } else if (difference.inSeconds < 60) {
      return '${difference.inSeconds}秒前';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分鐘前';
    } else {
      // 顯示具體時間
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _loadAndShowStock(String symbol) async {
    try {
      final stock = await _stockService.getTaiwanStock(symbol);
      if (stock != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StockDetailScreen(stock: stock),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法載入股票資料')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入失敗: $e')),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('股票看板'),
            if (_lastUpdateTime != null)
              Text(
                '更新: ${_formatUpdateTime(_lastUpdateTime!)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadStocks,
              tooltip: '手動刷新',
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜尋框
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜尋股票（代號或名稱）',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          // TODO: 預留位置 - 未來可加入 TabBar 切換「熱門」「分類」「漲幅排行」等
          // Example:
          // TabBar(
          //   tabs: [
          //     Tab(text: '熱門'),
          //     Tab(text: '分類'),
          //     Tab(text: '排行'),
          //   ],
          // ),

          // 內容區域
          Expanded(
            child: _isSearching
                ? _buildSearchResults()
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildStockList(isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final hasApiResult = _searchedStock != null;
    final hasSuggestions = _searchResults.isNotEmpty;
    final showEmpty = !hasApiResult && !hasSuggestions && !_isSearchingApi;

    if (showEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '找不到「${_searchController.text}」',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '請嘗試輸入股票代號（如：2330）或名稱',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        // API 查詢結果
        if (_isSearchingApi)
          const ListTile(
            leading: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('查詢中...'),
          ),

        if (hasApiResult)
          _buildStockResultTile(_searchedStock!),

        // 分隔線
        if (hasApiResult && hasSuggestions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '搜尋建議',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),
          ),

        // 本地搜尋建議
        ...(_searchResults.map((item) => _buildSuggestionTile(item))),
      ],
    );
  }

  Widget _buildStockResultTile(Stock stock) {
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
      tileColor: Colors.blue.withOpacity(0.05),
      leading: Icon(Icons.show_chart, color: Colors.blue[700]),
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
          Text(
            stock.name,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
      subtitle: Text(stock.market),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            stock.formattedPrice,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            stock.formattedChangePercent,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(StockListItem item) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        child: Text(
          item.symbol.substring(0, 1),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            item.symbol,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.name,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
      subtitle: item.category != null
          ? Text(
              item.category!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            )
          : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        _loadAndShowStock(item.symbol);
      },
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
