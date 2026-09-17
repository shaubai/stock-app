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

echo "==> flutter build web --release"
flutter build web --release

echo "==> Content-hashing main.dart.js"
dart run tool/hash_web_build.dart

echo "==> Done. Next: firebase deploy --only hosting"
