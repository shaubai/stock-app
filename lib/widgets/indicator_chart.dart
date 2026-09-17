import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/historical_data.dart';
import '../utils/technical_indicators.dart';

/// 可用的震盪指標子圖表類型。
///
/// 用 enum（而非各自獨立的 bool 開關）讓「目前選中哪些指標」可以用
/// `Set<IndicatorType>` 表示，UI 端無論單選或多選都只是同一份資料的
/// 不同互動方式，繪製端一律走同一條迴圈渲染每個選中的類型。
enum IndicatorType {
  rsi('RSI'),
  macd('MACD'),
  kd('KD');

  final String label;
  const IndicatorType(this.label);
}

/// 單一震盪指標的子圖表（RSI / MACD / KD）。
///
/// 每種指標各自獨立渲染，呼叫端依需要顯示的 [IndicatorType] 集合逐一
/// 建立多個 IndicatorChart 並排列（目前 UI 限制一次只選一個，但這個
/// widget 本身不假設呼叫端只會顯示一個）。
class IndicatorChart extends StatelessWidget {
  final IndicatorType type;
  final List<HistoricalData> data;

  const IndicatorChart({
    super.key,
    required this.type,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();

    switch (type) {
      case IndicatorType.rsi:
        return _RSIChart(data: data);
      case IndicatorType.macd:
        return _MACDChart(data: data);
      case IndicatorType.kd:
        return _KDChart(data: data);
    }
  }
}

class _RSIChart extends StatelessWidget {
  final List<HistoricalData> data;
  const _RSIChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final closes = data.map((d) => d.close).toList();
    final rsi = calculateRSI(closes);

    return _OscillatorChartFrame(
      label: 'RSI (14)',
      minY: 0,
      maxY: 100,
      referenceLines: const [
        _ReferenceLine(value: 70, color: Colors.red),
        _ReferenceLine(value: 30, color: Colors.green),
      ],
      lines: [
        _IndicatorLine(values: rsi, color: Colors.purple),
      ],
    );
  }
}

class _KDChart extends StatelessWidget {
  final List<HistoricalData> data;
  const _KDChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final highs = data.map((d) => d.high).toList();
    final lows = data.map((d) => d.low).toList();
    final closes = data.map((d) => d.close).toList();
    final kd = calculateKD(highs, lows, closes);

    return _OscillatorChartFrame(
      label: 'KD (9)',
      minY: 0,
      maxY: 100,
      referenceLines: const [
        _ReferenceLine(value: 80, color: Colors.red),
        _ReferenceLine(value: 20, color: Colors.green),
      ],
      lines: [
        _IndicatorLine(values: kd.k, color: Colors.blue, label: 'K'),
        _IndicatorLine(values: kd.d, color: Colors.orange, label: 'D'),
      ],
    );
  }
}

class _MACDChart extends StatelessWidget {
  final List<HistoricalData> data;
  const _MACDChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final closes = data.map((d) => d.close).toList();
    final macd = calculateMACD(closes);

    final allValues = [...macd.macd, ...macd.signal, ...macd.histogram];
    final maxAbs = allValues.isEmpty
        ? 1.0
        : allValues.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
    final bound = maxAbs == 0 ? 1.0 : maxAbs * 1.1;

    return _OscillatorChartFrame(
      label: 'MACD (12,26,9)',
      minY: -bound,
      maxY: bound,
      referenceLines: const [_ReferenceLine(value: 0, color: Colors.grey)],
      lines: [
        _IndicatorLine(values: macd.macd, color: Colors.blue, label: 'MACD'),
        _IndicatorLine(values: macd.signal, color: Colors.orange, label: 'Signal'),
        _IndicatorLine(values: macd.histogram, color: Colors.grey, label: 'Histogram'),
      ],
    );
  }
}

class _ReferenceLine {
  final double value;
  final Color color;
  const _ReferenceLine({required this.value, required this.color});
}

class _IndicatorLine {
  final List<double> values;
  final Color color;
  final String? label;
  const _IndicatorLine({required this.values, required this.color, this.label});
}

/// 震盪指標子圖表的共用外框：標籤、圖例、水平參考線、折線。
class _OscillatorChartFrame extends StatelessWidget {
  final String label;
  final double minY;
  final double maxY;
  final List<_ReferenceLine> referenceLines;
  final List<_IndicatorLine> lines;

  const _OscillatorChartFrame({
    required this.label,
    required this.minY,
    required this.maxY,
    required this.referenceLines,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox();
    final length = lines.first.values.length;
    if (length == 0) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 12),
              ...lines.where((l) => l.label != null).map(
                    (l) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 8, height: 8, color: l.color),
                          const SizedBox(width: 4),
                          Text(
                            l.label!,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 8),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: length.toDouble() - 1,
                minY: minY,
                maxY: maxY,
                // 關閉觸控互動：fl_chart 預設開啟時，點擊會彈出浮動數值
                // 框，其位置計算不考慮圖表外部元件，曾蓋住股票詳情頁
                // 上方的技術指標選項列（2026/09/17 使用者回報，股價圖表
                // 已修正）。這些子圖表目前沒有實作對應的固定式 tooltip，
                // 直接關閉觸控比另外做一套更省事、也不會有相同問題。
                lineTouchData: const LineTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: (maxY - minY) / 4,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(0),
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: referenceLines
                      .map((r) => HorizontalLine(
                            y: r.value,
                            color: r.color.withAlpha((255 * 0.5).round()),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ))
                      .toList(),
                ),
                lineBarsData: lines
                    .map(
                      (l) => LineChartBarData(
                        spots: l.values
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value))
                            .toList(),
                        isCurved: false,
                        color: l.color,
                        barWidth: 1.5,
                        dotData: const FlDotData(show: false),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
