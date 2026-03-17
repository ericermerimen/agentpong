# Star-Office-UI Architecture Notes

Research from 2026-03-15 exploring how Star-Office-UI builds their pixel office scene.

## Tech stack
- **Frontend**: Phaser 3.80.1 (vendored), vanilla JS
- **Backend**: Python Flask on port 19000
- **Desktop pet**: Tauri v2 (Rust + WebView) with tile-based maps + A* pathfinding
- **Font**: Ark Pixel 12px proportional (pixel art font, WOFF2)

## Scene rendering
- **NOT tile-based** in the web version
- Single pre-rendered background image (`office_bg.webp`, 1280x720)
- Individual sprite assets layered on top at fixed pixel coordinates
- Coordinates + depth ordering defined in `layout.js` (data separated from logic)
- Phaser config: `pixelArt: true` (nearest-neighbor scaling), arcade physics

## State mapping (6 states -> 3 zones)

| State | Zone | Position | Visual |
|-------|------|----------|--------|
| idle | breakroom (640,360) | Sofa area | Star on sofa (animated sofa sprite, 48 frames 12fps) |
| writing | writing (320,360) | Desk area | Star at desk (star_working, 192 frames 12fps) |
| researching | writing (320,360) | Desk area | star_researching (96 frames 12fps) |
| executing | writing (320,360) | Desk area | Same as writing |
| syncing | writing (1157,592) | Server area | Sync animation (52 frames 12fps) |
| error | error (1066,180) | Debug area | Bug sprite ping-pongs x:1007-1111 at 0.6px/frame |

State aliases: working->writing, run/running->executing, sync->syncing, research->researching

## Sprite assets (LimeZu based)
- `star-idle-v5.png` -- 128x128/frame, 30 frames, 12fps
- `star-working-spritesheet-grid.webp` -- 230x144/frame, 192 frames, 12fps (repacked from strip to grid)
- `sofa-busy-spritesheet` -- 256x256/frame, 48 frames, 12fps
- `coffee-machine-v3-grid.webp` -- 230x230/frame, 96 frames, 12.5fps (always animating)
- `serverroom-spritesheet.webp` -- 180x251/frame, 40 frames, 6fps
- `error-bug-spritesheet-grid.webp` -- 180x180/frame, 96 frames, 12fps

Credits: LimeZu "Animated Mini Characters 2 (Platformer) [FREE]" from itch.io

## Background generation (Gemini API)

Script: `scripts/gemini_image_generate.py`
Model: `gemini-2.0-flash-exp` or configured model
Reference image: `assets/room-reference.webp` (bare room skeleton)

Prompt:
```
Use a top-down pixel room composition compatible with an office game scene.
STRICTLY preserve the same room geometry, camera angle, wall/floor boundaries
and major object placement as the provided reference image.
Keep region layout stable (left work area, center lounge, right error area).
Only change visual style/theme/material/lighting according to: [THEME].
Do not add text or watermark. Retro 8-bit RPG style.
```

Theme pool (random):
- 8-bit dungeon guild room
- 8-bit stardew-valley inspired cozy farm tavern
- 8-bit nordic fantasy tavern
- 8-bit magitech workshop
- 8-bit elven forest inn
- 8-bit pixel cyber tavern
- 8-bit desert caravan inn
- 8-bit snow mountain lodge

## Depth ordering (low to high)
serverroom(2) -> poster(4) -> plants(5) -> sofa(10) -> syncAnim(40) -> errorBug(50) -> coffeeMachine(99) -> starWorking(900) -> desk(1000) -> flower(1100) -> cat(2000) -> agents/bubbles(1200+)

## Polling
Frontend fetches `GET /status` every 2000ms. On state change, sprites show/hide.
Backend auto-reverts working states to idle after configurable TTL (default 300s).

## Multi-agent support
Guest agents map to same 3 zones with 8 predefined offset positions per zone to avoid overlap.

## Desktop pet version (Tauri)
- Tile-based map (`map.json`) with collision grid
- A* pathfinding for character movement
- 4-direction walking animation (4 frames each, 6fps)
- Idle wander: 0.3% chance per frame to walk to random nearby tile
- DOM-based speech bubbles, every 6-10s, displayed 3.5s with fade
- Transparent window overlay
