#!/usr/bin/env python3
"""Generate pixel art office background using Google Gemini API."""

import base64
import json
import os
import sys
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError

# Load API key
env_file = Path.home() / ".agentpong" / ".env"
API_KEY = None
if env_file.exists():
    for line in env_file.read_text().splitlines():
        if line.startswith("GOOGLE_AI_API_KEY="):
            API_KEY = line.split("=", 1)[1].strip()
if not API_KEY:
    API_KEY = os.environ.get("GOOGLE_AI_API_KEY")
if not API_KEY:
    print("Error: No API key found. Set GOOGLE_AI_API_KEY in ~/.agentpong/.env")
    sys.exit(1)

# Theme from args or default
theme = sys.argv[1] if len(sys.argv) > 1 else "cozy night office with warm lamp lighting"

PROMPT = f"""Generate a top-down pixel art room image for a game office scene.
The room should be 320x320 pixels in retro 8-bit RPG style.

Layout requirements (STRICT):
- Left half: 4 small work desks in a row, each with a tiny computer monitor
- Center-bottom: a lounge area with a small sofa
- Right side: a server rack / debug station area
- Bottom-right: a door/entrance
- Scattered: 2-3 small plants, a coffee machine near the desks

Visual style:
- Dark color palette, nighttime atmosphere
- {theme}
- Warm interior lighting from desk lamps and monitors
- Pixel art style, clean edges, no anti-aliasing
- Top-down isometric-ish view (like classic RPG games)
- No characters or people in the scene
- No text or watermarks

The image must be exactly 320x320 pixels.
"""

# Try multiple image-capable models in order
MODELS = [
    "gemini-2.0-flash",
    "gemini-3.1-flash-image-preview",
    "gemini-3-pro-image-preview",
    "gemini-2.5-flash-image",
]
model = MODELS[1]  # gemini-3.1-flash-image-preview
url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={API_KEY}"

payload = {
    "contents": [
        {
            "parts": [
                {"text": PROMPT}
            ]
        }
    ],
    "generationConfig": {
        "responseModalities": ["TEXT", "IMAGE"],
    }
}

print(f"Generating background with theme: {theme}")
print("Calling Gemini API...")

try:
    req = Request(url, data=json.dumps(payload).encode(), method="POST")
    req.add_header("Content-Type", "application/json")

    with urlopen(req, timeout=120) as resp:
        result = json.loads(resp.read().decode())
except HTTPError as e:
    error_body = e.read().decode()
    print(f"API Error {e.code}: {error_body}")
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)

# Extract image from response
image_data = None
text_response = ""

if "candidates" in result:
    for candidate in result["candidates"]:
        if "content" in candidate:
            for part in candidate["content"].get("parts", []):
                if "inlineData" in part:
                    image_data = base64.b64decode(part["inlineData"]["data"])
                    mime = part["inlineData"].get("mimeType", "image/png")
                    print(f"Got image ({mime}, {len(image_data)} bytes)")
                elif "text" in part:
                    text_response += part["text"]

if text_response:
    print(f"Model text: {text_response[:200]}")

if not image_data:
    print("No image generated. Full response:")
    print(json.dumps(result, indent=2)[:2000])
    sys.exit(1)

# Save the image
output_dir = Path.home() / ".agentpong" / "themes"
output_dir.mkdir(parents=True, exist_ok=True)

# Determine extension from mime
ext = "png" if "png" in str(mime) else "jpg" if "jpeg" in str(mime) or "jpg" in str(mime) else "webp"
output_path = output_dir / f"default.{ext}"
output_path.write_bytes(image_data)
print(f"Saved to: {output_path}")

# Also save to project Assets for development
project_assets = Path(__file__).parent.parent / "Assets" / "backgrounds"
project_assets.mkdir(parents=True, exist_ok=True)
project_copy = project_assets / f"office_bg.{ext}"
project_copy.write_bytes(image_data)
print(f"Copied to: {project_copy}")

print("Done!")
