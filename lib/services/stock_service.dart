import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock.dart';
import '../models/historical_data.dart';

class StockService {
  // Taiwan stock API (使用證交所公開資訊)
  static const String _twStockApiBase = 'https://mis.twse.com.tw/stock/api';

  // US stock API (使用 Yahoo Finance API - 免費但有限制)
  // 注意：實際使用時可能需要申請 API key
  static const String _usStockApiBase = 'https://query1.finance.yahoo.com/v8/finance';

  /// 取得台股即時報價
  Future<Stock?> getTaiwanStock(String symbol) async {
    try {
      // 使用證交所 API
      final url = Uri.parse('$_twStockApiBase/getStockInfo.jsp?ex_ch=tse_$symbol.tw');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['msgArray'] != null && data['msgArray'].isNotEmpty) {
          final stockData = data['msgArray'][0];
          return _parseTaiwanStock(stockData, symbol);
        }
      }
      return null;
    } catch (e) {
      // TODO: 使用 logging 框架替代 print
      // print('Error fetching Taiwan stock $symbol: $e');
      return null;
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
  Stock _parseTaiwanStock(Map<String, dynamic> data, String symbol) {
    final currentPrice = double.tryParse(data['z'] ?? '0') ?? 0.0;
    final open = double.tryParse(data['o'] ?? '0') ?? 0.0;
    final high = double.tryParse(data['h'] ?? '0') ?? 0.0;
    final low = double.tryParse(data['l'] ?? '0') ?? 0.0;
    final previousClose = double.tryParse(data['y'] ?? '0') ?? 0.0;
    final volume = int.tryParse(data['v'] ?? '0') ?? 0;

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
    // 實作歷史資料抓取
    // 這裡簡化處理，實際使用時需要實作完整的歷史資料 API
    return [];
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
