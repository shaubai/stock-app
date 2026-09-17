import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/stock.dart';
import '../services/stock_service.dart';

/// Provider for the stock board's data: the default watched stock list,
/// the TAIEX index, loading state, and background auto-refresh.
///
/// This holds the stock-board data itself, distinct from WatchlistProvider
/// (which only holds the set of symbols a user has favorited).
class StockProvider with ChangeNotifier {
  final StockService _stockService;

  // 台股加權指數代碼
  static const String _taiwanIndexSymbol = 't00';

  static const Duration _refreshInterval = Duration(seconds: 30);

  // 預設顯示的台股清單（熱門股票）
  // 做為 id-list（見 loadStocks）無法取得時的 fallback，確保股票看板
  // 不會因遠端清單服務中斷而空白
  static const List<String> defaultTaiwanStocks = [
    '2330', // 台積電
    '2317', // 鴻海
    '2454', // 聯發科
    '2308', // 台達電
    '2412', // 中華電
    '2882', // 國泰金
    '2881', // 富邦金
    '2303', // 聯電
  ];

  List<Stock> _stocks = [];
  Stock? _taiwanIndex;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdateTime;
  Timer? _autoRefreshTimer;

  // 本次 App session 快取的遠端股票代碼清單。id-list 一天只由 server
  // 端更新一次（見 stock-api 的 cron job），沒必要跟著 30 秒的自動
  // 報價刷新一起重打；成功拿到一次後，本次 session 就重複使用。
  // 若啟動時取得失敗，維持 null，讓後續每次 loadStocks 繼續嘗試——
  // 避免單純的暫時性網路錯誤讓整個 session 卡死在 fallback 清單。
  List<String>? _cachedIdList;

  StockProvider({StockService? stockService})
      : _stockService = stockService ?? StockService();

  List<Stock> get stocks => _stocks;
  Stock? get taiwanIndex => _taiwanIndex;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  /// Start (or restart) periodic background refresh.
  ///
  /// Safe to call multiple times — cancels any existing timer first, so
  /// screens can call this from initState without worrying about the
  /// provider outliving a single screen instance.
  void startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (timer) {
      loadStocks(showLoading: false);
    });
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> loadStocks({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      // 股票看板清單優先使用 stock-api 的遠端 id-list（每日更新的完整
      // 代碼清單），本次 session 內快取重用（見 _cachedIdList）；取得
      // 失敗（服務未部署、網路錯誤等）時 fallback 回內建的固定熱門股
      // 清單，確保看板不會空白
      if (_cachedIdList == null) {
        final remoteIdList = await _stockService.getIdList();
        if (remoteIdList != null && remoteIdList.isNotEmpty) {
          _cachedIdList = remoteIdList;
        }
      }
      final symbols = _cachedIdList ?? defaultTaiwanStocks;

      final results = await Future.wait([
        _stockService.getTaiwanStocks(symbols),
        _stockService.getTaiwanStock(_taiwanIndexSymbol),
      ]);
      _stocks = results[0] as List<Stock>;
      _taiwanIndex = (results[1] as Stock?) ?? _taiwanIndex;
      _lastUpdateTime = DateTime.now();
      _error = null;
    } catch (e) {
      // 靜默刷新失敗時不設定 error，避免打斷用戶正在看的既有資料
      if (showLoading) {
        _error = '載入股票資料失敗: $e';
      }
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}
