#!/usr/bin/env python3
"""Generate pixel art screen textures for AgentPong monitors.

Only generates textures NOT covered by PixelLab MCP:
- center-terminal, center-code-editor, center-claude-chat, center-trading-chart
- side-code, side-browser (sides that PixelLab can't do or haven't generated)

PixelLab covers: center-youtube-player, center-twitter-feed, center-browser-docs,
                 side-social (heart), side-chart (bar chart), side-ai-chat (bubble)

Quality approach: multi-shade colors, highlights, subtle glow, organic shapes.
"""

import os
from PIL import Image, ImageDraw

OUTPUT_DIR = os.path.expanduser("~/.agentpong/sprites/screens")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Dark background colors
BG_DARK = (13, 13, 18, 255)
BG_TERMINAL = (8, 10, 8, 255)


def save(img, name):
    path = os.path.join(OUTPUT_DIR, f"{name}.png")
    img.save(path)
    print(f"  saved: {name}.png ({img.width}x{img.height})")


def px(img, x, y, color):
    """Set a single pixel with bounds checking."""
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color)


def rect(d, x1, y1, x2, y2, color):
    """Draw a filled rectangle."""
    d.rectangle([x1, y1, x2, y2], fill=color)


# =============================================================================
# CENTER TEXTURES (154x82) - only ones PixelLab can't handle
# =============================================================================

def center_code_editor():
    """Code editor: colorful syntax-highlighted lines on dark background.
    Reads as 'code' instantly at any size. Warm IDE feel."""
    img = Image.new("RGBA", (154, 82), (22, 24, 32, 255))
    d = ImageDraw.Draw(img)

    # Subtle line number gutter on left
    rect(d, 0, 0, 18, 81, (18, 20, 26, 255))
    for y in range(6, 76, 8):
        rect(d, 8, y, 14, y + 2, (40, 44, 55, 255))

    # Gutter separator line
    rect(d, 18, 0, 19, 81, (30, 33, 42, 255))

    # Code lines - varying widths and colors to suggest syntax highlighting
    lines = [
        # (indent, segments: [(width, color), ...])
        (0, [(16, (130, 170, 230)), (8, (200, 200, 210)), (24, (180, 220, 160))]),
        (0, [(12, (200, 140, 200)), (20, (200, 200, 210)), (10, (230, 200, 120))]),
        (4, [(28, (130, 170, 230)), (16, (200, 200, 210))]),
        (4, [(8, (200, 140, 200)), (12, (200, 200, 210)), (20, (180, 220, 160)), (6, (230, 200, 120))]),
        (8, [(16, (230, 200, 120)), (10, (200, 200, 210)), (14, (180, 220, 160))]),
        (8, [(24, (200, 200, 210)), (8, (220, 130, 130))]),
        (4, [(10, (130, 170, 230))]),
        (0, []),  # blank line
        (0, [(20, (130, 170, 230)), (12, (200, 200, 210)), (8, (230, 200, 120))]),
    ]

    y_start = 6
    for i, (indent, segments) in enumerate(lines):
        y = y_start + i * 8
        x = 24 + indent
        for seg_w, (r, g, b) in segments:
            # Main color
            rect(d, x, y, x + seg_w, y + 3, (r, g, b, 255))
            # Subtle highlight on top pixel row
            rect(d, x, y, x + seg_w, y, (min(r + 20, 255), min(g + 20, 255), min(b + 20, 255), 120))
            x += seg_w + 4

    # Active line highlight (subtle)
    rect(d, 20, y_start + 3 * 8 - 1, 153, y_start + 3 * 8 + 4, (35, 40, 52, 255))

    save(img, "center-code-editor")


def center_terminal():
    """Terminal: green prompt with subtle CRT glow. Multi-shade green."""
    img = Image.new("RGBA", (154, 82), BG_TERMINAL)
    d = ImageDraw.Draw(img)
    cx, cy = 77, 41

    # Color palette - 3 shades of green
    green_bright = (120, 255, 120, 255)
    green_mid = (60, 200, 60, 255)
    green_dim = (30, 100, 30, 255)
    green_glow = (20, 60, 20, 255)

    # Subtle glow halo behind the prompt area
    rect(d, cx - 36, cy - 18, cx + 30, cy + 18, green_glow)

    # Draw > chevron with shading
    # Top arm
    for i in range(9):
        x = cx - 30 + i * 3
        y = cy - 14 + i * 3
        # Shadow (bottom-right)
        rect(d, x + 1, y + 1, x + 5, y + 4, green_dim)
        # Main body
        rect(d, x, y, x + 4, y + 3, green_mid)
        # Highlight (top-left pixel)
        px(img, x, y, green_bright)

    # Bottom arm
    for i in range(9):
        x = cx - 30 + i * 3
        y = cy + 14 - i * 3
        rect(d, x + 1, y + 1, x + 5, y + 4, green_dim)
        rect(d, x, y, x + 4, y + 3, green_mid)
        px(img, x, y, green_bright)

    # Cursor block with glow
    cursor_x, cursor_y = cx + 10, cy + 6
    rect(d, cursor_x - 2, cursor_y - 2, cursor_x + 16, cursor_y + 8, green_glow)
    rect(d, cursor_x, cursor_y, cursor_x + 14, cursor_y + 6, green_mid)
    rect(d, cursor_x, cursor_y, cursor_x + 14, cursor_y + 1, green_bright)

    # Very subtle scanlines (just slightly darker every other row)
    for y in range(0, 82, 3):
        rect(d, 0, y, 153, y, (0, 0, 0, 15))

    save(img, "center-terminal")


