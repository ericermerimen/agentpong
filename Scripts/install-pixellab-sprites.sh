#!/bin/bash
# Downloads and installs PixelLab character sprites into ~/.agentpong/sprites/
# Usage: ./install-pixellab-sprites.sh <character_id> <prefix>
# Example: ./install-pixellab-sprites.sh 523fe8fd-... char
#          ./install-pixellab-sprites.sh 1b2fa906-... cat

set -euo pipefail

CHARACTER_ID="${1:?Usage: $0 <character_id> <prefix>}"
PREFIX="${2:?Usage: $0 <character_id> <prefix>}"
SPRITES_DIR="$HOME/.agentpong/sprites"
TMP_DIR=$(mktemp -d)
ZIP_FILE="$TMP_DIR/character.zip"

echo "Downloading character $CHARACTER_ID..."
curl --fail -sfo "$ZIP_FILE" "https://api.pixellab.ai/mcp/characters/$CHARACTER_ID/download"
if [ $? -ne 0 ]; then
    echo "ERROR: Download failed (animations may still be processing, HTTP 423)"
    rm -rf "$TMP_DIR"
    exit 1
fi

echo "Extracting..."
unzip -o "$ZIP_FILE" -d "$TMP_DIR/extracted" > /dev/null

mkdir -p "$SPRITES_DIR"

# Install rotation images
for dir in south north east west; do
    src="$TMP_DIR/extracted/rotations/$dir.png"
    if [ -f "$src" ]; then
        cp "$src" "$SPRITES_DIR/${PREFIX}_${dir}.png"
        echo "  ${PREFIX}_${dir}.png"
    fi
done

# Install animation frames
if [ -d "$TMP_DIR/extracted/animations" ]; then
    for anim_dir in "$TMP_DIR/extracted/animations"/*/; do
        anim_name=$(basename "$anim_dir")
        for dir_path in "$anim_dir"*/; do
            dir=$(basename "$dir_path")
            frame_idx=0
            for frame in "$dir_path"frame_*.png; do
                [ -f "$frame" ] || continue
                cp "$frame" "$SPRITES_DIR/${PREFIX}_${anim_name}_${dir}_${frame_idx}.png"
                echo "  ${PREFIX}_${anim_name}_${dir}_${frame_idx}.png"
                frame_idx=$((frame_idx + 1))
            done
        done
    done
fi

rm -rf "$TMP_DIR"

total=$(ls "$SPRITES_DIR"/${PREFIX}_*.png 2>/dev/null | wc -l | tr -d ' ')
echo "Done. $total sprites installed for '$PREFIX'."
