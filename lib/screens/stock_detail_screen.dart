import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stock.dart';
import '../models/historical_data.dart';
import '../services/stock_service.dart';
import '../providers/watchlist_provider.dart';
import '../widgets/stock_chart.dart';

class StockDetailScreen extends StatefulWidget {
  final Stock stock;

  const StockDetailScreen({
    super.key,
    required this.stock,
  });

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final StockService _stockService = StockService();
  List<HistoricalData> _historicalData = [];
  bool _isLoading = false;
  String _selectedPeriod = '1M'; // 1D, 5D, 1M, 3M, 1Y
  bool _showMA = false;

  @override
  void initState() {
    super.initState();
    _loadHistoricalData();
  }

  Future<void> _loadHistoricalData() async {
    setState(() => _isLoading = true);

    try {
      // 使用真實 API（所有平台）
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case '5D':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case '1M':
          startDate = now.subtract(const Duration(days: 30));
          break;
        case '3M':
          startDate = now.subtract(const Duration(days: 90));
          break;
        case '1Y':
          startDate = now.subtract(const Duration(days: 365));
          break;
        case '1D':
        default:
          startDate = now.subtract(const Duration(days: 1));
          break;
      }

      final data = await _stockService.getHistoricalData(
        widget.stock.symbol,
        widget.stock.market,
        startDate: startDate,
        endDate: now,
      );

      if (mounted) {
        setState(() {
          _historicalData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入歷史資料失敗: $e'),
          ),
        );
      }
    }
  }

  void _changePeriod(String period) {
    if (_selectedPeriod != period) {
      setState(() => _selectedPeriod = period);
      _loadHistoricalData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.stock.isPositive ? Colors.red : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.stock.symbol),
            Text(
              widget.stock.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer<WatchlistProvider>(
            builder: (context, watchlist, child) {
              final isInWatchlist = watchlist.isInWatchlist(widget.stock.symbol);
              return IconButton(
                icon: Icon(
                  isInWatchlist ? Icons.favorite : Icons.favorite_border,
                  color: isInWatchlist ? Colors.red : null,
                ),
                onPressed: () async {
                  await watchlist.toggleWatchlist(widget.stock.symbol);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isInWatchlist
                              ? '已從自選股移除 ${widget.stock.symbol}'
                              : '已加入自選股 ${widget.stock.symbol}',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 價格資訊區
          _buildPriceSection(color),

          // 時間範圍選擇
          _buildPeriodSelector(),

          // 圖表區
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _historicalData.isEmpty
                    ? const Center(child: Text('暫無歷史資料'))
                    : StockChart(
                        data: _historicalData,
                        showMA: _showMA,
                        maPeriods: const [5, 10, 20],
                      ),
          ),

          // MA 指標開關
          if (!_isLoading && _historicalData.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    '技術指標：',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('MA (5,10,20)'),
                    selected: _showMA,
                    onSelected: (selected) {
                      setState(() => _showMA = selected);
                    },
                  ),
                ],
              ),
            ),

          // 詳細資料區
          _buildDetailsSection(),
        ],
      ),
    );
  }

  Widget _buildPriceSection(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.05).round()),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.stock.formattedPrice,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
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
                  widget.stock.market,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                widget.stock.isPositive
                    ? Icons.arrow_drop_up
                    : Icons.arrow_drop_down,
                color: color,
                size: 24,
              ),
              Text(
                widget.stock.formattedChange,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.stock.formattedChangePercent,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    const periods = ['1D', '5D', '1M', '3M', '1Y'];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: periods.length,
        itemBuilder: (context, index) {
          final period = periods[index];
          final isSelected = _selectedPeriod == period;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(period),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) _changePeriod(period);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '詳細資料',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem('開盤', widget.stock.open.toStringAsFixed(2)),
              ),
              Expanded(
                child: _buildDetailItem('最高', widget.stock.high.toStringAsFixed(2)),
              ),
              Expanded(
                child: _buildDetailItem('最低', widget.stock.low.toStringAsFixed(2)),
              ),
              Expanded(
                child: _buildDetailItem('昨收', widget.stock.previousClose.toStringAsFixed(2)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  '成交量',
                  _formatVolume(widget.stock.volume),
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  '振幅',
                  '${((widget.stock.high - widget.stock.low) / widget.stock.previousClose * 100).toStringAsFixed(2)}%',
                ),
              ),
              const Expanded(child: SizedBox()),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatVolume(int volume) {
    if (volume >= 1000000000) {
      return '${(volume / 1000000000).toStringAsFixed(2)}B';
    } else if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(2)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(2)}K';
    }
    return volume.toString();
  }
}
