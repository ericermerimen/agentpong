# Decorative Monitor Screens + Floor Status Text

## Summary

Replace the current status-overlay monitor system with decorative pixel art content that reflects session state through vibe, not raw data. Move all session status information to perspective-correct floor text.

## Screen Content Model

### Content pools by session state

Instant swap when the highest-priority status changes category.

| State | Center monitor | Side monitors | Vibe |
|-------|---------------|---------------|------|
| **Working** (any running) | Code editor, Xcode, terminal | Claude/ChatGPT, browser/docs, one random (YouTube/Reddit) | "in the zone" with human touch |
| **Waiting** (needsInput, no running) | Claude/ChatGPT conversation | Browser, docs | "waiting for the AI" |
| **Idle** (all idle) | Social media (X, Threads, Reddit) | YouTube, trading charts, news | "killing time" |
| **No sessions** | Social media, random browsing | YouTube, entertainment, dashboards | "off the clock" |
| **Error** | Terminal with red text | Stack Overflow, docs | "debugging panic" |

### Behavior

- **Instant swap** when status category changes (working -> idle, etc.). Correct feedback to user about what agents are doing.
- Within same category, screens rotate content every 45-60s.
- Each monitor picks randomly from its pool. No duplicates across the 3 screens at the same time.
- Side monitors show impressionistic versions (color signature + layout shape, not readable text).

## PixelLab Assets (~18 textures)

All generated via PixelLab MCP with same style reference for consistency.

### Center monitor textures (detailed, ~148x70 image pixels)

| ID | Description |
|----|-------------|
| center-code-editor | Dark theme code editor with syntax highlighting |
| center-terminal | Terminal with green/white text on black |
| center-xcode-mobile | Xcode with phone simulator preview |
| center-claude-chat | Claude conversation interface |
| center-chatgpt-chat | ChatGPT conversation interface |
| center-browser-docs | Browser with documentation page |
| center-stackoverflow | Stack Overflow question page |
| center-twitter-feed | X/Twitter feed with posts |
| center-reddit-feed | Reddit feed |
| center-threads-feed | Threads feed |
| center-youtube-player | YouTube video player |
| center-trading-chart | Trading chart with candlesticks |

### Side monitor textures (impressionistic, ~32x38 / ~46x60 image pixels)

| ID | Description |
|----|-------------|
| side-code | Dark theme with colored horizontal lines |
| side-terminal | Black with green/white dots |
| side-ai-chat | Chat bubble pattern |
| side-browser | White-ish page with content blocks |
| side-social | Feed-like colored blocks |
| side-chart | Chart pattern with colored bars/lines |

## Floor Status Text

### Content

- Multi-line, one status per row: `1 working`, `2 idle`
- Positioned in the lamp spotlight area (center floor, ~x:165, y:65 scene)
- White text with `.add` blend mode, ~30% opacity
- Large enough to read at 170px small window (~18-20pt scene)

### Perspective

- Room viewed from ~60 degree elevated top-down angle
- Vanishing point at center-top (desk/wall junction, ~y:260 scene)
- Text must match the floor plane perspective:
  - `rotateX` to tilt text into the floor (foreshortening)
  - Slight `rotateZ` to align with floor plank angle
- Compute transform by analyzing floor plank lines in background image for actual vanishing point

## Bug Fixes (prerequisite)

### Monitor overlay coordinates

- Re-scan left and right monitor pixel boundaries (current overlays don't match)
- Center monitor still leaks on waiting (yellow) state -- verify crop node
- Use programmatic pixel brightness analysis (not eyeballing)

### Session list overlay UX

- Cursor pointer on session rows and X close button
- Row hover feedback (brightness/highlight change)
- Font sizes readable at 170px small window

## Architecture Changes

### ScreenNode

- Replace status color fill with texture display (`SKSpriteNode` with loaded texture)
- Remove `statusLabel` and `detailLabel` from screen surface
- Keep the crop node (text/texture must not extend beyond screen bounds)
- New method: `showTexture(_ texture: SKTexture)` replaces `assignSession`
- Keep `status` property for husky reactions
- Keep click handler for opening session list overlay

### OfficeScene

- New `ScreenContentManager` (or inline in OfficeScene):
  - Holds content pool arrays per category
  - On status change: instant swap to new category's content
  - Timer: rotate within category every 45-60s
  - Picks random non-duplicate textures for 3 screens
- Floor text: replace current label with perspective-correct transform
- Session list overlay: triggered by clicking any monitor (shows all sessions)

### SpriteAssetLoader

- New methods: `screenTexture(named:)` loading from `~/.agentpong/sprites/screens/`
- Textures organized by: `screens/center-*.png`, `screens/side-*.png`

## File locations

- Screen textures: `~/.agentpong/sprites/screens/`
- Center textures: `center-{name}.png`
- Side textures: `side-{name}.png`
