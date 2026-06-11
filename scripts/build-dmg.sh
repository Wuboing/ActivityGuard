#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ActivityGuard"
TOOLCHAIN_SWIFTC="$PROJECT_DIR/.toolchain/root/usr/bin/swiftc"
BUILD_DIR="$PROJECT_DIR/.build"
APP_BUNDLE="$PROJECT_DIR/dist/$APP_NAME.app"
DMG_PATH="$PROJECT_DIR/dist/$APP_NAME.dmg"
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
ICON_SOURCE="$PROJECT_DIR/Resources/AppIcon.icns"
ICON_PNG="$PROJECT_DIR/Resources/AppIcon.png"

echo "Building $APP_NAME..."
mkdir -p "$BUILD_DIR"

# Generate icon from PNG source, or fall back to programmatic icon
if [ -f "$ICON_PNG" ]; then
    echo "Generating app icon from $ICON_PNG..."
    bash "$PROJECT_DIR/scripts/generate-app-icon.sh" "$ICON_PNG"
elif [ ! -f "$ICON_SOURCE" ]; then
    echo "Generating app icon..."
    mkdir -p "$PROJECT_DIR/Resources"
    "$TOOLCHAIN_SWIFTC" \
      -o "$BUILD_DIR/gen-icon" \
      "$PROJECT_DIR/scripts/gen-icon.swift" \
      -sdk "$SDK_PATH" \
      -framework Cocoa \
      -O
    "$BUILD_DIR/gen-icon" "$BUILD_DIR/icons"
    iconutil -c icns "$BUILD_DIR/icons/AppIcon.iconset" -o "$ICON_SOURCE"
    rm -rf "$BUILD_DIR/gen-icon" "$BUILD_DIR/icons"
fi

# Compile with toolchain Swift to avoid SDK version mismatch
"$TOOLCHAIN_SWIFTC" \
  -o "$BUILD_DIR/ActivityGuardApp" \
  "$PROJECT_DIR/Sources/ActivityGuardCore/"*.swift \
  "$PROJECT_DIR/Sources/ActivityGuardApp/App.swift" \
  "$PROJECT_DIR/Sources/ActivityGuardApp/Localization/"*.swift \
  "$PROJECT_DIR/Sources/ActivityGuardApp/ViewModel/"*.swift \
  "$PROJECT_DIR/Sources/ActivityGuardApp/Views/"*.swift \
  "$PROJECT_DIR/Sources/ActivityGuardApp/StatusBar/"*.swift \
  "$PROJECT_DIR/Sources/ActivityGuardApp/Services/"*.swift \
  -sdk "$SDK_PATH" \
  -framework SwiftUI \
  -framework IOKit \
  -framework ServiceManagement \
  -O

echo "Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/ActivityGuardApp" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Sources/ActivityGuardApp/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$ICON_SOURCE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "Signing..."
codesign --force --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "Creating DMG..."
mkdir -p "$PROJECT_DIR/dist"
rm -f "$DMG_PATH"

TMP_DIR=$(mktemp -d)
cp -R "$APP_BUNDLE" "$TMP_DIR/"
ln -s /Applications "$TMP_DIR/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$TMP_DIR" -ov -format UDZO "$DMG_PATH"
rm -rf "$TMP_DIR"

echo "Done: $DMG_PATH"
