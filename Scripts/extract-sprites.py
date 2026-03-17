#!/usr/bin/env python3
"""
Extract furniture sprites from the Gemini background image.

Crops each furniture piece and removes the floor background,
producing PNGs with transparent backgrounds that perfectly match
the Gemini art style.

Usage:
  python3 extract-sprites.py ~/.agentpong/themes/default.png ~/.agentpong/sprites/
"""

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Install Pillow first: pip3 install Pillow")
    sys.exit(1)


def flood_fill_mask(img, start_x, start_y, tolerance=30):
    """Flood fill from a point, returning a set of background pixel coords."""
    w, h = img.size
    pixels = img.load()
    start_color = pixels[start_x, start_y]
    visited = set()
    queue = [(start_x, start_y)]

    def color_distance(c1, c2):
        return sum(abs(a - b) for a, b in zip(c1[:3], c2[:3]))

    while queue:
        x, y = queue.pop()
        if (x, y) in visited or x < 0 or y < 0 or x >= w or y >= h:
            continue
        if color_distance(pixels[x, y], start_color) > tolerance:
            continue
        visited.add((x, y))
        queue.extend([(x+1, y), (x-1, y), (x, y+1), (x, y-1)])

    return visited


def extract_sprite(img, crop_box, name, output_dir, bg_tolerance=35):
    """
    Crop a region and remove the background via flood fill from edges.

    crop_box: (left, top, right, bottom) in image pixel coords
    """
    cropped = img.crop(crop_box).convert("RGBA")
    w, h = cropped.size

    # Flood fill from all 4 corners and edges to find background
    bg_pixels = set()
    # Sample edge pixels as starting points for flood fill
    edge_points = []
    for x in range(0, w, 4):
        edge_points.extend([(x, 0), (x, h-1)])
    for y in range(0, h, 4):
        edge_points.extend([(0, y), (w-1, y)])

    for px, py in edge_points:
        if (px, py) not in bg_pixels:
            bg_pixels |= flood_fill_mask(cropped, px, py, tolerance=bg_tolerance)

    # Make background pixels transparent
    pixels = cropped.load()
    for (x, y) in bg_pixels:
        r, g, b, a = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)

    out_path = output_dir / f"{name}.png"
    cropped.save(out_path)
    print(f"  {name}.png  ({w}x{h}, {len(bg_pixels)} bg pixels removed)")
    return out_path


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <background.png> <output_dir>")
        sys.exit(1)

    bg_path = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    output_dir.mkdir(parents=True, exist_ok=True)

    img = Image.open(bg_path)
    print(f"Loaded background: {img.size}")

    # -------------------------------------------------------
    # Define crop regions for each furniture piece.
    # Coordinates are in the 1024x1024 image pixel space.
    # Adjust these by examining the actual background image.
    # Format: (left, top, right, bottom)
    # -------------------------------------------------------

    furniture = {
        # Top wall desks (2 main workstations with monitors)
        "desk_main_left":   (250, 260, 480, 440),
        "desk_main_right":  (500, 260, 730, 440),

        # Side desks
        "desk_side_left":   (50,  320, 230, 520),
        "desk_side_right":  (800, 320, 980, 520),

        # Chairs (in front of main desks)
        "chair_0":          (290, 400, 370, 480),
        "chair_1":          (410, 400, 490, 480),
        "chair_2":          (560, 400, 640, 480),

        # Sofa
        "sofa":             (300, 620, 720, 800),

        # Server rack (top right)
        "server_rack":      (830, 200, 960, 420),

        # Plants
        "plant_left":       (60,  230, 160, 330),
        "plant_sofa_left":  (200, 680, 310, 800),
        "plant_sofa_right": (720, 680, 830, 800),

        # Coffee machine area (left wall)
        "coffee_area":      (60,  380, 180, 490),

        # Door (bottom right)
        "door":             (840, 770, 960, 940),

        # Window (top left)
        "window":           (80,  60,  280, 230),

        # Ceiling lamp
        "ceiling_lamp":     (380, 100, 560, 260),
    }

    print(f"\nExtracting {len(furniture)} sprites:")
    for name, box in furniture.items():
        extract_sprite(img, box, name, output_dir, bg_tolerance=35)

    print(f"\nDone! Sprites saved to {output_dir}")
    print("\nNext steps:")
    print("1. Open each PNG and verify the crop boundaries are correct")
    print("2. Adjust crop_box coordinates in this script if needed")
    print("3. Tweak bg_tolerance if too much/little background is removed")
    print("4. Generate a clean room background (walls+floor only) via Gemini")


if __name__ == "__main__":
    main()