def center_claude_chat():
    """Claude: warm coral speech bubble with shading and sparkle."""
    img = Image.new("RGBA", (154, 82), (14, 12, 16, 255))
    d = ImageDraw.Draw(img)
    cx, cy = 77, 36

    # Color palette - warm coral with depth
    coral_light = (255, 170, 120, 255)
    coral_mid = (228, 125, 75, 255)
    coral_shadow = (180, 90, 55, 255)
    bg = (14, 12, 16, 255)

    # Bubble body with rounded corners
    # Main fill
    rect(d, cx - 24, cy - 14, cx + 24, cy + 8, coral_mid)
    # Top highlight strip
    rect(d, cx - 22, cy - 14, cx + 22, cy - 12, coral_light)
    # Bottom shadow strip
    rect(d, cx - 22, cy + 6, cx + 22, cy + 8, coral_shadow)

    # Round all 4 corners (3px cut)
    for (crnx, crny) in [(cx - 24, cy - 14), (cx + 22, cy - 14),
                          (cx - 24, cy + 6), (cx + 22, cy + 6)]:
        rect(d, crnx, crny, crnx + 2, crny + 2, bg)

    # Tail pointing down
    d.polygon([(cx - 4, cy + 8), (cx - 10, cy + 18), (cx + 6, cy + 8)], fill=coral_mid)
    # Shadow on tail
    d.polygon([(cx - 2, cy + 12), (cx - 8, cy + 18), (cx + 4, cy + 12)], fill=coral_shadow)

    # Three dots inside bubble (ellipsis - "thinking")
    dot_color = (14, 12, 16, 200)
    for dx in [-10, 0, 10]:
        rect(d, cx + dx - 2, cy - 5, cx + dx + 2, cy - 1, dot_color)
        # Tiny highlight on each dot
        px(img, cx + dx - 1, cy - 5, (14, 12, 16, 140))

    save(img, "center-claude-chat")


def center_trading_chart():
    """Trading chart: candlesticks with glow and grid. Multi-shade."""
    img = Image.new("RGBA", (154, 82), (10, 12, 20, 255))
    d = ImageDraw.Draw(img)

    # Subtle grid lines
    grid_color = (22, 26, 38, 255)
    for y in range(10, 72, 12):
        rect(d, 16, y, 140, y, grid_color)
    for x in range(28, 140, 20):
        rect(d, x, 8, x, 68, grid_color)

    # Color palettes
    green_hi = (100, 240, 110, 255)
    green_mid = (50, 190, 70, 255)
    green_dim = (30, 120, 40, 255)
    red_hi = (255, 100, 80, 255)
    red_mid = (210, 55, 45, 255)
    red_dim = (140, 35, 30, 255)

    candles = [
        # (x, body_top, body_bot, wick_top, wick_bot, is_green)
        (28, 28, 46, 20, 54, True),
        (44, 34, 52, 26, 60, False),
        (58, 22, 40, 16, 48, True),
        (72, 30, 56, 22, 64, False),
        (86, 18, 36, 12, 44, True),
        (100, 24, 50, 16, 58, True),
        (114, 20, 34, 14, 40, True),
        (128, 26, 48, 18, 56, False),
    ]

    for x, bt, bb, wt, wb, is_green in candles:
        hi = green_hi if is_green else red_hi
        mid = green_mid if is_green else red_mid
        dim = green_dim if is_green else red_dim

        # Wick with subtle glow
        rect(d, x - 1, wt, x + 1, wb, dim)
        rect(d, x, wt, x, wb, mid)

        # Body with shading
        rect(d, x - 4, bt, x + 4, bb, mid)
        # Left highlight
        rect(d, x - 4, bt, x - 3, bb, hi)
        # Right shadow
        rect(d, x + 3, bt, x + 4, bb, dim)
        # Top edge highlight
        rect(d, x - 3, bt, x + 3, bt + 1, hi)

    # Axis lines
    rect(d, 16, 68, 140, 69, (35, 40, 55, 255))
    rect(d, 16, 8, 17, 68, (35, 40, 55, 255))

    save(img, "center-trading-chart")


