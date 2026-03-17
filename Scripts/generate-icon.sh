#!/bin/bash
# generate-icon.sh -- Create AppIcon.icns from the husky south-facing sprite.
# Uses sips (built into macOS) to resize the pixel art sprite to all required icon sizes.
# The --resampleNearest flag preserves pixel-crisp scaling.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SPRITE="$HOME/.agentpong/sprites/husky-pro/south.png"
ICONSET_DIR="$PROJECT_DIR/build/AppIcon.iconset"
OUTPUT="$PROJECT_DIR/Resources/AppIcon.icns"

if [ ! -f "$SPRITE" ]; then
    echo "Error: Husky sprite not found at $SPRITE"
    exit 1
fi

mkdir -p "$ICONSET_DIR"
mkdir -p "$(dirname "$OUTPUT")"

# macOS icon sizes (filename -> pixel size)
declare -A SIZES=(
    ["icon_16x16.png"]=16
    ["icon_16x16@2x.png"]=32
    ["icon_32x32.png"]=32
    ["icon_32x32@2x.png"]=64
    ["icon_128x128.png"]=128
    ["icon_128x128@2x.png"]=256
    ["icon_256x256.png"]=256
    ["icon_256x256@2x.png"]=512
    ["icon_512x512.png"]=512
    ["icon_512x512@2x.png"]=1024
)

for name in "${!SIZES[@]}"; do
    size=${SIZES[$name]}
    cp "$SPRITE" "$ICONSET_DIR/$name"
    sips --resampleNearest "$size" "$size" "$ICONSET_DIR/$name" >/dev/null 2>&1 || \
    sips -z "$size" "$size" "$ICONSET_DIR/$name" >/dev/null 2>&1
done

# Convert iconset to icns
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT"
rm -rf "$ICONSET_DIR"

echo "Created: $OUTPUT"
