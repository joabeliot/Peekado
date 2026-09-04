#!/usr/bin/env bash
# Build a signed Release and install Peek-A-Do to /Applications, then relaunch.
set -euo pipefail

cd "$(dirname "$0")/.."

APP="PeekADo.app"
BUILD_DIR="build"
PRODUCT="${BUILD_DIR}/Build/Products/Release/${APP}"
DEST="/Applications/${APP}"

echo "==> Building Release..."
rm -rf "${BUILD_DIR}"
xcodebuild -project PeekADo.xcodeproj -scheme PeekADo -configuration Release \
  -derivedDataPath "${BUILD_DIR}" -destination 'generic/platform=macOS' build \
  | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" || true

if [ ! -d "${PRODUCT}" ]; then
  echo "ERROR: build product not found at ${PRODUCT}" >&2
  exit 1
fi

echo "==> Quitting any running instance..."
osascript -e 'quit app "PeekADo"' 2>/dev/null || true
pkill -x PeekADo 2>/dev/null || true
sleep 1

echo "==> Installing to ${DEST}..."
rm -rf "${DEST}"
cp -R "${PRODUCT}" /Applications/

echo "==> Launching..."
open "${DEST}"

echo "Done. Look for the checklist icon in the menu bar."
echo "First run: gear -> paste your Notion token, then flip 'Start at login'."
