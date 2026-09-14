import 'package:flutter/foundation.dart' show kIsWeb;
import 'storage_service.dart';
import 'storage_service_mobile.dart';
import 'storage_service_web.dart';

/// Factory to create the appropriate StorageService based on the platform
///
/// Usage:
/// ```dart
/// final storageService = createStorageService();
/// await storageService.init();
/// ```
StorageService createStorageService() {
  if (kIsWeb) {
    return StorageServiceWeb();
  } else {
    return StorageServiceMobile();
  }
}
