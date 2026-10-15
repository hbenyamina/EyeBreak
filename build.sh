#!/bin/bash

# Build script for EyeBreak: the menu bar app plus its End of Shift widget extension.

set -euo pipefail
cd "$(dirname "$0")"

# Parse arguments
BUILD_DMG=false
BUILD_RELEASE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dmg) BUILD_DMG=true ;;
        --release) BUILD_RELEASE=true ;;
        -h|--help)
            echo "Usage: ./build.sh [options]"
            echo ""
            echo "Options:"
            echo "  --release    Build in release mode (optimized)"
            echo "  --dmg        Create a DMG file for distribution"
            echo "  -h, --help   Show this help message"
            echo ""
            echo "Environment:"
            echo "  EYEBREAK_BUNDLE_ID   Build under another bundle ID (e.g. com.eyebreak.app.dev),"
            echo "                       so a test build keeps its own settings and history"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# The widget extension needs Xcode; the Command Line Tools alone can't build app
# extensions. Use Xcode without changing the system-wide xcode-select setting.
if [ -z "${DEVELOPER_DIR:-}" ]; then
    selected="$(xcode-select -p 2>/dev/null || true)"
    case "$selected" in
        *Xcode*) export DEVELOPER_DIR="$selected" ;;
        *) export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" ;;
    esac
fi
if [ ! -d "$DEVELOPER_DIR" ]; then
    echo "Xcode not found. Install Xcode, or point DEVELOPER_DIR at its Developer directory." >&2
    exit 1
fi

if [ "$BUILD_RELEASE" = true ]; then
    CONFIGURATION="Release"
else
    CONFIGURATION="Debug"
fi
echo "Building EyeBreak ($CONFIGURATION)..."

# Generate app icon from source PNG if needed
ICON_SOURCE="Sources/Eyebreak/Resources/AppIcon.png"
ICON_ICNS="Sources/Eyebreak/Resources/AppIcon.icns"
if [ "$ICON_SOURCE" -nt "$ICON_ICNS" ] || [ ! -f "$ICON_ICNS" ]; then
    echo "Generating app icon..."
    ICONSET_DIR="AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"
    for size in 16 32 64 128 256 512 1024; do
        sips -z $size $size "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" > /dev/null 2>&1
    done
    cp "$ICONSET_DIR/icon_32x32.png" "$ICONSET_DIR/icon_16x16@2x.png"
    mv "$ICONSET_DIR/icon_64x64.png" "$ICONSET_DIR/icon_32x32@2x.png"
    cp "$ICONSET_DIR/icon_256x256.png" "$ICONSET_DIR/icon_128x128@2x.png"
    cp "$ICONSET_DIR/icon_512x512.png" "$ICONSET_DIR/icon_256x256@2x.png"
    mv "$ICONSET_DIR/icon_1024x1024.png" "$ICONSET_DIR/icon_512x512@2x.png"
    iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS"
    rm -rf "$ICONSET_DIR"
    echo "App icon generated."
fi

OVERRIDES=()
if [ -n "${EYEBREAK_BUNDLE_ID:-}" ]; then
    echo "Bundle ID: $EYEBREAK_BUNDLE_ID"
    OVERRIDES+=("EYEBREAK_BUNDLE_ID=$EYEBREAK_BUNDLE_ID")
fi

LOG="build/xcodebuild.log"
mkdir -p build
if ! xcodebuild -project EyeBreak.xcodeproj \
                -scheme Eyebreak \
                -configuration "$CONFIGURATION" \
                -derivedDataPath build/dd \
                ${OVERRIDES[@]+"${OVERRIDES[@]}"} \
                build > "$LOG" 2>&1; then
    grep -E "error:" "$LOG" | sort -u || tail -30 "$LOG"
    echo "Build failed. Full log: $LOG" >&2
    exit 1
fi

# The widget lives inside the app, so replace the whole bundle
BUILT="build/dd/Build/Products/$CONFIGURATION/Eyebreak.app"
rm -rf Eyebreak.app
cp -R "$BUILT" Eyebreak.app
codesign --verify --deep --strict Eyebreak.app
echo "App bundle created: Eyebreak.app"

# Create DMG if requested
if [ "$BUILD_DMG" = true ]; then
    echo "Creating DMG..."

    VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Eyebreak.app/Contents/Info.plist)"
    DMG_NAME="EyeBreak-$VERSION.dmg"
    DMG_TEMP="build/dmg_temp"

    rm -rf "$DMG_TEMP"
    rm -f "build/$DMG_NAME"
    mkdir -p "$DMG_TEMP"
    cp -R Eyebreak.app "$DMG_TEMP/EyeBreak.app"
    ln -s /Applications "$DMG_TEMP/Applications"

    hdiutil create -volname "EyeBreak" \
        -srcfolder "$DMG_TEMP" \
        -ov -format UDZO \
        "build/$DMG_NAME"

    rm -rf "$DMG_TEMP"
    echo "DMG created: build/$DMG_NAME"
fi

echo ""
echo "Build complete!"
echo "  Run app:    open Eyebreak.app"
echo "  Widget:     macOS lists it once the app has run from /Applications (or ~/Applications):"
echo "              right-click the desktop > Edit Widgets > EyeBreak > End of Shift"
if [ "$BUILD_DMG" = true ]; then
    echo "  Distribute: build/$DMG_NAME"
fi
