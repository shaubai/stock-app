import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';

/// 比較兩個版本號字串（例如 "1.0.0" vs "1.0.1"），回傳 [latest] 是否比
/// [current] 新。只比較 major.minor.patch 三段；缺少的段落視為 0
/// （例如 "1.0" 視為 "1.0.0"）。
///
/// 抽成 top-level 純函式方便直接單元測試，不需要透過 UpdateService 或
/// mock 任何網路/平台相依。
bool isNewerVersion(String current, String latest) {
  final currentParts = current.split('.').map(int.parse).toList();
  final latestParts = latest.split('.').map(int.parse).toList();

  for (int i = 0; i < 3; i++) {
    final currentPart = i < currentParts.length ? currentParts[i] : 0;
    final latestPart = i < latestParts.length ? latestParts[i] : 0;

    if (latestPart > currentPart) return true;
    if (latestPart < currentPart) return false;
  }
  return false;
}

class UpdateService {
  // 版本資訊 API（可以放在 Firebase Hosting 或 GitHub）
  static const String versionCheckUrl =
      'https://nav-stock-analysis-app-16f6d.web.app/version.json';

  final http.Client _httpClient;

  UpdateService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  /// 檢查是否有新版本
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      // 取得當前版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 從伺服器取得最新版本資訊
      final response = await _httpClient.get(Uri.parse(versionCheckUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'] as String;
        final downloadUrl = data['downloadUrl'] as String;
        final releaseNotes = data['releaseNotes'] as String?;
        final forceUpdate = data['forceUpdate'] as bool? ?? false;

        // 比較版本號
        if (isNewerVersion(currentVersion, latestVersion)) {
          return UpdateInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes ?? '有新版本可用',
            forceUpdate: forceUpdate,
          );
        }
      }
      return null;
    } catch (e) {
      print('檢查更新失敗: $e');
      return null;
    }
  }
}

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate; // 是否強制更新

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    this.forceUpdate = false,
  });
}
