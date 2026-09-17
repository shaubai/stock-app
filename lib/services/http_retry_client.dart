import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

/// 帶 timeout、重試與指數退避的 HTTP GET 輔助函式。
///
/// 適用於本 App 呼叫的第三方公開 API（證交所、Yahoo Finance 等）——
/// 這些服務沒有 SLA 保證，偶發逾時或限流是預期中的情況，因此重試
/// 邏輯集中在這裡，供 StockService 的各個方法共用。
class HttpRetryClient {
  static const Duration _defaultTimeout = Duration(seconds: 10);
  static const int _maxAttempts = 3;
  static const Duration _baseDelay = Duration(seconds: 1);

  final Random _random;
  final http.Client _client;
  final Future<void> Function(Duration) _delay;
  final Duration _timeout;

  HttpRetryClient({
    Random? random,
    http.Client? client,
    Future<void> Function(Duration)? delay,
    Duration? timeout,
  })  : _random = random ?? Random(),
        _client = client ?? http.Client(),
        _delay = delay ?? ((d) => Future.delayed(d)),
        _timeout = timeout ?? _defaultTimeout;

  /// 執行 GET 請求，逾時或可重試的失敗會自動重試（指數退避 + 抖動）。
  ///
  /// 可重試的情況：連線逾時、網路層錯誤（如 SocketException）、
  /// HTTP 429（限流）、HTTP 5xx（伺服器端暫時性錯誤）。
  /// 不可重試：其他 4xx（如 404，重試也不會成功）。
  ///
  /// 重試次數用盡或遇到不可重試的錯誤時，回傳最後一次的 [http.Response]
  /// （若是逾時/連線層錯誤導致完全沒有回應，則拋出原始例外）。
  Future<http.Response> get(Uri url) async {
    Object? lastError;
    http.Response? lastResponse;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await _client.get(url).timeout(_timeout);

        if (!_isRetryableStatus(response.statusCode)) {
          return response;
        }

        lastResponse = response;
        if (attempt == _maxAttempts) break;

        await _delay(_delayForAttempt(attempt, response));
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt == _maxAttempts) break;
        await _delay(_delayForAttempt(attempt, null));
      } on SocketException catch (e) {
        lastError = e;
        if (attempt == _maxAttempts) break;
        await _delay(_delayForAttempt(attempt, null));
      }
    }

    if (lastResponse != null) return lastResponse;
    throw lastError ?? StateError('HttpRetryClient: unreachable');
  }

  bool _isRetryableStatus(int statusCode) {
    return statusCode == 429 || (statusCode >= 500 && statusCode < 600);
  }

  Duration _delayForAttempt(int attempt, http.Response? response) {
    // 429 回應若帶 Retry-After（秒數），優先採用伺服器指定的等待時間
    final retryAfter = response?.headers['retry-after'];
    if (retryAfter != null) {
      final seconds = int.tryParse(retryAfter);
      if (seconds != null) return Duration(seconds: seconds);
    }

    // 指數退避：1s, 2s, 4s... 加上 0-300ms 隨機抖動，避免多個請求同時重試
    final exponential = _baseDelay * (1 << (attempt - 1));
    final jitter = Duration(milliseconds: _random.nextInt(300));
    return exponential + jitter;
  }
}
