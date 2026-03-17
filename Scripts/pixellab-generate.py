#!/usr/bin/env python3
"""Generate pixel art assets via PixelLab API with high quality settings."""

import json, base64, struct, zlib, sys
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError

# Load API key
env = Path.home() / ".agentpong" / ".env"
API_KEY = None
for line in env.read_text().splitlines():
    if line.startswith("PIXELLAB_API_KEY="):
        API_KEY = line.split("=", 1)[1].strip()

assert API_KEY, "No PIXELLAB_API_KEY in ~/.agentpong/.env"
BASE = "https://api.pixellab.ai/v2"
SPRITES_DIR = Path.home() / ".agentpong" / "sprites"
SPRITES_DIR.mkdir(parents=True, exist_ok=True)


def api_call(endpoint, payload, files=None):
    """Make API call. For multipart, use files dict."""
    url = f"{BASE}{endpoint}"

    if files:
        # Multipart form data
        import io
        boundary = "----PxlBoundary"
        body = io.BytesIO()

        for key, val in payload.items():
            body.write(f"--{boundary}\r\n".encode())
            body.write(f'Content-Disposition: form-data; name="{key}"\r\n\r\n'.encode())
            body.write(f"{json.dumps(val) if isinstance(val, (dict, list, bool)) else val}\r\n".encode())

        for key, (filename, data, mime) in files.items():
            body.write(f"--{boundary}\r\n".encode())
            body.write(f'Content-Disposition: form-data; name="{key}"; filename="{filename}"\r\n'.encode())
            body.write(f"Content-Type: {mime}\r\n\r\n".encode())
            body.write(data)
            body.write(b"\r\n")

        body.write(f"--{boundary}--\r\n".encode())
        body_bytes = body.getvalue()

        req = Request(url, data=body_bytes, method="POST")
        req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    else:
        req = Request(url, data=json.dumps(payload).encode(), method="POST")
        req.add_header("Content-Type", "application/json")

    req.add_header("Authorization", f"Bearer {API_KEY}")

    try:
        with urlopen(req, timeout=120) as resp:
            return json.loads(resp.read())
    except HTTPError as e:
        error_body = e.read().decode()
        print(f"API Error {e.code}: {error_body[:500]}")
        raise


def save_rgba_as_png(rgba_b64, width, height, path):
    """Convert PixelLab RGBA bytes to PNG."""
    raw = base64.b64decode(rgba_b64)
    expected = width * height * 4
    if len(raw) != expected:
        print(f"Warning: expected {expected} bytes, got {len(raw)}. Trying anyway.")

    def chunk(ct, d):
        c = ct + d
        return struct.pack('>I', len(d)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

    header = b'\x89PNG\r\n\x1a\n'
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
    rows = b''
    for y in range(height):
        rows += b'\x00' + raw[y * width * 4:(y + 1) * width * 4]
    idat = chunk(b'IDAT', zlib.compress(rows))
    iend = chunk(b'IEND', b'')
    Path(path).write_bytes(header + ihdr + idat + iend)
    print(f"Saved: {path} ({width}x{height})")


def generate_character(desc, filename, size=32):
    """Generate a character sprite."""
    print(f"Generating character: {desc}")
    result = api_call("/generate-image-v2", {
        "description": desc,
        "image_size": {"width": size, "height": size},
        "no_background": True,
        "text_guidance_scale": 10.0,
    })
    img = result["images"][0]
    save_rgba_as_png(img["base64"], size, size, str(SPRITES_DIR / filename))


def generate_object(desc, filename, width=48, height=48):
    """Generate a map object / furniture sprite."""
    print(f"Generating object: {desc}")
    result = api_call("/generate-image-v2", {
        "description": desc,
        "image_size": {"width": width, "height": height},
        "no_background": True,
        "text_guidance_scale": 10.0,
    })
    img = result["images"][0]
    save_rgba_as_png(img["base64"], width, height, str(SPRITES_DIR / filename))


def generate_scene(desc, filename, width=200, height=200):
    """Generate a background scene."""
    print(f"Generating scene: {desc}")
    result = api_call("/generate-image-v2", {
        "description": desc,
        "image_size": {"width": width, "height": height},
        "no_background": False,
        "text_guidance_scale": 8.0,
    })
    img = result["images"][0]
    save_rgba_as_png(img["base64"], width, height, str(SPRITES_DIR / filename))


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "character"

    if what == "character":
        # High quality character - cozy office worker style
        generate_character(
            "A small pixel art office worker character, sitting at a desk typing on a computer. "
            "Warm cozy atmosphere, dark theme, soft warm lighting. "
            "Low top-down RPG perspective like Stardew Valley. "
            "Dark hair, casual clothes, relaxed posture. "
            "Detailed pixel art, warm earth tones, cozy indie game style.",
            "char_working.png",
            size=48
        )

    elif what == "character-idle":
        generate_character(
            "A small pixel art office worker character standing idle, facing south (toward camera). "
            "Warm cozy atmosphere, dark theme. Low top-down RPG perspective. "
            "Casual clothes, relaxed posture, hands at sides. "
            "Detailed pixel art, warm earth tones, cozy indie game aesthetic.",
            "char_idle_south.png",
            size=48
        )

    elif what == "desk":
        generate_object(
            "A pixel art wooden office desk with a dark computer monitor on top, "
            "an office chair in front. Low top-down RPG perspective. "
            "Warm wood tones, dark monitor screen (off), cozy warm lighting. "
            "Stardew Valley style furniture, detailed pixel art.",
            "desk_with_chair.png",
            width=64, height=48
        )

    elif what == "sofa":
        generate_object(
            "A pixel art cozy green sofa/couch with cushions, low top-down RPG perspective. "
            "Warm atmosphere, dark green fabric, comfortable and inviting. "
            "Stardew Valley style furniture, detailed pixel art.",
            "sofa.png",
            width=80, height=48
        )

    elif what == "server":
        generate_object(
            "A pixel art server rack with blinking lights, tall and dark. "
            "Low top-down RPG perspective. Dark metal, small green and blue LED lights. "
            "Tech office equipment, detailed pixel art.",
            "server_rack.png",
            width=32, height=64
        )

    elif what == "room":
        generate_scene(
            "A cozy pixel art office room interior, top-down RPG view. "
            "Dark wood floor, dark walls, warm ambient lighting from ceiling lamp. "
            "Night time, window showing starry sky. Warm and inviting atmosphere. "
            "Empty room with just floor, walls, and warm lighting. No furniture. "
            "Stardew Valley / Earthbound style. Detailed 16-bit pixel art.",
            "room_shell.png",
            width=200, height=200
        )

    elif what == "all":
        for item in ["character", "character-idle", "desk", "sofa", "server", "room"]:
            try:
                print(f"\n--- Generating: {item} ---")
                # Re-run ourselves with each arg
                import subprocess
                subprocess.run([sys.executable, __file__, item], check=True)
            except Exception as e:
                print(f"Failed {item}: {e}")

    else:
        print(f"Unknown: {what}")
        print("Usage: pixellab-generate.py [character|character-idle|desk|sofa|server|room|all]")
