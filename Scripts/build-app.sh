#!/bin/bash
# build-app.sh -- Build AgentPong.app bundle from Swift Package Manager output.
#
# Usage:
#   ./Scripts/build-app.sh              # Debug build
#   ./Scripts/build-app.sh release      # Release build
#   ./Scripts/build-app.sh release sign # Release + codesign (requires Developer ID)
#
# Output: build/AgentPong.app

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

CONFIG="${1:-debug}"
SIGN="${2:-}"
VERSION=$(cat VERSION | tr -d '[:space:]')
APP_NAME="AgentPong"
BUNDLE_ID="com.agentpong.app"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME v$VERSION ($CONFIG)..."

# Update version constant in source
sed -i '' "s/public static let current = \".*\"/public static let current = \"$VERSION\"/" \
    Sources/Shared/Version.swift

# Build
if [ "$CONFIG" = "release" ]; then
    swift build -c release
    BINARY=".build/release/$APP_NAME"
else
    swift build
    BINARY=".build/debug/$APP_NAME"
fi

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY"
    exit 1
fi

# Create .app bundle structure
rm -r "$APP_BUNDLE" 2>/dev/null || true
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary (serves as both GUI app and CLI tool)
# NOTE: Do NOT create a lowercase "agentpong" symlink here.
# macOS APFS is case-insensitive -- "agentpong" and "AgentPong" are the
# same file, so ln -sf would replace the binary with a broken symlink.
# The Homebrew formula creates the CLI symlink externally via:
#   bin.install_symlink prefix/"AgentPong.app/Contents/MacOS/AgentPong" => "agentpong"
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Verify binary was actually copied
if [ ! -x "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]; then
    echo "Error: Binary copy failed"
    exit 1
fi

# Copy app icon if it exists
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

# Embed Sparkle.framework for auto-updates
SPARKLE_FW=".build/${CONFIG}/Sparkle.framework"
if [ -d "$SPARKLE_FW" ]; then
    mkdir -p "$APP_BUNDLE/Contents/Frameworks"
    cp -R "$SPARKLE_FW" "$APP_BUNDLE/Contents/Frameworks/"
    echo "Embedded Sparkle.framework"
fi

# Generate Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>AgentPong needs accessibility access to focus terminal windows when you click on a session.</string>
    <key>SUFeedURL</key>
    <string>https://ericermerimen.github.io/agentpong/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>MFXKZi9wP1qC2tGJMxbKyBTma6Ei0Tdbu0odkIbT9fQ=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
</dict>
</plist>
PLIST

# Write PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Codesign if requested
if [ "$SIGN" = "sign" ]; then
    echo "Signing..."
    # Sign embedded frameworks first (inside-out signing)
    if [ -d "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework" ]; then
        codesign -f -s "Developer ID Application" \
            -o runtime \
            "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
    fi
    codesign -f -s "Developer ID Application" \
        -o runtime \
        "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    codesign -f -s "Developer ID Application" \
        -o runtime \
        "$APP_BUNDLE"
    echo "Signed."
fi

echo ""
echo "Built: $APP_BUNDLE"
echo "Version: $VERSION"
echo "Binary: $(du -h "$APP_BUNDLE/Contents/MacOS/$APP_NAME" | cut -f1 | tr -d '[:space:]')"
echo ""
echo "To run:  open $APP_BUNDLE"
echo "To link: ln -sf \"\$(pwd)/$APP_BUNDLE\" /Applications/"
