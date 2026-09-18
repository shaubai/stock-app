import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/web_update_checker.dart' show webAppVersion;

/// Displays the app's version number (e.g. "版本 1.1.0").
///
/// Web uses the same build-time constant the update checker compares
/// against (see web_update_checker.dart's doc comment for why
/// PackageInfo.fromPlatform() can't be used for "current version" on Web);
/// Android/iOS use PackageInfo.fromPlatform(), which reads the actual
/// installed package's version — reliable there since it's a local platform
/// API, not something fetched over the network.
class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12, color: Colors.grey[500]);

    if (kIsWeb) {
      if (webAppVersion.isEmpty) return const SizedBox.shrink();
      return Text('版本 $webAppVersion', style: style);
    }

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        if (version == null || version.isEmpty) {
          return const SizedBox.shrink();
        }
        return Text('版本 $version', style: style);
      },
    );
  }
}
