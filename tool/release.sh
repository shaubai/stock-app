#!/bin/bash
# Automates the full release flow: version bump, release notes draft,
# Android APK + GitHub Release, Web build + Firebase deploy, commit + tag.
#
# ============================================================================
# ⚠️  SPECIAL CASE: this script auto-pushes to origin/main.
#
# Every other workflow in this project requires the user to explicitly say
# "push" before anything is pushed (see claude-notes/collaboration/workflow.md).
# This script is a deliberate, narrow exception the user asked for
# (2026/09/18): the release itself (APK on GitHub Releases, Web build on
# Firebase Hosting) is already public the moment this script runs, so holding
# the source commit back in local-only state would leave the repo out of
# sync with what's actually deployed. Do NOT copy this auto-push pattern into
# any other script or workflow without the user asking for it again.
# ============================================================================
#
# Usage:
#   ./tool/release.sh                  # patch bump (default), both platforms
#   ./tool/release.sh --minor          # minor bump
#   ./tool/release.sh --major          # major bump
#   ./tool/release.sh --web-only       # skip Android APK / GitHub Release
#   ./tool/release.sh --apk-only       # skip Web build / Firebase deploy
#   ./tool/release.sh --notes "..."    # skip the notes editor, use this text
#
# On any failure, the script stops immediately (set -e) and does not attempt
# to roll back already-completed steps (e.g. an already-committed pubspec.yaml
# bump, or an already-created GitHub Release) — surviving partial state is
# intentional so a human can decide what to do next rather than the script
# guessing. Re-running after fixing the issue will redo completed steps
# (bump/build are idempotent; gh release create and firebase deploy will
# simply overwrite), except a git commit already made — check `git log` and
# `git status` before re-running.

set -euo pipefail
cd "$(dirname "$0")/.."

# ---- Argument parsing ----
BUMP="patch"
PLATFORMS="both"
NOTES_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --minor) BUMP="minor"; shift ;;
    --major) BUMP="major"; shift ;;
    --web-only) PLATFORMS="web"; shift ;;
    --apk-only) PLATFORMS="apk"; shift ;;
    --notes) NOTES_ARG="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ---- Preflight ----
for cmd in jq gh flutter firebase; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "error: '$cmd' is required but not found on PATH." >&2
    exit 1
  fi
done

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is not clean. Commit or stash changes before releasing." >&2
  git status --short
  exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "error: releases must be cut from main (currently on '$CURRENT_BRANCH')" >&2
  exit 1
fi

# ---- Version bump ----
CURRENT_VERSION_LINE="$(grep '^version:' pubspec.yaml)"
CURRENT_VERSION="${CURRENT_VERSION_LINE#version: }"
CURRENT_NAME="${CURRENT_VERSION%%+*}"
CURRENT_BUILD="${CURRENT_VERSION##*+}"

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_NAME"

case "$BUMP" in
  patch) PATCH=$((PATCH + 1)) ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
esac

NEW_NAME="${MAJOR}.${MINOR}.${PATCH}"
NEW_BUILD=$((CURRENT_BUILD + 1))
NEW_VERSION="${NEW_NAME}+${NEW_BUILD}"

echo "==> Version: ${CURRENT_VERSION} -> ${NEW_VERSION} (${BUMP}, platforms: ${PLATFORMS})"

# ---- Release notes draft ----
LAST_TAG="$(git describe --tags --abbrev=0 2>/dev/null || echo "")"
if [[ -n "$NOTES_ARG" ]]; then
  RELEASE_NOTES="$NOTES_ARG"
else
  echo "==> Drafting release notes from commits since ${LAST_TAG:-the beginning}..."
  RANGE="${LAST_TAG:+$LAST_TAG..HEAD}"
  RANGE="${RANGE:-HEAD}"

  # [[:space:]]* rather than \s*: BSD sed (macOS default) treats \s as a
  # literal "s", not a whitespace class — using \s* here silently leaves a
  # double space after the bullet (verified: `fix: foo` -> `•  foo`).
  FEAT_LINES="$(git log $RANGE --pretty=format:'%s' | grep -E '^feat:' | sed -E 's/^feat:[[:space:]]*/• /' || true)"
  FIX_LINES="$(git log $RANGE --pretty=format:'%s' | grep -E '^fix:' | sed -E 's/^fix:[[:space:]]*/• /' || true)"

  DRAFT=""
  if [[ -n "$FEAT_LINES" ]]; then
    DRAFT="新增功能"$'\n'"$FEAT_LINES"
  fi
  if [[ -n "$FIX_LINES" ]]; then
    [[ -n "$DRAFT" ]] && DRAFT="$DRAFT"$'\n'
    DRAFT="${DRAFT}修正"$'\n'"$FIX_LINES"
  fi
  if [[ -z "$DRAFT" ]]; then
    DRAFT="（此版本沒有偵測到 feat:/fix: commit，請手動填寫發版說明）"
  fi

  echo ""
  echo "---- Draft release notes (from commit messages — please review/edit) ----"
  echo "$DRAFT"
  echo "---------------------------------------------------------------------------"
  echo ""
  echo "Press Enter to accept the draft as-is, or type replacement text"
  echo "(single line; use \\n for line breaks) and press Enter:"
  read -r USER_INPUT
  if [[ -n "$USER_INPUT" ]]; then
    RELEASE_NOTES="$(echo -e "$USER_INPUT")"
  else
    RELEASE_NOTES="$DRAFT"
  fi
