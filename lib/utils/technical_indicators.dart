/// 移動平均線 (Moving Average)
///
/// 前 [period]-1 筆資料樣本不足，直接取當筆收盤價（與圖表既有行為一致，
/// 讓折線從第一筆資料就有值可畫，而非留白）。
List<double> calculateMA(List<double> prices, int period) {
  final ma = <double>[];
  for (var i = 0; i < prices.length; i++) {
    if (i < period - 1) {
      ma.add(prices[i]);
    } else {
      var sum = 0.0;
      for (var j = 0; j < period; j++) {
        sum += prices[i - j];
      }
      ma.add(sum / period);
    }
  }
  return ma;
}

/// 指數移動平均線 (Exponential Moving Average)
///
/// 為 MACD 計算的基礎。第一筆值直接採用收盤價作為種子（常見慣例）。
List<double> calculateEMA(List<double> prices, int period) {
  if (prices.isEmpty) return [];

  final ema = <double>[prices[0]];
  final multiplier = 2 / (period + 1);

  for (var i = 1; i < prices.length; i++) {
    final value = (prices[i] - ema[i - 1]) * multiplier + ema[i - 1];
    ema.add(value);
  }
  return ema;
}

/// 相對強弱指標 (Relative Strength Index)
///
/// 傳統定義使用 Wilder's smoothing（平滑移動平均），而非簡單移動平均。
/// 前 [period] 筆資料（含第 0 筆，因為漲跌幅需要前一日資料才能計算）
/// 沒有足夠樣本，回傳 50（中性值，避免顯示 0 造成誤解為「極度超賣」）。
List<double> calculateRSI(List<double> prices, {int period = 14}) {
  if (prices.length < 2) {
    return List.filled(prices.length, 50.0);
  }

  final rsi = List<double>.filled(prices.length, 50.0);
  final gains = <double>[];
  final losses = <double>[];

  for (var i = 1; i < prices.length; i++) {
    final change = prices[i] - prices[i - 1];
    gains.add(change > 0 ? change : 0);
    losses.add(change < 0 ? -change : 0);
  }

  if (gains.length < period) {
    return rsi; // 樣本不足，全部維持中性值
  }

  // 第一個 RSI 值：用前 period 筆漲跌幅的簡單平均作為種子
  var avgGain = gains.take(period).reduce((a, b) => a + b) / period;
  var avgLoss = losses.take(period).reduce((a, b) => a + b) / period;
  rsi[period] = _rsiFromAverages(avgGain, avgLoss);

  // 其餘用 Wilder's smoothing 遞迴更新
  for (var i = period; i < gains.length; i++) {
    avgGain = (avgGain * (period - 1) + gains[i]) / period;
    avgLoss = (avgLoss * (period - 1) + losses[i]) / period;
    rsi[i + 1] = _rsiFromAverages(avgGain, avgLoss);
  }

  return rsi;
}

double _rsiFromAverages(double avgGain, double avgLoss) {
  if (avgLoss == 0) return 100;
  final rs = avgGain / avgLoss;
  return 100 - (100 / (1 + rs));
}

/// MACD (指數平滑異同移動平均線)
///
/// 回傳三條序列：macd（快線 - 慢線）、signal（macd 的 EMA）、
/// histogram（macd - signal，柱狀圖）。
class MACDResult {
  final List<double> macd;
  final List<double> signal;
  final List<double> histogram;

  const MACDResult({
    required this.macd,
    required this.signal,
    required this.histogram,
  });
}

MACDResult calculateMACD(
  List<double> prices, {
  int fastPeriod = 12,
  int slowPeriod = 26,
  int signalPeriod = 9,
}) {
  if (prices.isEmpty) {
    return const MACDResult(macd: [], signal: [], histogram: []);
  }

  final emaFast = calculateEMA(prices, fastPeriod);
  final emaSlow = calculateEMA(prices, slowPeriod);
  final macdLine = List.generate(
    prices.length,
    (i) => emaFast[i] - emaSlow[i],
  );
  final signalLine = calculateEMA(macdLine, signalPeriod);
  final histogram = List.generate(
    prices.length,
    (i) => macdLine[i] - signalLine[i],
  );

  return MACDResult(macd: macdLine, signal: signalLine, histogram: histogram);
}

/// KD 隨機指標 (Stochastic Oscillator)
///
/// 需要每日的最高價/最低價/收盤價，而非單純收盤價序列。
/// K 值使用 RSV 的 Wilder 平滑（傳統台股看盤軟體慣例：K = 前日K*2/3 + RSV*1/3，
/// D = 前日D*2/3 + K*1/3），初始 K、D 皆設為 50。
class KDResult {
  final List<double> k;
  final List<double> d;

  const KDResult({required this.k, required this.d});
}

KDResult calculateKD(
  List<double> highs,
  List<double> lows,
  List<double> closes, {
  int period = 9,
}) {
  final length = closes.length;
  if (length == 0) {
    return const KDResult(k: [], d: []);
  }

  final kValues = List<double>.filled(length, 50.0);
  final dValues = List<double>.filled(length, 50.0);

  var prevK = 50.0;
  var prevD = 50.0;

  for (var i = 0; i < length; i++) {
    final windowStart = (i - period + 1).clamp(0, i);
    final windowHighs = highs.sublist(windowStart, i + 1);
    final windowLows = lows.sublist(windowStart, i + 1);

    final highestHigh = windowHighs.reduce((a, b) => a > b ? a : b);
    final lowestLow = windowLows.reduce((a, b) => a < b ? a : b);

    final rsv = highestHigh == lowestLow
        ? 50.0
        : (closes[i] - lowestLow) / (highestHigh - lowestLow) * 100;

    final k = prevK * 2 / 3 + rsv / 3;
    final d = prevD * 2 / 3 + k / 3;

    kValues[i] = k;
    dValues[i] = d;
    prevK = k;
    prevD = d;
  }

  return KDResult(k: kValues, d: dValues);
}
