# Pixel Art Sizing Strategy & Asset Generation Guide

Production-grade sizing plan for 320x320 macOS widget + Retina + SpriteKit 60fps.

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
- Easy BFS pathfinding
- Retina friendly (2x scaling)

## 2. Retina Scaling Strategy

PixelLab Tier 1 max: **320x320**. So we author at native 320x320.

**Workflow:**
- Author all sprites at **16px tiles** (native)
- Scene size: 320x320
- SpriteKit `filteringMode = .nearest` ensures pixel-crisp on Retina
- This is how every classic pixel game works -- no blur, sharp pixels at any display scale

**Alternative (if needed later):** Generate 32x32 tiles individually, stitch into 640x640 via script. Not needed for now.

## 3. Scene Tile Layout (20 x 20)

```
WWWWWWWWWWWWWWWWWWWW
W....window......SW
W................SW
W..DD..DD..DD..DD.W    <- desk row (y: 3-4)
W..DD..DD..DD..DD.W
W.................W
W......sofa.......W    <- lounge (y: 6)
W.................W
W....plant..plant.W    <- plants (y: 8)
W..............door    <- door (y: 9, right side)
WWWWWWWWWWWWWWWWWWWW

W = wall, D = desk, S = server rack
```

Zone mapping:
- y 0-3: top wall + window
- y 3-5: desk row (4 desks)
- y 5-7: lounge (sofa area)
- y 7-9: door + plants + floor

## 4. PixelLab Asset Generation List

Generate in this order. All use same style reference.

### Style Reference Prompt (generate FIRST)
```
cozy pixel office environment
top-down perspective
warm lighting
retro RPG pixel style
stardew valley inspired
dark nighttime atmosphere
```
Pass `style_reference_id` to all subsequent requests.

### A. Tile Set (~15 tiles, 32x32 each)
```
floor_wood_1
floor_wood_2
floor_wood_shadow
wall_top
wall_left
wall_right
wall_corner
window_night
window_day
lamp_light
carpet_tile
door_frame_tile
```

### B. Desk Set (64x32)
```
desk_empty
desk_with_monitor_off
desk_with_monitor_on
desk_typing
desk_with_keyboard
```

### C. Office Chair (32x32)
```
chair_front
chair_back
chair_left
chair_right
chair_spin_animation
```

### D. Coffee Machine (32x32)
```
coffee_idle
coffee_brew
coffee_ready
coffee_steam
```

### E. Server Rack (32x48)
```
server_idle
server_processing
server_error
server_fixing
server_overheat
```

### F. Sofa (64x32)
```
sofa_empty
sofa_sit_left
sofa_sit_right
```

### G. Plants (32x32)
```
plant_small
plant_big
plant_shadow
```

### H. Door (32x48)
```
door_closed
door_open
door_half
door_glow_night
```

Prompt tip: "strong contrast from wall, visible door frame, pixel shadow on floor"

### I. Monitor Screen States (24x16)
```
monitor_off
monitor_code
monitor_terminal
monitor_social
monitor_video
monitor_error
monitor_success
```

### J. Character Sprite Sheet (32x32)

Use PixelLab: `POST /create-character-with-4-directions`

```
Directions: up/down/left/right
Walk: 6 frames per direction
Idle: 4 frames
Typing: animation
Sitting: animation
```

States needed:
```
walk
idle
typing
debugging
alert
celebrate
```

### K. Mascot Cat (24x24)
```
cat_idle
cat_walk (4 dirs)
cat_sleep
cat_jump_desk
cat_tail_wag
cat_drink_coffee
```

### L. Speech Bubbles (16x16)
```
bubble_question
bubble_alert
bubble_done
bubble_typing
bubble_sleep
```

### M. Ambient Objects

Fan (32x32): 4 rotation frames
Clock (16x16): day/night/tick
Lamp glow overlay: small/large

## 5. Total Asset Count

| Category | Count |
|---|---|
| Tiles | ~15 |
| Furniture | ~25 |
| Interactive objects | ~20 |
| Character frames | ~40 |
| Cat frames | ~20 |
| UI elements | ~10 |
| **TOTAL** | **~130 sprites** |

Normal for pixel games.

## 6. SpriteKit Configuration

```swift
// Scene
scene.size = CGSize(width: 320, height: 320)
scene.scaleMode = .aspectFit

// Tiles
let tileSize: CGFloat = 16  // native authored size

// Characters
characterNode.size = CGSize(width: 16, height: 16)

// Textures -- CRITICAL for pixel art
texture.filteringMode = .nearest  // no blur, pixel-crisp on Retina
```

