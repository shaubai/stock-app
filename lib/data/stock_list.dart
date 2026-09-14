/// Taiwan stock list data
/// This file contains a curated list of popular Taiwan stocks
/// TODO: Can be expanded to fetch full list from TWSE API

class StockListItem {
  final String symbol;
  final String name;
  final String? category;

  const StockListItem({
    required this.symbol,
    required this.name,
    this.category,
  });
}

/// Popular Taiwan stocks list
/// Organized by market cap and liquidity
class TaiwanStockList {
  static const List<StockListItem> stocks = [
    // 科技股 - Technology
    StockListItem(symbol: '2330', name: '台積電', category: '半導體'),
    StockListItem(symbol: '2454', name: '聯發科', category: '半導體'),
    StockListItem(symbol: '2317', name: '鴻海', category: '電子'),
    StockListItem(symbol: '3711', name: '日月光投控', category: '半導體'),
    StockListItem(symbol: '2382', name: '廣達', category: '電子'),
    StockListItem(symbol: '2301', name: '光寶科', category: '電子'),
    StockListItem(symbol: '2357', name: '華碩', category: '電子'),
    StockListItem(symbol: '2303', name: '聯電', category: '半導體'),
    StockListItem(symbol: '3034', name: '聯詠', category: '半導體'),
    StockListItem(symbol: '2379', name: '瑞昱', category: '半導體'),
    StockListItem(symbol: '6505', name: '台塑化', category: '化工'),
    StockListItem(symbol: '2408', name: '南亞科', category: '半導體'),
    StockListItem(symbol: '3008', name: '大立光', category: '光學'),
    StockListItem(symbol: '2474', name: '可成', category: '電子'),
    StockListItem(symbol: '2324', name: '仁寶', category: '電子'),

    // 金融股 - Financial
    StockListItem(symbol: '2882', name: '國泰金', category: '金融'),
    StockListItem(symbol: '2881', name: '富邦金', category: '金融'),
    StockListItem(symbol: '2891', name: '中信金', category: '金融'),
    StockListItem(symbol: '2884', name: '玉山金', category: '金融'),
    StockListItem(symbol: '2886', name: '兆豐金', category: '金融'),
    StockListItem(symbol: '2892', name: '第一金', category: '金融'),
    StockListItem(symbol: '2883', name: '開發金', category: '金融'),
    StockListItem(symbol: '2885', name: '元大金', category: '金融'),
    StockListItem(symbol: '5880', name: '合庫金', category: '金融'),
    StockListItem(symbol: '2887', name: '台新金', category: '金融'),

    // 傳產股 - Traditional Industries
    StockListItem(symbol: '1301', name: '台塑', category: '塑膠'),
    StockListItem(symbol: '1303', name: '南亞', category: '塑膠'),
    StockListItem(symbol: '1326', name: '台化', category: '化工'),
    StockListItem(symbol: '2002', name: '中鋼', category: '鋼鐵'),
    StockListItem(symbol: '1216', name: '統一', category: '食品'),
    StockListItem(symbol: '2105', name: '正新', category: '橡膠'),
    StockListItem(symbol: '2103', name: '台橡', category: '橡膠'),
    StockListItem(symbol: '1102', name: '亞泥', category: '水泥'),
    StockListItem(symbol: '2207', name: '和泰車', category: '汽車'),
    StockListItem(symbol: '9904', name: '寶成', category: '紡織'),

    // 電信股 - Telecom
    StockListItem(symbol: '2412', name: '中華電', category: '電信'),
    StockListItem(symbol: '3045', name: '台灣大', category: '電信'),
    StockListItem(symbol: '4904', name: '遠傳', category: '電信'),

    // 航運股 - Shipping
    StockListItem(symbol: '2603', name: '長榮', category: '航運'),
    StockListItem(symbol: '2609', name: '陽明', category: '航運'),
    StockListItem(symbol: '2615', name: '萬海', category: '航運'),

    // 生技醫療 - Biotech & Healthcare
    StockListItem(symbol: '4770', name: '上品', category: '生技'),
    StockListItem(symbol: '6547', name: '高端疫苗', category: '生技'),
    StockListItem(symbol: '6446', name: '藥華藥', category: '生技'),
    StockListItem(symbol: '4142', name: '國光生', category: '生技'),

    // 綠能 - Green Energy
    StockListItem(symbol: '6505', name: '台塑化', category: '化工'),
    StockListItem(symbol: '3231', name: '緯創', category: '電子'),
    StockListItem(symbol: '6669', name: '緯穎', category: '電子'),

    // 營建 - Construction
    StockListItem(symbol: '2501', name: '國建', category: '營建'),
    StockListItem(symbol: '2505', name: '國揚', category: '營建'),
    StockListItem(symbol: '5522', name: '遠雄', category: '營建'),

    // 其他熱門股
    StockListItem(symbol: '2912', name: '統一超', category: '零售'),
    StockListItem(symbol: '2823', name: '中壽', category: '保險'),
    StockListItem(symbol: '2801', name: '彰銀', category: '金融'),
    StockListItem(symbol: '2820', name: '華票', category: '金融'),
    StockListItem(symbol: '2809', name: '京城銀', category: '金融'),
    StockListItem(symbol: '9910', name: '豐泰', category: '紡織'),
    StockListItem(symbol: '2385', name: '群光', category: '電子'),
    StockListItem(symbol: '2327', name: '國巨', category: '電子零件'),
    StockListItem(symbol: '3037', name: '欣興', category: '電子'),
    StockListItem(symbol: '6415', name: '矽力-KY', category: '半導體'),
  ];

  /// Search stocks by symbol or name
  static List<StockListItem> search(String query) {
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    return stocks.where((stock) {
      return stock.symbol.contains(query) ||
          stock.name.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Get stocks by category
  static List<StockListItem> getByCategory(String category) {
    return stocks.where((stock) => stock.category == category).toList();
  }

  /// Get all unique categories
  static List<String> getCategories() {
    final categories = stocks
        .map((stock) => stock.category)
        .where((cat) => cat != null)
        .cast<String>()
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  /// Get stock info by symbol
  static StockListItem? getBySymbol(String symbol) {
    try {
      return stocks.firstWhere((stock) => stock.symbol == symbol);
    } catch (e) {
      return null;
    }
  }
}
