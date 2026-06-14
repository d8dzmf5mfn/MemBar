#!/usr/bin/env bash
# Build MemBar.app in Release configuration and package it as a DMG.
#
# Output: MemBar.dmg in the current working directory.
#
# Usage:
#   ./scripts/build-dmg.sh                # uses default name MemBar.dmg
#   ./scripts/build-dmg.sh MyName.dmg     # custom DMG name
#   ./scripts/build-dmg.sh --skip-build   # reuse last xcodebuild output
#
# Requirements: Xcode 27+, macOS 15+

set -euo pipefail

# ----- Args -----
DMG_NAME="${1:-MemBar.dmg}"
SKIP_BUILD=0
if [[ "${1:-}" == "--skip-build" ]]; then
    SKIP_BUILD=1
    DMG_NAME="${2:-MemBar.dmg}"
fi

# ----- Paths -----
# Resolve repo root from this script's location (../)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
XCODEPROJ="$REPO_ROOT/Monitor/Monitor.xcodeproj"
SCHEME="Monitor"
CONFIG="Release"
BUILD_DIR="$REPO_ROOT/Monitor/build/Build/Products/$CONFIG"
APP_PATH="$BUILD_DIR/MemBar.app"
STAGE_DIR="$(mktemp -d -t membar-dmg)"
DMG_TMP="$(mktemp -d -t membar-dmg)"
DMG_OUTPUT="$REPO_ROOT/$DMG_NAME"

cleanup() {
    rm -rf "$STAGE_DIR" "$DMG_TMP"
}
trap cleanup EXIT

# ----- Build -----
if [[ $SKIP_BUILD -eq 0 ]]; then
    echo "==> Building $SCHEME ($CONFIG)..."
    cd "$REPO_ROOT/Monitor"
    xcodebuild \
        -project Monitor.xcodeproj \
        -scheme "$SCHEME" \
        -configuration "$CONFIG" \
        -destination 'platform=macOS' \
        -derivedDataPath build \
        clean build | tail -20
else
    echo "==> Skipping build (--skip-build), reusing $APP_PATH"
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "ERROR: Built app not found at $APP_PATH" >&2
    exit 1
fi

# ----- Stage -----
echo "==> Staging $APP_PATH into DMG layout..."
cp -R "$APP_PATH" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

# ----- Make DMG -----
echo "==> Creating DMG at $DMG_OUTPUT..."
# hdiutil create expects a directory. We build the read-write image, then
# convert to a compressed read-only image in one go.
# Layout: read-write first (lets hdiutil compute sizes), then convert.
RW_DMG="$DMG_TMP/rw.dmg"
hdiutil create -volname "MemBar" \
    -srcfolder "$STAGE_DIR" \
    -ov -format UDZO \
    "$DMG_OUTPUT"

# Cleanup intermediate
rm -f "$RW_DMG"

# ----- Report -----
if [[ -f "$DMG_OUTPUT" ]]; then
    SIZE=$(du -h "$DMG_OUTPUT" | cut -f1)
    echo ""
    echo "✓ Built $DMG_OUTPUT ($SIZE)"
    echo ""
    echo "Next: create a GitHub release and attach this DMG."
    echo "  gh release create v1.1.0 $DMG_OUTPUT --title 'MemBar v1.1.0' --notes '...'"
else
    echo "ERROR: DMG not produced" >&2
    exit 1
fi
