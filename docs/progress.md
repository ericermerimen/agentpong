# AgentPong Progress Tracker

Last updated: 2026-03-17 (pivot session)

## Current State

App builds and runs (`swift build`, 15 tests pass). Floating borderless window with Gemini room background. Real-time hook server receives Claude Code events and handles permissions. **Pivoted from character-per-session to pet + reactive screens concept.**

### What works
- Floating borderless window with shadow, rounded corners, right-click menu (Small 170x170 / Large 364x382)
- SpriteKit 60fps scene with Gemini room shell background
- HookServer on port 49152 -- receives real-time Claude Code events via HTTP
- hook-sender.sh reads stdin JSON from Claude Code, POSTs to HookServer
- Permission holding: PreToolUse with `permission_mode="ask"` holds HTTP connection, shows Allow/Deny UI
- Interactive permission bubbles (currently on characters, will migrate to screens)
- `agentpong setup` writes hook-sender.sh + updates ~/.claude/settings.json
- CLI: `agentpong report/setup/status`
- Session tracking: reads ~/.agentpong/sessions/*.json (polling + real-time)
- Cat mascot wanders with placeholder sprite (will become husky)
- Menu bar cube icon, hover close button
- Depth sorting (lower Y = in front)
- 15 tests passing (Session, SessionWriter/Reader, ZoneManager, Pathfinding, HookEvent, HookServer)

### What needs pivot work
- CharacterNode system (DELETE -- replaced by ScreenNode)
- Pathfinding module (DELETE -- not needed)
- DeskNode (DELETE)
- ZoneManager (REWRITE -- screen positions + pet wander bounds)
- OfficeScene character lifecycle (REWRITE -- screen state management)
- MascotNode (ADAPT -- cat -> husky, add screen reactions)
- Permission bubbles (MIGRATE -- from characters to screens)
- Background (REGENERATE -- cozy room with monitors, dog bed, open floor)

## Pivot Summary (2026-03-17)

**Old concept**: Characters represent sessions, walk between zones (desk/lounge/debug).
**New concept**: Cozy room with husky pet + 4 reactive monitor screens.

Why pivot:
- Old concept blocked on 130+ PixelLab sprites. New concept needs ~70.
- Screens-as-dashboard adds real utility (click to jump, approve permissions).
- Pet is the star -- charming even with 0 sessions.
- "Don't fake the dev around" -- screens are honest indicators.

What survives (70%):
- App shell, floating window, menu bar, CLI (100%)
- Session model, reader, writer (100%)
- HookServer + HookEvent + permission system (100%)
- hook-sender.sh (100%)
- Background loading pipeline (100%)
- MascotNode base logic (90% -- rename + adapt)

What's deleted/rewritten (30%):
- CharacterNode.swift (DELETE)
- Pathfinding.swift (DELETE)
- DeskNode.swift (DELETE)
- ZoneManager.swift (REWRITE)
- OfficeScene session management (REWRITE)

## Art Pipeline

**Hybrid approach (unchanged):**
- **Gemini** for background room (NEEDS REGENERATION for new concept)
- **PixelLab MCP** for sprites (husky character, animations, monitor sprites)

**PixelLab MCP tools:**
- `mcp__pixellab__create_character` -- husky with 4 directional views
- `mcp__pixellab__animate_character` -- walk cycle, idle, sleep, bark, play
- `mcp__pixellab__create_map_object` -- monitor screen sprites

**PixelLab status**: API key saved in ~/.agentpong/.env. Use MCP tools directly from Claude Code.

## Phase Status

### Phase 1: Foundations -- DONE
- [x] SPM project, Session model, SessionReader, SessionWriter
- [x] CLI: report, setup, status
- [x] Floating window (borderless, shadow, rounded corners, size presets)
- [x] Right-click context menu (Small/Large, Hide, Quit)
- [x] Menu bar cube icon
- [x] SpriteKit scene with background image loading (3-layer: bg/fg/overlay)
- [x] Room shell background generated and installed (Gemini)
- [x] HookServer (NWListener, loopback only, TCP buffered reader)
- [x] HookEvent + HookDecision + AnyCodable models
- [x] hook-sender.sh (stdin -> curl -> HookServer)
- [x] Permission holding (connection stays open for PreToolUse ask)
- [x] Interactive Allow/Deny permission bubbles
- [x] agentpong setup (writes hook script + updates Claude settings.json)
- [x] 15 tests passing

### Phase 2: Screens + Jump -- NEXT
- [ ] ScreenNode (4 fixed monitors: green/yellow/red/dim)
- [ ] Session-to-screen mapping (group by status, priority slots, count labels)
- [ ] Screen click handler (hover tooltip, click to jump)
- [ ] Port WindowJumper from AgentsHub
- [ ] Migrate permission bubbles from CharacterNode to ScreenNode
- [ ] Delete CharacterNode, Pathfinding, DeskNode
- [ ] Rewrite ZoneManager for screen positions + pet bounds
- [ ] Regenerate Gemini background (cozy room, monitors, dog bed, open floor)
- [ ] Update SpriteAssetLoader for new sprite categories
- [ ] Update tests (remove Pathfinding tests, add ScreenNode tests)

### Phase 3: Husky Pet
- [ ] Generate husky via PixelLab MCP `create_character` (4 dirs)
- [ ] Generate walk cycle via PixelLab MCP `animate_character`
- [ ] HuskyNode (adapted from MascotNode) with wander/scare
- [ ] Additional animations (sleep, drink, bark, play, sit)
- [ ] Rich idle behaviors (tail wag, head tilt, sniff, yawn)
- [ ] Dog bed zone, water bowl zone

### Phase 4: Pet-Screen Reactions
- [ ] Husky walks toward yellow/red screens
- [ ] Bark at errors, head tilt at warnings
- [ ] Happy bounce when all green, nap when all off
- [ ] Celebration on session completion

### Phase 5: Themes & Polish
- [ ] Day/night cycle
- [ ] Multiple room themes
- [ ] Sound effects, keyboard shortcuts
- [ ] PixelLab MCP monitor sprites (replace glow overlays)

## Key Files

| File | Purpose | Pivot status |
|---|---|---|
| Package.swift | SPM project definition | KEEP |
| Sources/App/AgentPongApp.swift | Main app, window, menu bar, CLI, HookServer | KEEP |
| Sources/SpriteEngine/OfficeScene.swift | Main scene, session management, hooks | ADAPT |
| Sources/SpriteEngine/Nodes/CharacterNode.swift | Character state machine | DELETE |
| Sources/SpriteEngine/Nodes/MascotNode.swift | Cat mascot | ADAPT -> HuskyNode |
| Sources/SpriteEngine/Nodes/DeskNode.swift | Desk furniture | DELETE |
| Sources/SpriteEngine/ZoneManager.swift | Zone coordinates | REWRITE |
| Sources/SpriteEngine/Pathfinding.swift | BFS grid pathfinding | DELETE |
| Sources/Shared/Session.swift | Session model | KEEP |
| Sources/Shared/SessionReader.swift | Reads session JSON files | KEEP |
| Sources/Shared/SessionWriter.swift | Writes session JSON | KEEP |
| Sources/Shared/HookServer.swift | Local HTTP server for hook events | KEEP |
| Sources/Shared/HookEvent.swift | Hook event model + decisions | KEEP |
| Sources/Shared/SpriteAssetLoader.swift | Loads sprites | ADAPT |
| Scripts/hook-sender.sh | stdin->curl bridge | KEEP |

## Data Locations

| Path | Contents |
|---|---|
| ~/.agentpong/.env | API keys (GOOGLE_AI_API_KEY, PIXELLAB_API_KEY) |
| ~/.agentpong/sessions/*.json | Active session data |
| ~/.agentpong/hooks/hook-sender.sh | Hook bridge script (written by setup) |
| ~/.agentpong/themes/background.png | Room background layer (Gemini) |
| ~/.agentpong/themes/foreground.png | Room foreground layer (Gemini) |
| ~/.agentpong/sprites/ | Sprite assets (PixelLab MCP generated) |

## Next Steps (Priority Order)

1. Build ScreenNode + session-to-screen mapping
2. Wire click handlers + port WindowJumper
3. Migrate permission bubbles to screens
4. Delete old character code
5. Regenerate Gemini background for new room concept
6. Generate husky via PixelLab MCP
7. Build HuskyNode with behaviors
8. Add pet-screen reactions
