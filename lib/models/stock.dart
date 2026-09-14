class Stock {
  final String symbol;
  final String name;
  final double currentPrice;
  final double changeAmount;
  final double changePercent;
  final int volume;
  final double high;
  final double low;
  final double open;
  final double previousClose;
  final DateTime lastUpdate;
  final String market; // 'TW' for Taiwan, 'US' for US

  Stock({
    required this.symbol,
    required this.name,
    required this.currentPrice,
    required this.changeAmount,
    required this.changePercent,
    required this.volume,
    required this.high,
    required this.low,
    required this.open,
    required this.previousClose,
    required this.lastUpdate,
    required this.market,
  });

  factory Stock.fromJson(Map<String, dynamic> json, String market) {
    return Stock(
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? json['longName'] ?? '',
      currentPrice: (json['regularMarketPrice'] ?? json['price'] ?? 0).toDouble(),
      changeAmount: (json['regularMarketChange'] ?? json['change'] ?? 0).toDouble(),
      changePercent: (json['regularMarketChangePercent'] ?? json['changePercent'] ?? 0).toDouble(),
      volume: json['regularMarketVolume'] ?? json['volume'] ?? 0,
      high: (json['regularMarketDayHigh'] ?? json['high'] ?? 0).toDouble(),
      low: (json['regularMarketDayLow'] ?? json['low'] ?? 0).toDouble(),
      open: (json['regularMarketOpen'] ?? json['open'] ?? 0).toDouble(),
      previousClose: (json['regularMarketPreviousClose'] ?? json['previousClose'] ?? 0).toDouble(),
      lastUpdate: DateTime.now(),
      market: market,
    );
  }

  bool get isPositive => changeAmount >= 0;

  String get formattedPrice => currentPrice.toStringAsFixed(2);
  String get formattedChange => '${changeAmount >= 0 ? '+' : ''}${changeAmount.toStringAsFixed(2)}';
  String get formattedChangePercent => '${changeAmount >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%';
}
