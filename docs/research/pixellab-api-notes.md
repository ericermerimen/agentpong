# PixelLab API Notes

Research from 2026-03-15. API tested with Eric's account.

## API info
- Base URL: `https://api.pixellab.ai/v2`
- Auth: `Authorization: Bearer API_KEY`
- Docs: `https://api.pixellab.ai/v2/llms.txt`
- MCP docs: `https://api.pixellab.ai/mcp/docs`

## Key endpoints for this project

### Generate background scene
```
POST /generate-image-v2
{
  "description": "...",
  "image_size": {"width": 320, "height": 320},
  "seed": 42,
  "no_background": false
}
```
Returns `background_job_id`, poll with `GET /background-jobs/{id}`.
Response has `images[0].base64` as RGBA bytes (NOT PNG). Need to convert.

### Generate character
```
POST /create-character-with-4-directions
{
  "description": "...",
  "image_size": {"width": 32, "height": 32},
  "view": "low top-down",
  "outline": "single color outline",
  "shading": "medium shading",
  "detail": "low detail"
}
```
Returns `character_id`. Get rotations via `GET /characters/{id}`.

### Generate furniture objects
```
POST /map-objects
{
  "description": "...",
  "image_size": {"width": 48, "height": 48},
  "view": "low top-down",
  "outline": "single color outline",
  "shading": "medium shading",
  "detail": "medium detail"
}
```

### Animate character
```
POST /animate-character
{
  "character_id": "...",
  "template_animation_id": "breathing-idle"  // or walk, etc.
}
```

## Lessons learned
- `generate-image-v2` returns RGBA bytes, not PNG. Need manual conversion.
- Outline values: "single color outline", "selective outline", "lineless"
- Shading values: "flat shading", "basic shading", "medium shading", "detailed shading"
- Detail values: "low detail", "medium detail", "high detail"
- Min image size: 32x32
- Generated backgrounds have their own pixel density -- character sprites MUST match or they look wrong
- CRITICAL: Generate background and characters in the same session/style to maintain consistency. Don't mix PixelLab-generated backgrounds with LimeZu tile characters.

## Credits remaining
Started with 14 free generations. Used 8 during research. 6 remaining as of 2026-03-15.

## Generated assets (from research)
Saved in agentshub/mockups/sprites/:
- room_bg.png (340x200, PixelLab generated office scene)
- char_south.png, char_east.png, etc. (32x32 character)
- desk.png, sofa.png, server_rack.png, plant.png (map objects)

These are test outputs -- quality was OK for individual pieces but scale mismatched when composited.
