#!/usr/bin/env python3
"""
Extract furniture overlay layer from Gemini background.

Creates a transparent PNG containing ONLY the front portions of
desks/chairs/sofa that should render IN FRONT of characters.
This gives depth occlusion -- cat/characters appear to walk behind furniture.

The overlay image is the same size as the background so it can be
placed at the exact same position with a higher z-order.
"""

import sys
from pathlib import Path
from PIL import Image

def main():
    bg_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / ".agentpong/themes/default.png"
    out_path = Path(sys.argv[2]) if len(sys.argv) > 2 else Path.home() / ".agentpong/themes/overlay.png"

    img = Image.open(bg_path).convert("RGBA")
    w, h = img.size
    print(f"Background: {w}x{h}")

    # Create empty transparent overlay same size as background
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    # Define regions to copy as overlay (front parts of furniture).
    # These are the portions BELOW the chair seat line that should
    # occlude characters walking behind them.
    # Format: (left, top, right, bottom) in image pixel coords.

    regions = [
        # Left wall desk - chair and desk front
        (45, 420, 215, 530),

        # Main desk row - chair fronts and desk front edge
        (220, 380, 700, 480),

        # Right wall desk - chair and desk front
        (700, 420, 860, 530),

        # Sofa front
        (285, 660, 610, 800),

        # Plants near sofa
        (180, 680, 300, 790),
        (600, 680, 730, 790),
    ]

    pixels_bg = img.load()
    pixels_ov = overlay.load()

    total = 0
    for (left, top, right, bottom) in regions:
        # Clamp to image bounds
        left = max(0, left)
        top = max(0, top)
        right = min(w, right)
        bottom = min(h, bottom)

        for y in range(top, bottom):
            for x in range(left, right):
                r, g, b, a = pixels_bg[x, y]
                pixels_ov[x, y] = (r, g, b, a)
                total += 1

    overlay.save(out_path)
    print(f"Overlay saved: {out_path} ({total} pixels)")
    print(f"Place this at same position as background, with higher z-order")

if __name__ == "__main__":
    main()
