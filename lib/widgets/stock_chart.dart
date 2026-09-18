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

  // MA 線顏色，圖例與實際畫線共用同一份定義，避免兩處顏色對不上。
  // 對齊 Yahoo 財經慣例配色（MA5 淡藍／MA10 紫／MA20 橘紅）。
  static const List<Color> _maColors = [Color(0xFF42A5F5), Color(0xFF9C27B0), Color(0xFFFF5722)];

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const Center(child: Text('無資料可顯示'));
    }

    return Column(
      children: [
        if (widget.showMA) _buildMALegend(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 16),
            child: _buildChart(),
          ),
        ),
        if (_touchedIndex != null) _buildTooltip(),
      ],
    );
  }

  /// K 線（蠟燭圖）與 MA 疊加線分屬 fl_chart 兩種不同的圖表類型
  /// （CandlestickChart / LineChart），無法像單一 LineChart 那樣把
  /// 多條線放進同一份 lineBarsData 裡混搭，因此用 Stack 疊放兩層，
  /// 並讓兩層共用完全相同的 minX/maxX/minY/maxY，確保座標對齊。
  /// MA 那層關閉自己的網格線／座標軸／背景，只畫線本身。
  Widget _buildChart() {
    final maxPrice = widget.data
        .map((d) => d.high)
        .reduce((a, b) => a > b ? a : b);
    final minPrice = widget.data
        .map((d) => d.low)
        .reduce((a, b) => a < b ? a : b);

    final priceRange = maxPrice - minPrice;
    final padding = priceRange * 0.1;
    final minY = minPrice - padding;
    final maxY = maxPrice + padding;
    final minX = 0.0;
    final maxX = widget.data.length.toDouble() - 1;

    return Stack(
      children: [
        // 三層由下到上：座標軸／網格線（純背景，不畫任何資料）→ MA 線
        // （疊加指標，可被 K 線蓋住）→ K 線本體（蠟燭圖，永遠最上層可見）。
        // fl_chart 沒有辦法把「網格線」從單一 CandlestickChart/LineChart
        // widget 中抽出來單獨排序，所以改用一個 lineBarsData 為空的
        // LineChart 專門畫座標軸與網格線；K 線層與 MA 層各自關閉自己的
        // gridData/titlesData，避免三層各畫一份互相打架。
        IgnorePointer(
          child: _buildAxisLayer(minX: minX, maxX: maxX, minY: minY, maxY: maxY, priceRange: priceRange),
        ),
        if (widget.showMA)
          IgnorePointer(
            // MA 線本身不接收觸控——K 線層已經處理點擊顯示 tooltip，
            // 疊上去的這層若也吃觸控事件，會擋住底下的 CandlestickChart。
            child: _buildMALayer(minX: minX, maxX: maxX, minY: minY, maxY: maxY),
          ),
        _buildCandlestickLayer(minX: minX, maxX: maxX, minY: minY, maxY: maxY),
      ],
    );
  }

  /// 只畫座標軸與網格線的背景層，不畫任何蠟燭／線段資料（用 LineChart
  /// 而非 CandlestickChart 承載，見呼叫端註解）。
  Widget _buildAxisLayer({
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
    required double priceRange,
  }) {
    // 用 LineChart（lineBarsData 留空）取代 CandlestickChart 畫座標軸／
    // 網格線：只是借用 fl_chart 圖表元件的座標軸繪製能力，不需要蠟燭圖
    // 才有的渲染器／觸控資料結構，LineChart 是專案裡本來就在用的最
    // 輕量選項，沒有理由為了「不畫任何東西」載入更重的元件。
    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
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
      ),
    );
  }

  Widget _buildMALayer({
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
  }) {
    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: _buildMALines(),
      ),
    );
  }

  Widget _buildCandlestickLayer({
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
  }) {
    return CandlestickChart(
      CandlestickChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        candlestickSpots: widget.data.asMap().entries.map((entry) {
          final d = entry.value;
          return CandlestickSpot(
            x: entry.key.toDouble(),
            open: d.open,
            high: d.high,
            low: d.low,
            close: d.close,
          );
        }).toList(),
        // 紅漲綠跌（台股慣例），對齊 VolumeChart／_buildTooltip 既有配色。
        candlestickPainter: DefaultCandlestickPainter(
          candlestickStyleProvider: (spot, index) {
            final color = spot.isUp ? Colors.red : Colors.green;
            return CandlestickStyle(
              lineColor: color,
              lineWidth: 1,
              bodyStrokeColor: color,
              bodyStrokeWidth: 0,
              bodyFillColor: color,
              bodyWidth: 4,
              bodyRadius: 0,
            );
          },
        ),
        candlestickTouchData: CandlestickTouchData(
          // 關閉內建浮動 tooltip：同一個理由是 2026/09/17 修過的折線圖
          // tooltip 遮擋問題——自訂的 _buildTooltip() 顯示在圖表下方，
          // 不會蓋住技術指標選項列。
          handleBuiltInTouches: false,
          touchCallback: (FlTouchEvent event, CandlestickTouchResponse? response) {
            setState(() {
              _touchedIndex = response?.touchedSpot?.spotIndex;
            });
          },
        ),
        // 座標軸與網格線交給 _buildAxisLayer 那層畫，這裡關閉避免
        // 兩層都畫一次（K 線層疊在最上層，重複的網格線只會蓋住 MA）。
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildMALegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (int i = 0; i < widget.maPeriods.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 3,
                    color: _maColors[i % _maColors.length],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'MA${widget.maPeriods[i]}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<LineChartBarData> _buildMALines() {
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
          color: _maColors[i % _maColors.length],
          barWidth: 1.0,
          dotData: const FlDotData(show: false),
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

  Widget _buildTooltip() {
    if (_touchedIndex == null ||
        _touchedIndex! < 0 ||
        _touchedIndex! >= widget.data.length) {
      return const SizedBox();
    }

    final data = widget.data[_touchedIndex!];
    // 與 CandlestickSpot.isUp（close > open，嚴格大於）保持一致，避免
    // 平盤（收盤=開盤）時蠟燭圖顏色與 tooltip 文字顏色矛盾。
    final isUp = data.close > data.open;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${data.date.year}/${data.date.month}/${data.date.day}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => setState(() => _touchedIndex = null),
                child: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
              ),
            ],
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