fi

echo ""
echo "==> Final release notes:"
echo "$RELEASE_NOTES"
echo ""
read -p "Proceed with release v${NEW_NAME} using these notes? [y/N] " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborted. No changes made."
  exit 1
fi

# ---- Apply version bump ----
sed -i '' "s/^version: .*/version: ${NEW_VERSION}/" pubspec.yaml
echo "==> pubspec.yaml updated"

APK_DOWNLOAD_URL="https://github.com/shaubai/stock-app/releases/download/v${NEW_NAME}/app-release.apk"

# ---- Android APK + GitHub Release ----
if [[ "$PLATFORMS" == "both" || "$PLATFORMS" == "apk" ]]; then
  echo "==> Building release APK..."
  flutter build apk --release

  echo "==> Creating GitHub Release v${NEW_NAME}..."
  gh release create "v${NEW_NAME}" build/app/outputs/flutter-apk/app-release.apk \
    --title "v${NEW_NAME}" \
    --notes "$RELEASE_NOTES"
fi

# ---- Web build + Firebase deploy ----
if [[ "$PLATFORMS" == "both" || "$PLATFORMS" == "web" ]]; then
  # web/version.json's downloadUrl always points at the APK release, even on
  # a --web-only release — that field only matters to Android's in-app
  # update check, so it's harmless to leave pointed at the last real APK
  # version, but pointing at the current version number is misleading if no
  # matching APK was published. Only touch it when we actually built one.
  if [[ "$PLATFORMS" == "both" ]]; then
    # Built with jq rather than string-templated JSON: release notes can
    # contain quotes/backslashes/newlines, and jq is the only approach here
    # that escapes all of them correctly (verified: a hand-rolled sed-based
    # \n substitution produced syntactically invalid JSON that the app's
    # update check would have silently failed to parse).
    jq -n \
      --arg version "$NEW_NAME" \
      --arg downloadUrl "$APK_DOWNLOAD_URL" \
      --arg releaseNotes "$RELEASE_NOTES" \
      '{version: $version, downloadUrl: $downloadUrl, releaseNotes: $releaseNotes, forceUpdate: false}' \
      > web/version.json
    echo "==> web/version.json updated"

    # Keep the download page's version string and APK link in sync too.
    sed -i '' "s#最新版本：v[0-9.]*#最新版本：v${NEW_NAME}#" web/download/index.html
    sed -i '' "s#releases/download/v[0-9.]*/app-release.apk#releases/download/v${NEW_NAME}/app-release.apk#" web/download/index.html
    echo "==> web/download/index.html updated"
  fi

  echo "==> Building web (with cache-busting hash)..."
  ./tool/build_web.sh

  echo "==> Deploying to Firebase Hosting..."
  firebase deploy --only hosting
fi

# ---- Commit, tag, push ----
echo "==> Committing release..."
git add pubspec.yaml
[[ "$PLATFORMS" == "both" ]] && git add web/version.json web/download/index.html

git commit -m "chore: release v${NEW_NAME}

${RELEASE_NOTES}"

git tag "v${NEW_NAME}"

echo "==> Pushing to origin/main (including tag)..."
git push origin main
git push origin "v${NEW_NAME}"

echo ""
echo "✅ Released v${NEW_NAME}"
[[ "$PLATFORMS" == "both" || "$PLATFORMS" == "apk" ]] && echo "   APK: https://github.com/shaubai/stock-app/releases/tag/v${NEW_NAME}"
[[ "$PLATFORMS" == "both" || "$PLATFORMS" == "web" ]] && echo "   Web: https://nav-stock-analysis-app-16f6d.web.app"
