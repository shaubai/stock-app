// Post-processes `build/web` after `flutter build web` to content-hash
// main.dart.js, so it can be served with a long, immutable Cache-Control
// header (see firebase.json) without risking stale bundles after a deploy.
//
// Why this exists: Flutter's web build produces stable filenames
// (main.dart.js never changes name across releases), and the current
// `_flutter.loader.load()` API has no supported way to attach a
// cache-busting query string to the entrypoint URL — `entrypointBaseUrl` is
// path-joined with `mainJsPath`, not merged as a query string, and the only
// API that accepts a full custom URL (`loadEntrypoint`) is deprecated and
// skips renderer auto-selection (this app uses CanvasKit). See project
// discussion in `claude-notes/projects/Stock-App/開發進度.md`.
//
// So instead: rename the built main.dart.js to embed a content hash, and
// patch the one JSON field in flutter_bootstrap.js that names it
// (`_flutter.buildConfig.builds[].mainJsPath`). That field is plain
// generated JSON data, not minified logic, so this stays stable across
// Flutter SDK upgrades in a way that patching the minified loader body
// would not.
//
// Usage: run after `flutter build web --release`, before deploying:
//   dart run tool/hash_web_build.dart

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

void main() {
  final buildWebDir = Directory('build/web');
  final mainJsFile = File('${buildWebDir.path}/main.dart.js');
  final bootstrapFile = File('${buildWebDir.path}/flutter_bootstrap.js');

  if (!mainJsFile.existsSync()) {
    stderr.writeln(
      'error: ${mainJsFile.path} not found — run `flutter build web --release` first',
    );
    exit(1);
  }
  if (!bootstrapFile.existsSync()) {
    stderr.writeln('error: ${bootstrapFile.path} not found');
    exit(1);
  }

  final bytes = mainJsFile.readAsBytesSync();
  final hash = sha256.convert(bytes).toString().substring(0, 12);
  final hashedName = 'main.dart.$hash.js';
  final hashedFile = File('${buildWebDir.path}/$hashedName');

  mainJsFile.renameSync(hashedFile.path);
  print('renamed main.dart.js -> $hashedName');

  const needle = '"mainJsPath":"main.dart.js"';
  final replacement = '"mainJsPath":"$hashedName"';
  var bootstrapContent = bootstrapFile.readAsStringSync();

  final occurrences = needle.allMatches(bootstrapContent).length;
  if (occurrences != 1) {
    stderr.writeln(
      'error: expected exactly one occurrence of $needle in '
      '${bootstrapFile.path}, found $occurrences — Flutter SDK output format '
      'may have changed; update this script before deploying',
    );
    // Undo the rename so the build directory is left in a consistent state.
    hashedFile.renameSync(mainJsFile.path);
    exit(1);
  }

  bootstrapContent = bootstrapContent.replaceFirst(needle, replacement);
  bootstrapFile.writeAsStringSync(bootstrapContent);
  print('patched mainJsPath in flutter_bootstrap.js -> $hashedName');

  // Sanity check: the patched content must still be valid JSON on the
  // buildConfig line, so a malformed replacement fails loudly here rather
  // than silently shipping a broken bootstrap script.
  final buildConfigLine = bootstrapContent
      .split('\n')
      .firstWhere((line) => line.startsWith('_flutter.buildConfig = '));
  final jsonPart = buildConfigLine
      .substring('_flutter.buildConfig = '.length)
      .replaceFirst(RegExp(r';\s*$'), '');
  try {
    jsonDecode(jsonPart);
  } catch (e) {
    stderr.writeln('error: patched buildConfig is not valid JSON: $e');
    exit(1);
  }
  print('verified buildConfig JSON is still well-formed');
}
