import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/stock.dart';
import '../models/historical_data.dart';

class StockService {
  // Vercel API proxy (用於 Web 平台避免 CORS 問題)
  static const String _vercelApiBase = 'https://stock-api-one-beige.vercel.app/api';

  // Taiwan stock API (使用證交所公開資訊)
  static const String _twStockApiBase = 'https://mis.twse.com.tw/stock/api';

  // US stock API (使用 Yahoo Finance API - 免費但有限制)
  // 注意：實際使用時可能需要申請 API key
  static const String _usStockApiBase = 'https://query1.finance.yahoo.com/v8/finance';

  /// 取得台股即時報價
  Future<Stock?> getTaiwanStock(String symbol) async {
    try {
      final Uri url;

      if (kIsWeb) {
        // Web 平台使用 Vercel API proxy 避免 CORS 問題
        url = Uri.parse('$_vercelApiBase/stock?symbols=$symbol');
      } else {
        // Mobile/Desktop 平台直接使用 TWSE API
        url = Uri.parse('$_twStockApiBase/getStockInfo.jsp?ex_ch=tse_$symbol.tw');
      }

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['msgArray'] != null && data['msgArray'].isNotEmpty) {
          final stockData = data['msgArray'][0];
          return _parseTaiwanStock(stockData);
        }
      }
      return null;
    } catch (e) {
      // TODO: 使用 logging 框架替代 print
      // print('Error fetching Taiwan stock $symbol: $e');
      return null;
    }
  }

  /// 批量取得台股即時報價（更有效率）
  Future<List<Stock>> getTaiwanStocks(List<String> symbols) async {
    if (symbols.isEmpty) return [];

    try {
      final Uri url;

      if (kIsWeb) {
        // Web 平台使用 Vercel API proxy 避免 CORS 問題
        final symbolsParam = symbols.join(',');
        url = Uri.parse('$_vercelApiBase/stock?symbols=$symbolsParam');
      } else {
        // Mobile/Desktop 平台直接使用 TWSE API
        final exChList = symbols.map((s) => 'tse_$s.tw').join('|');
        url = Uri.parse('$_twStockApiBase/getStockInfo.jsp?ex_ch=$exChList');
      }

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['msgArray'] != null) {
          return (data['msgArray'] as List)
              .map((stockData) => _parseTaiwanStock(stockData))
              .toList();
        }
      }
      return [];
    } catch (e) {
      // TODO: 使用 logging 框架替代 print
      // print('Error fetching Taiwan stocks: $e');
      return [];
    }
  }

  /// 取得美股即時報價
  Future<Stock?> getUSStock(String symbol) async {
    try {
      // 使用 Yahoo Finance API
      final url = Uri.parse('$_usStockApiBase/quote?symbols=$symbol');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['quoteResponse']?['result'] != null &&
            data['quoteResponse']['result'].isNotEmpty) {
          final stockData = data['quoteResponse']['result'][0];
          return Stock.fromJson(stockData, 'US');
        }
      }
      return null;
    } catch (e) {
      // TODO: 使用 logging 框架替代 print
      // print('Error fetching US stock $symbol: $e');
      return null;
    }
  }

  /// 解析台股資料
  Stock _parseTaiwanStock(Map<String, dynamic> data) {
    // 從 API 回應提取資料
    // c: 股票代碼, n: 股票名稱, z: 成交價, y: 昨收, o: 開盤, h: 最高, l: 最低, v: 成交量(張)
    final symbol = (data['c'] ?? '').toString();
    final currentPrice = double.tryParse(data['z'] ?? '0') ?? 0.0;
    final open = double.tryParse(data['o'] ?? '0') ?? 0.0;
    final high = double.tryParse(data['h'] ?? '0') ?? 0.0;
    final low = double.tryParse(data['l'] ?? '0') ?? 0.0;
    final previousClose = double.tryParse(data['y'] ?? '0') ?? 0.0;
    // TWSE volume 是「張」，需要 * 1000 轉成股數
    final volumeInLots = int.tryParse(data['v'] ?? '0') ?? 0;
    final volume = volumeInLots * 1000;

    final changeAmount = currentPrice - previousClose;
    final changePercent = previousClose > 0 ? (changeAmount / previousClose * 100) : 0.0;

    return Stock(
      symbol: symbol,
      name: data['n'] ?? symbol,
      currentPrice: currentPrice,
      changeAmount: changeAmount,
      changePercent: changePercent,
      volume: volume,
      high: high,
      low: low,
      open: open,
      previousClose: previousClose,
      lastUpdate: DateTime.now(),
      market: 'TW',
    );
  }

  /// 取得歷史資料
  Future<List<HistoricalData>> getHistoricalData(
    String symbol,
    String market,
    {DateTime? startDate, DateTime? endDate}
  ) async {
    if (market == 'TW') {
      return _getTaiwanHistoricalData(symbol, startDate, endDate);
    } else if (market == 'US') {
      // TODO: 實作美股歷史資料（目前先返回空）
      return [];
    }
    return [];
  }

  /// 取得台股歷史資料
  Future<List<HistoricalData>> _getTaiwanHistoricalData(
    String symbol,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    try {
      // 使用證交所個股日成交資訊 API
      // 格式：https://www.twse.com.tw/rwd/zh/afterTrading/STOCK_DAY?date=YYYYMMDD&stockNo=SYMBOL&response=json

      final now = DateTime.now();
      final end = endDate ?? now;
      final start = startDate ?? end.subtract(const Duration(days: 30));

      final List<HistoricalData> allData = [];

      // TWSE API 一次只能查一個月的資料
      DateTime currentMonth = DateTime(start.year, start.month, 1);
      final endMonth = DateTime(end.year, end.month, 1);

      while (currentMonth.isBefore(endMonth) || currentMonth.isAtSameMomentAs(endMonth)) {
        final dateStr = '${currentMonth.year}${currentMonth.month.toString().padLeft(2, '0')}01';

        final Uri url;
        if (kIsWeb) {
          // Web 平台使用 Vercel API proxy 避免 CORS 問題
          url = Uri.parse('$_vercelApiBase/history?symbol=$symbol&date=$dateStr');
        } else {
          // Mobile/Desktop 平台直接使用 TWSE API
          url = Uri.parse(
            'https://www.twse.com.tw/rwd/zh/afterTrading/STOCK_DAY?date=$dateStr&stockNo=$symbol&response=json'
          );
        }

        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['stat'] == 'OK' && data['data'] != null) {
            final dataList = data['data'] as List;
            for (var item in dataList) {
              final historicalData = _parseTaiwanHistoricalData(item as List);
              if (historicalData != null &&
                  !historicalData.date.isBefore(start) &&
                  !historicalData.date.isAfter(end)) {
                allData.add(historicalData);
              }
            }
          }
        }

        // 移到下個月
        currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);

        // 避免過度頻繁請求
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 按日期排序（由舊到新）
      allData.sort((a, b) => a.date.compareTo(b.date));

      return allData;
    } catch (e) {
      // TODO: 使用 logging 框架替代 print
      // print('Error fetching Taiwan historical data: $e');
      return [];
    }
  }

  /// 解析台股歷史資料
  HistoricalData? _parseTaiwanHistoricalData(List<dynamic> item) {
    try {
      // item 格式：["日期", "成交股數", "成交金額", "開盤價", "最高價", "最低價", "收盤價", "漲跌價差", "成交筆數"]
      // 日期格式：111/01/03 (民國年/月/日)
      final dateStr = item[0] as String;
      final dateParts = dateStr.split('/');
      final year = int.parse(dateParts[0]) + 1911; // 民國轉西元
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);
      final date = DateTime(year, month, day);

      // 移除千分位逗號再轉換
      final open = double.parse((item[3] as String).replaceAll(',', ''));
      final high = double.parse((item[4] as String).replaceAll(',', ''));
      final low = double.parse((item[5] as String).replaceAll(',', ''));
      final close = double.parse((item[6] as String).replaceAll(',', ''));
      final volumeStr = (item[1] as String).replaceAll(',', '');
      final volume = int.parse(volumeStr);

      return HistoricalData(
        date: date,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
      );
    } catch (e) {
      // 解析失敗，返回 null
      return null;
    }
  }

  /// 計算技術指標 - 移動平均線 (MA)
  List<double> calculateMA(List<double> prices, int period) {
    List<double> ma = [];
    for (int i = 0; i < prices.length; i++) {
      if (i < period - 1) {
        ma.add(0);
      } else {
        double sum = 0;
        for (int j = 0; j < period; j++) {
          sum += prices[i - j];
        }
        ma.add(sum / period);
      }
    }
    return ma;
  }

  /// 取得多支股票（自選股）
  Future<List<Stock>> getStocks(List<Map<String, String>> symbols) async {
    List<Stock> stocks = [];

    for (var symbolInfo in symbols) {
      final symbol = symbolInfo['symbol']!;
      final market = symbolInfo['market']!;

      Stock? stock;
      if (market == 'TW') {
        stock = await getTaiwanStock(symbol);
      } else if (market == 'US') {
        stock = await getUSStock(symbol);
      }

      if (stock != null) {
        stocks.add(stock);
      }
    }

    return stocks;
  }
}
