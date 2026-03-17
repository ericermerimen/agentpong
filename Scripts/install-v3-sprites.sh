#!/bin/bash
# Install v3 128px character sprites + animations
# Run this after all PixelLab animations complete

set -euo pipefail

CHARACTER_ID="c497eac4-1a37-4c99-96d8-37eb6b41caf1"
SPRITES_DIR="$HOME/.agentpong/sprites"
TMP_DIR=$(mktemp -d)

echo "Downloading v3 character..."
curl --fail -sfo "$TMP_DIR/char.zip" "https://api.pixellab.ai/mcp/characters/$CHARACTER_ID/download"
if [ $? -ne 0 ]; then
    echo "ERROR: Download failed (animations may still be processing)"
    rm -rf "$TMP_DIR"
    exit 1
fi

echo "Extracting..."
unzip -o "$TMP_DIR/char.zip" -d "$TMP_DIR/extracted" > /dev/null

# Install rotations
for dir in south north east west; do
    cp "$TMP_DIR/extracted/rotations/$dir.png" "$SPRITES_DIR/char_${dir}.png"
    echo "  char_${dir}.png"
done

# Install walk animation frames
for dir_path in "$TMP_DIR/extracted/animations/walking"/*/; do
    [ -d "$dir_path" ] || continue
    dir=$(basename "$dir_path")
    idx=0
    for frame in "$dir_path"frame_*.png; do
        [ -f "$frame" ] || continue
        cp "$frame" "$SPRITES_DIR/char_walking_${dir}_${idx}.png"
        echo "  char_walking_${dir}_${idx}.png"
        idx=$((idx + 1))
    done
done

# Install sitting (crouching) animation frames - use first frame as static sitting pose
for dir_path in "$TMP_DIR/extracted/animations/crouching"/*/; do
    [ -d "$dir_path" ] || continue
    dir=$(basename "$dir_path")
    # Take first frame as the sitting pose
    first_frame="$dir_path/frame_000.png"
    if [ -f "$first_frame" ]; then
        cp "$first_frame" "$SPRITES_DIR/char_sitting_${dir}_0.png"
        echo "  char_sitting_${dir}_0.png"
    fi
done

rm -rf "$TMP_DIR"
total=$(ls "$SPRITES_DIR"/char_*.png 2>/dev/null | wc -l | tr -d ' ')
echo "Done. $total character sprites installed."
