import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/historical_data.dart';

class StockChart extends StatefulWidget {
  final List<HistoricalData> data;
  final bool showMA;
  final List<int> maPeriods;

  const StockChart({
    super.key,
    required this.data,
    this.showMA = false,
    this.maPeriods = const [5, 10, 20],
  });

  @override
  State<StockChart> createState() => _StockChartState();
}

class _StockChartState extends State<StockChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const Center(child: Text('無資料可顯示'));
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 16),
            child: _buildCandlestickChart(),
          ),
        ),
        if (_touchedIndex != null) _buildTooltip(),
      ],
    );
  }

  Widget _buildCandlestickChart() {
    final maxPrice = widget.data
        .map((d) => d.high)
        .reduce((a, b) => a > b ? a : b);
    final minPrice = widget.data
        .map((d) => d.low)
        .reduce((a, b) => a < b ? a : b);

    final priceRange = maxPrice - minPrice;
    final padding = priceRange * 0.1;

    return LineChart(
      LineChartData(
        minY: minPrice - padding,
        maxY: maxPrice + padding,
        minX: 0,
        maxX: widget.data.length.toDouble() - 1,
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            setState(() {
              if (response?.lineBarSpots != null &&
                  response!.lineBarSpots!.isNotEmpty) {
                _touchedIndex = response.lineBarSpots!.first.x.toInt();
              } else {
                _touchedIndex = null;
              }
            });
          },
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                const FlLine(color: Colors.blue, strokeWidth: 2),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: Colors.blue,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
              );
            }).toList();
          },
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: priceRange / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: priceRange / 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (widget.data.length / 5).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < widget.data.length) {
                  final date = widget.data[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${date.month}/${date.day}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // 主要價格線（連接收盤價）
          LineChartBarData(
            spots: widget.data.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.close);
            }).toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.withAlpha((255 * 0.3).round()),
                  Colors.blue.withAlpha(0),
                ],
              ),
            ),
          ),
          // MA 均線（如果啟用）
          if (widget.showMA) ..._buildMALines(),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: _buildCandlesticks(),
        ),
      ),
    );
  }

  List<LineChartBarData> _buildMALines() {
    final colors = [Colors.orange, Colors.purple, Colors.green];
    final lines = <LineChartBarData>[];

    for (int i = 0; i < widget.maPeriods.length; i++) {
      final period = widget.maPeriods[i];
      final maValues = _calculateMA(period);

      lines.add(
        LineChartBarData(
          spots: maValues.asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble(), entry.value);
          }).toList(),
          isCurved: true,
          color: colors[i % colors.length],
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          dashArray: [5, 5],
        ),
      );
    }

    return lines;
  }

  List<double> _calculateMA(int period) {
    List<double> ma = [];
    for (int i = 0; i < widget.data.length; i++) {
      if (i < period - 1) {
        ma.add(widget.data[i].close); // 不足期間使用當日收盤價
      } else {
        double sum = 0;
        for (int j = 0; j < period; j++) {
          sum += widget.data[i - j].close;
        }
        ma.add(sum / period);
      }
    }
    return ma;
  }

  List<HorizontalLine> _buildCandlesticks() {
    // 使用 ExtraLinesData 繪製蠟燭圖效果（簡化版）
    // 注意：fl_chart 沒有內建蠟燭圖，這裡用線條模擬
    return [];
  }

  Widget _buildTooltip() {
    if (_touchedIndex == null ||
        _touchedIndex! < 0 ||
        _touchedIndex! >= widget.data.length) {
      return const SizedBox();
    }

    final data = widget.data[_touchedIndex!];
    final isUp = data.close >= data.open;

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data.date.year}/${data.date.month}/${data.date.day}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTooltipItem('開', data.open, Colors.black),
              _buildTooltipItem('高', data.high, Colors.red),
              _buildTooltipItem('低', data.low, Colors.green),
              _buildTooltipItem(
                '收',
                data.close,
                isUp ? Colors.red : Colors.green,
              ),
              _buildTooltipItem('量', data.volume.toDouble(), Colors.black,
                  isVolume: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTooltipItem(String label, double value, Color color,
      {bool isVolume = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        Text(
          isVolume ? _formatVolume(value.toInt()) : value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatVolume(int volume) {
    if (volume >= 1000000000) {
      return '${(volume / 1000000000).toStringAsFixed(1)}B';
    } else if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    }
    return volume.toString();
  }
}

/// 成交量柱狀圖，獨立於 [StockChart]（股價折線圖）之外。
///
/// 股票詳情頁需要「選取 RSI/MACD/KD 時置換股價折線圖，但成交量圖保持
/// 顯示」，因此拆成獨立 widget，而非讓 StockChart 內部用參數控制顯示
/// 與否（那樣會讓呼叫端需要用兩個 StockChart 實例，反而容易重複渲染）。
class VolumeChart extends StatelessWidget {
  final List<HistoricalData> data;

  const VolumeChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();

    final maxVolume = data.map((d) => d.volume).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVolume.toDouble(),
          minY: 0,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _formatVolume(value.toInt()),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isUp = item.close >= item.open;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: item.volume.toDouble(),
                  color: isUp
                      ? Colors.red.withAlpha((255 * 0.5).round())
                      : Colors.green.withAlpha((255 * 0.5).round()),
                  width: 3,
                  borderRadius: BorderRadius.zero,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatVolume(int volume) {
    if (volume >= 1000000000) {
      return '${(volume / 1000000000).toStringAsFixed(1)}B';
    } else if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    }
    return volume.toString();
  }
}
