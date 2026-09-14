import 'dart:math';
import '../models/stock.dart';
import '../models/historical_data.dart';

class MockStockService {
  /// 取得模擬股票資料（用於展示UI）
  Future<List<Stock>> getMockStocks() async {
    // 模擬網路延遲
    await Future.delayed(const Duration(seconds: 1));

    return [
      Stock(
        symbol: '2330',
        name: '台積電',
        currentPrice: 585.0,
        changeAmount: 5.0,
        changePercent: 0.86,
        volume: 25000000,
        high: 588.0,
        low: 580.0,
        open: 582.0,
        previousClose: 580.0,
        lastUpdate: DateTime.now(),
        market: 'TW',
      ),
      Stock(
        symbol: '2317',
        name: '鴻海',
        currentPrice: 105.5,
        changeAmount: -1.5,
        changePercent: -1.40,
        volume: 35000000,
        high: 107.0,
        low: 105.0,
        open: 106.5,
        previousClose: 107.0,
        lastUpdate: DateTime.now(),
        market: 'TW',
      ),
      Stock(
        symbol: '2454',
        name: '聯發科',
        currentPrice: 890.0,
        changeAmount: 15.0,
        changePercent: 1.71,
        volume: 8000000,
        high: 895.0,
        low: 875.0,
        open: 880.0,
        previousClose: 875.0,
        lastUpdate: DateTime.now(),
        market: 'TW',
      ),
      Stock(
        symbol: 'AAPL',
        name: 'Apple Inc.',
        currentPrice: 178.25,
        changeAmount: 2.15,
        changePercent: 1.22,
        volume: 55000000,
        high: 179.50,
        low: 176.80,
        open: 177.00,
        previousClose: 176.10,
        lastUpdate: DateTime.now(),
        market: 'US',
      ),
      Stock(
        symbol: 'GOOGL',
        name: 'Alphabet Inc.',
        currentPrice: 142.60,
        changeAmount: -0.85,
        changePercent: -0.59,
        volume: 28000000,
        high: 144.00,
        low: 142.20,
        open: 143.50,
        previousClose: 143.45,
        lastUpdate: DateTime.now(),
        market: 'US',
      ),
      Stock(
        symbol: 'TSLA',
        name: 'Tesla Inc.',
        currentPrice: 248.50,
        changeAmount: 8.75,
        changePercent: 3.65,
        volume: 98000000,
        high: 250.00,
        low: 240.00,
        open: 242.50,
        previousClose: 239.75,
        lastUpdate: DateTime.now(),
        market: 'US',
      ),
      Stock(
        symbol: 'MSFT',
        name: 'Microsoft Corp.',
        currentPrice: 418.30,
        changeAmount: 3.20,
        changePercent: 0.77,
        volume: 22000000,
        high: 420.00,
        low: 415.50,
        open: 416.80,
        previousClose: 415.10,
        lastUpdate: DateTime.now(),
        market: 'US',
      ),
      Stock(
        symbol: '2412',
        name: '中華電',
        currentPrice: 123.5,
        changeAmount: 0.5,
        changePercent: 0.41,
        volume: 12000000,
        high: 124.0,
        low: 122.5,
        open: 123.0,
        previousClose: 123.0,
        lastUpdate: DateTime.now(),
        market: 'TW',
      ),
    ];
  }

  /// 取得模擬歷史資料
  Future<List<HistoricalData>> getMockHistoricalData(
    String symbol,
    String market,
    String period,
  ) async {
    // 模擬網路延遲
    await Future.delayed(const Duration(milliseconds: 500));

    // 根據時間範圍決定資料點數量
    int dataPoints;
    switch (period) {
      case '1D':
        dataPoints = 78; // 每 5 分鐘一個點，6.5 小時
        break;
      case '5D':
        dataPoints = 5 * 78;
        break;
      case '1M':
        dataPoints = 20; // 20 個交易日
        break;
      case '3M':
        dataPoints = 60;
        break;
      case '1Y':
        dataPoints = 240;
        break;
      default:
        dataPoints = 20;
    }

    // 取得該股票的當前價格作為基準
    final stocks = await getMockStocks();
    final stock = stocks.firstWhere(
      (s) => s.symbol == symbol && s.market == market,
      orElse: () => stocks.first,
    );

    final basePrice = stock.previousClose;
    final random = Random(symbol.hashCode); // 使用固定種子確保資料一致

    List<HistoricalData> data = [];
    DateTime currentDate = DateTime.now();

    // 根據期間調整時間間隔
    Duration interval;
    if (period == '1D') {
      interval = const Duration(minutes: 5);
      currentDate = DateTime(currentDate.year, currentDate.month, currentDate.day, 9, 0);
    } else {
      interval = const Duration(days: 1);
      currentDate = currentDate.subtract(Duration(days: dataPoints));
    }

    double price = basePrice * (0.9 + random.nextDouble() * 0.1); // 起始價格在基準價的 90%-100%

    for (int i = 0; i < dataPoints; i++) {
      // 生成隨機波動
      final volatility = 0.02; // 2% 波動
      final change = (random.nextDouble() - 0.5) * 2 * volatility;

      final open = price;
      final close = price * (1 + change);
      final high = max(open, close) * (1 + random.nextDouble() * 0.01);
      final low = min(open, close) * (1 - random.nextDouble() * 0.01);
      final volume = (stock.volume * (0.5 + random.nextDouble())).toInt();

      data.add(HistoricalData(
        date: currentDate,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
      ));

      price = close;
      currentDate = currentDate.add(interval);

      // 跳過週末（如果是日線資料）
      if (interval.inDays >= 1) {
        while (currentDate.weekday == DateTime.saturday ||
            currentDate.weekday == DateTime.sunday) {
          currentDate = currentDate.add(const Duration(days: 1));
        }
      }
    }

    // 調整最後一個資料點為當前價格
    if (data.isNotEmpty) {
      final lastData = data.last;
      final currentPrice = stock.currentPrice;
      data[data.length - 1] = HistoricalData(
        date: lastData.date,
        open: lastData.open,
        high: max(lastData.open, currentPrice) * 1.005,
        low: min(lastData.open, currentPrice) * 0.995,
        close: currentPrice,
        volume: lastData.volume,
      );
    }

    return data;
  }
}
