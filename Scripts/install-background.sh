#!/bin/bash
# Install a background image for AgentPong
# Usage: ./install-background.sh path/to/image.png
#
# Generate backgrounds at:
# - Google AI Studio (aistudio.google.com) -- paste the prompt below
# - Or use any pixel art tool
#
# PROMPT for AI Studio:
# Generate a top-down pixel art room image, 320x320 pixels, retro 8-bit RPG style.
# Layout: left half has 4 small work desks with monitors, center-bottom has a lounge sofa,
# right side has a server rack, bottom-right has a door. Add 2 plants and a coffee machine.
# Dark color palette, nighttime, warm lamp lighting. No characters, no text.

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <image-file>"
    echo ""
    echo "Installs a background image for AgentPong."
    echo "Image should be 320x320 pixel art."
    echo ""
    echo "Generate one at aistudio.google.com with this prompt:"
    echo "  Generate a top-down pixel art room, 320x320px, 8-bit RPG style."
    echo "  4 desks left, sofa center, server rack right, door bottom-right."
    echo "  Dark, nighttime, warm lamps. No characters, no text."
    exit 1
fi

THEMES_DIR="$HOME/.agentpong/themes"
mkdir -p "$THEMES_DIR"

# Get extension
EXT="${1##*.}"
DEST="$THEMES_DIR/default.$EXT"

cp "$1" "$DEST"
echo "Installed background: $DEST"
echo "Restart AgentPong to see the new background."
