#!/bin/bash
# Builds the release web bundle and content-hashes main.dart.js for cache
# busting — the two steps always need to run together (see
# tool/hash_web_build.dart's doc comment for why), so this is the one
# command to run instead of remembering both.
#
# Usage: ./tool/build_web.sh
# Then:  firebase deploy --only hosting

set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Cleaning build/web (avoids stale hashed main.dart.*.js from a previous build)"
rm -rf build/web

# Baked in at build time via --dart-define so the Web update-checker (see
# lib/services/web_updater.dart / main.dart) has something to compare
# web/version.json's "version" field against. PackageInfo.fromPlatform()
# can't be used for this on Web — its web implementation itself fetches
# version.json for "the current version" (see package_info_plus_web.dart),
# so "current" and "latest" would always be identical and no update would
# ever be detected.
APP_VERSION="$(grep '^version:' pubspec.yaml | sed -E 's/^version: ([0-9.]+).*/\1/')"
echo "==> flutter build web --release (APP_VERSION=${APP_VERSION})"
flutter build web --release --dart-define=APP_VERSION="${APP_VERSION}"

echo "==> Content-hashing main.dart.js"
dart run tool/hash_web_build.dart

echo "==> Done. Next: firebase deploy --only hosting"