# =============================================================================
# SIDE TEXTURES (64x80) - only ones PixelLab can't do
# =============================================================================

def side_code():
    """Code: colored { } braces with shading."""
    img = Image.new("RGBA", (64, 80), (16, 18, 28, 255))
    d = ImageDraw.Draw(img)
    cx, cy = 32, 40

    # Yellow brace { with highlight/shadow
    y_hi = (255, 230, 110, 255)
    y_mid = (220, 190, 70, 255)
    y_dim = (160, 140, 50, 255)

    bx = cx - 10
    # { shape with shading
    rect(d, bx + 3, cy - 12, bx + 6, cy - 10, y_mid)
    px(img, bx + 3, cy - 12, y_hi)
    rect(d, bx + 1, cy - 10, bx + 4, cy - 3, y_mid)
    rect(d, bx + 1, cy - 10, bx + 1, cy - 3, y_hi)
    rect(d, bx - 1, cy - 3, bx + 2, cy + 3, y_mid)
    px(img, bx - 1, cy - 3, y_hi)
    rect(d, bx + 1, cy + 3, bx + 4, cy + 10, y_mid)
    rect(d, bx + 4, cy + 3, bx + 4, cy + 10, y_dim)
    rect(d, bx + 3, cy + 10, bx + 6, cy + 12, y_mid)
    px(img, bx + 6, cy + 12, y_dim)

    # Purple brace } with highlight/shadow
    p_hi = (210, 160, 255, 255)
    p_mid = (170, 110, 220, 255)
    p_dim = (120, 70, 160, 255)

    bx = cx + 6
    rect(d, bx, cy - 12, bx + 3, cy - 10, p_mid)
    px(img, bx, cy - 12, p_hi)
    rect(d, bx + 2, cy - 10, bx + 5, cy - 3, p_mid)
    rect(d, bx + 5, cy - 10, bx + 5, cy - 3, p_dim)
    rect(d, bx + 4, cy - 3, bx + 7, cy + 3, p_mid)
    px(img, bx + 7, cy + 3, p_dim)
    rect(d, bx + 2, cy + 3, bx + 5, cy + 10, p_mid)
    rect(d, bx + 2, cy + 3, bx + 2, cy + 10, p_hi)
    rect(d, bx, cy + 10, bx + 3, cy + 12, p_mid)
    px(img, bx + 3, cy + 12, p_dim)

    save(img, "side-code")


def side_browser():
    """Browser: compact globe with proper circle outline and shading."""
    img = Image.new("RGBA", (64, 80), BG_DARK)
    d = ImageDraw.Draw(img)
    cx, cy = 32, 40
    r = 11

    blue_hi = (130, 190, 255, 255)
    blue_mid = (80, 140, 220, 255)
    blue_dim = (45, 80, 140, 255)
    blue_glow = (25, 40, 70, 255)

    # Glow behind globe
    d.ellipse([cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3], fill=blue_glow)

    # Circle outline - pixelated but smooth
    import math
    for angle in range(360):
        rad = math.radians(angle)
        x = cx + int(r * math.cos(rad))
        y = cy + int(r * math.sin(rad))
        # Use brighter shade on top, dimmer on bottom
        shade = blue_hi if angle > 180 else blue_dim
        px(img, x, y, shade)

    # Horizontal equator
    rect(d, cx - r + 1, cy - 1, cx + r - 1, cy, blue_mid)
    # Vertical meridian
    rect(d, cx - 1, cy - r + 1, cx, cy + r - 1, blue_mid)

    # Latitude lines (dimmer)
    for dy in [-6, 6]:
        half = int((r ** 2 - dy ** 2) ** 0.5) - 1
        if half > 0:
            rect(d, cx - half, cy + dy, cx + half, cy + dy, blue_dim)

    # Longitude curves (dimmer, suggesting spherical shape)
    for dx in [-5, 5]:
        half = int((r ** 2 - dx ** 2) ** 0.5) - 1
        if half > 0:
            rect(d, cx + dx, cy - half, cx + dx, cy + half, blue_dim)

    save(img, "side-browser")


# =============================================================================
# GENERATE ALL (only non-PixelLab textures)
# =============================================================================

if __name__ == "__main__":
    print("Generating improved center textures (154x82)...")
    center_code_editor()
    center_terminal()
    center_claude_chat()
    center_trading_chart()

    print("\nGenerating improved side textures (64x80)...")
    side_code()
    side_browser()

    print(f"\nSaved to: {OUTPUT_DIR}")
    print("Note: YouTube, X/Twitter, browser-docs covered by PixelLab")
