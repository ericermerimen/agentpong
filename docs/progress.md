# AgentPong Progress Tracker

Last updated: 2026-03-18 (v1.0.0 ship review)

## Current State

**v1.0.0 -- feature complete.** App builds and runs. Floating borderless window with Gemini room background, triple monitors with decorative textures, husky pet with 12+ behaviors, real-time hook events, click-to-jump, permission approval, info overlay. Homebrew formula, build script, and README ready.

### What works

- Floating borderless window with shadow, rounded corners, right-click menu (Small 170x170 / Large 364x382)
- SpriteKit 60fps scene with Gemini room background (1024x1024, 3-layer: bg/fg/objects)
- Triple monitor system with perspective-correct trapezoid overlays
- Decorative screen textures that rotate by status category (working/waiting/idle/error)
- Monitor glow, pulse, hover highlight, status flash transitions
- HookServer on port 52775 -- receives real-time Claude Code events via HTTP
- hook-sender.sh reads stdin JSON from Claude Code, POSTs to HookServer (jq optional)
- Permission holding: PreToolUse with `permission_mode="ask"` holds HTTP connection, shows Allow/Deny bubble
- Click-to-jump: info overlay lists all sessions, click a row to activate that terminal
- WindowJumper: process tree walk from Claude PID to terminal app
- Husky pet with 12+ behaviors: wander, sit, lie down, sleep, play, drink, zoomies, look around, watch cursor, bark, head tilt, scare
- Husky screen reactions: barks at errors, tilts head at warnings, naps when all off, wakes on activity
- Perspective scaling + depth sorting for husky and foreground objects
- Floor status text with 3D perspective (multiply blend mode)
- `agentpong setup` writes hook-sender.sh + updates ~/.claude/settings.json
- `agentpong --version` prints current version
- CLI: report, setup, status
- Session tracking: reads ~/.agentpong/sessions/*.json (polling 5s + real-time)
- Menu bar cube icon, hover close button, context menu with session submenu
- 15 tests passing (Session, SessionWriter/Reader, ZoneManager, HookEvent, HookServer)
- Build script (Scripts/build-app.sh) creates .app bundle from SPM
- Makefile: build, app, install, archive, clean
- Homebrew formula template (Formula/agentpong.rb)

## Phase Status

### Phase 1: Foundations -- DONE
- [x] SPM project, Session model, SessionReader, SessionWriter
- [x] CLI: report, setup, status, --version
- [x] Floating window (borderless, shadow, rounded corners, size presets)
- [x] Right-click context menu (Small/Large, session list, Hide, Quit)
- [x] Menu bar cube icon
- [x] SpriteKit scene with background image loading (3-layer: bg/fg/overlay)
- [x] Room shell background generated and installed (Gemini)
- [x] Foreground objects (lamp, plant, water bowl) as separate depth-sorted nodes
- [x] HookServer (NWListener, loopback only, TCP buffered reader)
- [x] HookEvent + HookDecision + AnyCodable models
- [x] hook-sender.sh (stdin -> curl -> HookServer, jq optional)
- [x] Permission holding (connection stays open for PreToolUse ask)
- [x] Interactive Allow/Deny permission bubbles
- [x] agentpong setup (writes hook script + updates Claude settings.json)
- [x] 15 tests passing

### Phase 2: Screens + Jump -- DONE
- [x] ScreenNode (3 fixed monitors, perspective trapezoid, color states, glow effects)
- [x] Session-to-screen mapping (sorted by priority, center gets highest)
- [x] Decorative screen textures with content pools and rotation timer
- [x] Screen click handler (hover highlight, click shows info overlay)
- [x] Info overlay (fullscreen session list, row hover, click-to-jump)
- [x] WindowJumper (PID walk, bundle ID matching, AppleScript fallback)
- [x] Permission bubbles on ScreenNode (migrated from old CharacterNode)
- [x] Deleted old code: CharacterNode, Pathfinding, DeskNode
- [x] ZoneManager rewrite (triple monitors, pet zones, perspective scaling)
- [x] Gemini background regenerated (cozy room with monitors, dog bed, open floor)
- [x] SpriteAssetLoader updated (husky-pro, screen textures)

### Phase 3: Husky Pet -- DONE
- [x] Husky with real PixelLab sprites (88px pro + 128px behavior sprites)
- [x] Walk cycle (8 directions, mirroring east->west)
- [x] Run cycle (for zoomies and scare)
- [x] HuskyNode with weighted random behavior selection
- [x] Behaviors: wander, sit, lie down, sleep, play, drink, zoomies, look around, watch cursor
- [x] Bark animation (screen reaction)
- [x] Dog bed zone (husky naps here when all screens off)
- [x] Water bowl zone (random drink behavior)
- [x] Shadow with radial gradient texture
- [x] Click interaction (play reaction, 3x = scare)

### Phase 4: Pet-Screen Reactions -- DONE
- [x] Husky walks toward red screens, barks
- [x] Head tilt at yellow screens
- [x] Nap when all screens off for >30s
- [x] Wake up on new activity
- [x] Scare reaction (sprint to far corner)

### v1.0.0 Ship -- DONE
- [x] VERSION file + AppVersion constant
- [x] `agentpong --version` CLI command
- [x] Port alignment (52775 everywhere)
- [x] jq fallback in hook-sender.sh
- [x] Build script (Scripts/build-app.sh)
- [x] Makefile (build, app, install, archive, clean)
- [x] Homebrew formula template
- [x] README.md

## Future Ideas (not planned)

These are deferred ideas that may or may not happen. None are needed for v1.

- Day/night cycle (tint from system clock)
- Multiple room themes + theme switcher
- Sound effects (toggleable)
- Keyboard shortcuts (show/hide, resize)
- PixelLab monitor sprites (replace SpriteKit glow overlays)
- Progression/leveling system
- Room upgrades at milestones
- Pet accessories/toys
- Multiple pets
- Happy bounce when all sessions green
- Celebration on session completion

## Key Files

| File | Purpose |
|------|---------|
| Package.swift | SPM project definition |
| VERSION | Version number (read by build script) |
| Makefile | Build, install, archive targets |
| Sources/App/AgentPongApp.swift | Main app, window, menu bar, CLI, HookServer |
| Sources/SpriteEngine/OfficeScene.swift | Main scene, screen management, hooks, overlay |
| Sources/SpriteEngine/Nodes/ScreenNode.swift | Monitor with trapezoid overlay, status, textures |
| Sources/SpriteEngine/Nodes/HuskyNode.swift | Pet sprite + 12 behaviors + screen reactions |
| Sources/SpriteEngine/ScreenContentManager.swift | Decorative texture rotation by status |
| Sources/SpriteEngine/ZoneManager.swift | Monitor positions, pet zones, perspective |
| Sources/Shared/Session.swift | Session model |
| Sources/Shared/SessionReader.swift | Reads session JSON files |
| Sources/Shared/SessionWriter.swift | Writes session JSON |
| Sources/Shared/HookServer.swift | Local HTTP server for hook events |
| Sources/Shared/HookEvent.swift | Hook event model + decisions |
| Sources/Shared/WindowJumper.swift | Activate session terminal window |
| Sources/Shared/SpriteAssetLoader.swift | Loads sprites with caching |
| Sources/Shared/Version.swift | App version constant |
| Scripts/hook-sender.sh | stdin->curl bridge for Claude Code hooks |
| Scripts/build-app.sh | Build .app bundle from SPM |
| Formula/agentpong.rb | Homebrew formula template |

## Data Locations

| Path | Contents |
|------|----------|
| ~/.agentpong/sessions/*.json | Active session data |
| ~/.agentpong/hooks/hook-sender.sh | Hook bridge script (written by setup) |
| ~/.agentpong/server-port | HTTP server port (written on startup) |
| ~/.agentpong/themes/background.png | Room background layer (Gemini) |
| ~/.agentpong/themes/foreground.png | Room foreground layer (Gemini) |
| ~/.agentpong/sprites/ | Sprite assets (PixelLab MCP generated) |