## 7. Character Interaction Triggers

Tile-based interaction:
- Desk tile -> typing state
- Sofa tile -> sit state
- Coffee tile -> drink animation
- Server tile -> debug animation
- Distance threshold: < 1 tile

## 8. Fun Addictive Features

### Deploy Chaos
Random event: `production_error`. Character runs to server.

### Cat Sabotage
Cat randomly: `sit_on_keyboard`, `disconnect_network`, `steal_coffee`

### Late Night Mode
After midnight: lights dim, characters slower, cat sleeps

### Friday Deploy
Random event: "Deploy Friday?" If accepted: server explosion animation

## 9. PixelLab Consistency Tips

1. Generate style reference FIRST
2. Pass `style_reference_id` to ALL subsequent requests
3. Use same view/outline/shading/detail across everything
4. Generate related assets in same session

Settings for all assets:
```json
{
  "view": "low top-down",
  "outline": "single color outline",
  "shading": "medium shading",
  "detail": "medium detail"
}
```

## 10. Production Pipeline: Gemini + PixelLab Hybrid

**Confirmed approach** (from external API consultation):

PixelLab alone will NOT match Gemini's rich atmospheric quality. The correct pipeline:

```
Gemini → background scene (lighting, atmosphere, room shell)
PixelLab → sprites / objects / characters (consistent pixel grid, animation frames)
```

### Why this split works

| Tool | Strength | Weakness |
|---|---|---|
| Gemini | Lighting gradients, atmospheric shadows, cohesive scene composition, decorative details | Can't do consistent sprite sheets or animations |
| PixelLab | Consistent pixel grids, sprite sheets, animation frames, object reuse | Produces simpler "Stardew Valley" look, less atmospheric |

### Expected quality match to Gemini concept art

| Element | Similarity |
|---|---|
| Lighting | 90% |
| Furniture | 80% |
| Atmosphere | 90% |
| Layout | 100% |
| Pixel style | 85-95% |

PixelLab objects will be slightly simpler than Gemini concept art. That's actually good for games (cleaner sprites, better at small sizes).

### CRITICAL: Style Reference Trick

To keep PixelLab assets matching the Gemini background:

1. Generate a **style reference** first:
```
top-down cozy pixel office
warm night lighting
wood furniture
indoor plants
retro RPG pixel art
stardew valley style
```

2. Feed that `style_reference_id` to EVERY PixelLab asset request
3. This forces: same palette, same shading, same lighting direction
4. Without this, assets WILL look mismatched

### Clean Gemini Background Prompt

The Gemini background must be EMPTY (no baked furniture):

```
top-down pixel art office room
empty room layout
wood floor
walls with window
warm ceiling lamp lighting
no furniture, no characters, no desks, no chairs
only room structure
retro 8-bit cozy pixel style
320x320 pixels
```

Then all furniture = PixelLab sprites placed by SpriteKit.

### Monitor Screen Ideas

Since the app tracks Claude sessions, monitors could show:
- Terminal scrolling animation
- Claude logo
- Git commit progress
- Deploy progress bar
- Error screen (red)
- Success screen (green)

This makes the office feel like live developer activity.

### The Cat is the Killer Feature

The mascot cat is what makes users watch even with 0 sessions:
- Sleeping on sofa
- Walking across desks
- Blocking keyboard (sits on it)
- Drinking coffee
- Watching workers type

Key to stickiness.

### SpriteKit Animation Trick

Animate characters at 60fps while only using 12fps sprite frames:
- SpriteKit runs at 60fps game loop
- Character sprite frames change at 12fps (every 5 game frames)
- Movement interpolation at 60fps (smooth walking)
- Result: crispy sprite animation + butter-smooth movement

```swift
// 12fps sprite animation inside 60fps game loop
let walkFrames: [SKTexture] = [...]  // 4-6 frames
let animateSprite = SKAction.animate(with: walkFrames, timePerFrame: 1.0/12.0)
character.run(SKAction.repeatForever(animateSprite))
// Movement is separate, runs at 60fps via SKAction.move
```

## 11. Remaining TODO from External Review

Three things offered that would be valuable:
1. **Exact 20x20 tile coordinate layout** -- so pathfinding works perfectly and characters never clip furniture
2. **Complete PixelLab asset generation script** (~30 API calls) -- auto-builds the whole sprite pack
3. **60fps/12fps animation implementation** -- the SpriteKit trick described above

These should be built in the next session once art approach is confirmed.
