# Art Assets Needed -- PixelLab Generation Guide

All assets should be generated in the same PixelLab session/style for consistency.
Style: low top-down isometric, dark theme, warm lighting, 8-bit pixel art.

## Generation Settings (PixelLab API)
- view: "low top-down"
- outline: "single color outline"
- shading: "medium shading"
- detail: "medium detail"

## Room Shell
- **room-shell.png** -- 320x320
- Just floor (dark wood), walls (dark stone/wood), window (night sky), ceiling lamp
- NO furniture, NO door -- those are separate sprites
- Generate via Gemini or PixelLab generate-image-v2

## Furniture Sprites (generate via /map-objects)

| Asset | Filename | Size | Description |
|---|---|---|---|
| Desk | desk.png | 48x32 | Wooden desk, dark monitors on top (OFF state) |
| Chair | chair.png | 16x20 | Office swivel chair, dark color |
| Monitor ON | monitor-on.png | 16x12 | Monitor with blue/white glow (screen active) |
| Monitor OFF | monitor-off.png | 16x12 | Monitor dark/off |
| Sofa | sofa.png | 64x32 | Green/dark cushioned sofa |
| Server rack | server-rack.png | 32x48 | Tall server rack with panel lights |
| Coffee machine | coffee-machine.png | 16x24 | Small countertop coffee machine |
| Plant (small) | plant-small.png | 16x16 | Small potted plant |
| Plant (large) | plant-large.png | 16x24 | Taller potted plant |
| Door (open) | door-open.png | 24x32 | Open doorway |
| Door (closed) | door-closed.png | 24x32 | Closed wooden door |
| Ceiling lamp | lamp.png | 16x16 | Overhead warm light |
| Wall poster | poster.png | 16x20 | Decorative poster |
| Rug | rug.png | 48x32 | Small area rug |

## Character Sprites (generate via /create-character-with-4-directions + /animate-character)

| Asset | Filename | Size per frame | Frames | Description |
|---|---|---|---|---|
| Agent (idle) | agent-idle-{dir}.png | 16x16 | 4 dirs x 2 frames | Standing, breathing |
| Agent (walk) | agent-walk-{dir}.png | 16x16 | 4 dirs x 4 frames | Walking cycle |
| Agent (sit) | agent-sit.png | 16x16 | 1 frame (facing up) | Sitting at desk |
| Agent (type) | agent-type.png | 16x16 | 2 frames | Typing at desk |

Need 4-6 different agent color variants for different sessions.

## Mascot Cat (Phase 3)

| Asset | Filename | Size per frame | Frames | Description |
|---|---|---|---|---|
| Cat idle | cat-idle.png | 16x16 | 2 frames | Sitting, tail sway |
| Cat walk | cat-walk-{dir}.png | 16x16 | 4 dirs x 4 frames | Walking |
| Cat sleep | cat-sleep.png | 16x16 | 2 frames | Napping on sofa |

## PixelLab Free Tier Budget
- 40 fast generations initially (may be spent already)
- 5 slow generations per day after that
- Max 200x200 per generation (fine for all sprites, not enough for room shell)
- NO animation tools on free tier -- walk cycles need manual assembly

## PixelLab Tier 1 ($12/mo) Budget
- 2,000 generations per month
- 320x320 max (enough for room shell)
- Animation tools available (walk cycles auto-generated)
- Estimated need: ~50-100 generations for all assets (with iteration)

## Asset Installation
Place all sprites in: `~/.agentpong/sprites/`
The app will load them at startup and fall back to colored placeholders if missing.
