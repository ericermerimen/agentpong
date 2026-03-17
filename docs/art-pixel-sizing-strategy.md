# Pixel Art Sizing Strategy & Asset Generation Guide

Production-grade sizing plan for 320x320 macOS floating window + Retina + SpriteKit 60fps.

## 1. Pixel Grid

| Property | Value |
|---|---|
| Tile size | 16px logical / 32px authored |
| Grid | 20 x 20 tiles |
| Scene | 320 x 320 logical |
| Retina render | 640 x 640 actual |

**Why 16px tiles:**
- Pixel perfect: 320 / 16 = 20 tiles
- Good density for detail
- Retina friendly (2x scaling via `.nearest` filtering)

## 2. Retina Scaling Strategy

Author all sprites at native resolution. SpriteKit `filteringMode = .nearest` ensures pixel-crisp on Retina displays. This is standard for pixel games.

```swift
scene.size = CGSize(width: 320, height: 320)
scene.scaleMode = .aspectFit
texture.filteringMode = .nearest  // pixel-crisp, no blur
```

## 3. Scene Layout (Cozy Room)

```
┌──────────────────────────────────────┐
│  [window]     [lamp]                 │  <- wall with window, day/night
│                                      │
│  [monitor1] [monitor2]  [monitor3]   │  <- desk with 3 monitors
│  ─────────desk surface──────────     │
│                                      │
│          [open floor]     [monitor4] │  <- side monitor / server
│                                      │
│     husky wanders here               │
│                                      │
│  [dog bed]    [water bowl]  [plant]  │  <- pet zones
│                                      │
└──────────────────────────────────────┘
```

Zone mapping:
- y 0-3: top wall + window
- y 3-5: desk row with monitors
- y 5-8: open floor (husky wander area)
- y 8-10: pet zones (dog bed, water bowl) + plants

## 4. PixelLab MCP Asset Generation

Generate via PixelLab MCP tools. All use same style reference for consistency.

### Style Reference (generate FIRST)

Use `mcp__pixellab__create_character` with description:
```
cozy pixel art style
warm lighting
retro RPG aesthetic
stardew valley inspired
dark nighttime atmosphere
```
Pass the resulting style reference to ALL subsequent calls.

### A. Husky Character

**Tool:** `mcp__pixellab__create_character` (4 directional views)

```
Description: cute husky dog, fluffy, grey and white fur,
blue eyes, friendly expression, pixel art style
```

Directions: north, south, east, west (west = flipped east)
Size: 32x32 per direction

### B. Husky Animations

**Tool:** `mcp__pixellab__animate_character`

| Animation | Frames | Notes |
|---|---|---|
| Walk (4 dirs) | 6 each | Main movement |
| Idle: tail wag | 4 | Subtle, looping |
| Idle: head tilt | 4 | Curiosity reaction |
| Idle: sniff ground | 4 | Random behavior |
| Idle: yawn | 4 | Sleepy behavior |
| Sleep | 2 | Curled up, zzz |
| Drink water | 4 | At bowl |
| Bark / alert | 4 | Error reaction |
| Sit | 2 | Resting pose |
| Play | 6 | Chase tail / toy |

### C. Monitor Sprites

**Tool:** `mcp__pixellab__create_map_object`

| Sprite | Size | Notes |
|---|---|---|
| monitor_off | 24x20 | Dark screen, powered off |
| monitor_green | 24x20 | Code/terminal, green tint |
| monitor_green_2 | 24x20 | Alt frame for scrolling effect |
| monitor_yellow | 24x20 | Warning, yellow tint |
| monitor_yellow_2 | 24x20 | Alt frame for pulse |
| monitor_red | 24x20 | Error, red tint |
| monitor_red_2 | 24x20 | Alt frame for flash |

### D. Room Objects (optional, can be baked into Gemini background)

| Object | Size | Tool |
|---|---|---|
| dog_bed | 32x24 | create_map_object |
| water_bowl | 16x12 | create_map_object |
| plant_small | 16x24 | create_map_object |
| lamp | 16x24 | create_map_object |

## 5. Total Asset Count

| Category | Count |
|---|---|
| Husky standing (4 dirs) | 4 |
| Husky walk frames | 24 |
| Husky behavior frames | 30 |
| Monitor sprites | 7 |
| Room objects (optional) | 4 |
| **TOTAL** | **~70 sprites** |

Down from ~130 in the old character-per-session plan.

## 6. SpriteKit Configuration

```swift
// Scene
scene.size = CGSize(width: 320, height: 320)
scene.scaleMode = .aspectFit

// Husky
huskyNode.size = CGSize(width: 32, height: 32)

// Monitors (screen overlays on background)
screenNode.size = CGSize(width: 24, height: 20)

// CRITICAL for pixel art
texture.filteringMode = .nearest
```

## 7. Gemini Background Prompt

New room optimized for pet + screens concept:

```
top-down pixel art cozy room
warm den/study atmosphere
desk against top wall with 3-4 monitor outlines (dark/off screens)
open floor space in center for a pet to walk
dog bed in bottom-left corner
water bowl near dog bed
small plant in corner
warm ceiling lamp with glow
window on wall showing night sky
wood floor, warm colors
no characters, no pets, no text
retro 8-bit RPG pixel style
320x320 pixels
```

Important: monitors should be baked into background as "off" state. SpriteKit overlays colored glow sprites on top when sessions are active.

## 8. Style Consistency Tips

1. Generate PixelLab style reference FIRST from a warm cozy pixel art prompt
2. Pass `style_reference_id` to ALL subsequent PixelLab MCP calls
3. Match palette warmth between Gemini background and PixelLab sprites
4. Use same view angle (top-down / low top-down) for all assets
5. Test sprite placement on background before generating full set

## 9. SpriteKit Animation Pattern

Animate husky at 60fps while using 12fps sprite frames:

```swift
// 12fps sprite animation inside 60fps game loop
let walkFrames: [SKTexture] = [...]  // 6 frames
let animateSprite = SKAction.animate(with: walkFrames, timePerFrame: 1.0/12.0)
character.run(SKAction.repeatForever(animateSprite))
// Movement is separate, runs at 60fps via SKAction.move
```

This gives crispy sprite animation + butter-smooth movement.
