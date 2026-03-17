# AgentPong Progress Tracker

Last updated: 2026-03-16 (end of session 1)

## Current State

App builds and runs (`swift build`, 15 tests pass). Floating borderless window with proper room shell background. Characters are still colored square placeholders. Engine is functional, art is the blocker.

### What works
- Floating borderless window with shadow, rounded corners, right-click menu (Small 170x170 / Large 364x382)
- SpriteKit 60fps scene with Gemini room shell background (dark cozy nighttime office)
- Characters walk from door to assigned zones based on session status
- CLI: `agentpong report/setup/status` for Claude Code hook integration
- Session tracking: reads ~/.agentpong/sessions/*.json
- Monitor glow overlay, server rack blinks, coffee steam, status text
- Menu bar cube icon, hover close button
- Depth sorting (lower Y = in front)
- BFS pathfinding (built but not used -- using direct movement currently)
- Window corner colors matched to room border for seamless rounded corners

### What's placeholder / broken
- Characters are colored squares (need PixelLab sprites)
- Furniture is colored rectangles (need PixelLab sprites)
- Zone positions approximate (need fine-tuning once real sprites exist)
- Hover tooltips don't scale well in small view
- No cat mascot, no day/night, no door animation yet

## Art Pipeline (DECIDED)

**Hybrid approach confirmed:**
- **Gemini** for background room shell (DONE -- installed at ~/.agentpong/themes/default.png)
- **PixelLab** for all sprites (characters, furniture, cat, effects)
- Style reference trick: generate one from PixelLab first, use for all subsequent assets
- Full sizing strategy documented in `docs/art-pixel-sizing-strategy.md`

**Room shell background**: Dark cozy nighttime office, empty room with wood floor, thin walls, window with moon/stars, door opening bottom-right. Warm subtle lighting. Generated from Gemini AI Studio.

**PixelLab status**: API key saved in ~/.agentpong/.env. Free tier credits depleted (402). Replenishes 5 slow gens/day. Tier 1 ($12/mo) would unblock everything.

## Phase Status

### Phase 1: Foundations -- DONE
- [x] SPM project, Session model, SessionReader, SessionWriter
- [x] CLI: report, setup, status
- [x] Floating window (borderless, shadow, rounded corners, size presets)
- [x] Right-click context menu (Small/Large, Hide, Quit)
- [x] Menu bar cube icon
- [x] SpriteKit scene with background image loading
- [x] Room shell background generated and installed (Gemini)
- [x] 15 tests passing

### Phase 2: Characters Walk -- PARTIAL (blocked on sprites)
- [x] CharacterNode state machine (idle/walking/working/alerting/departing)
- [x] Walk animation (SKAction.move with bob)
- [x] Typing animation (lateral shake)
- [x] Idle animation (breathing scale)
- [x] Alert state (red color, ! bubble)
- [x] Speech bubbles (!, ?, done) with pulse
- [x] Monitor glow overlay when desk occupied
- [x] Depth sorting by Y position
- [x] SpriteAssetLoader (loads from ~/.agentpong/sprites/, colored square fallback)
- [x] Characters enter from door, walk to zone, depart to door
- [x] BFS pathfinding module (ready but using direct movement for now)
- [ ] **BLOCKED: PixelLab character sprites (4 dirs x walk/idle/sit/type)**
- [ ] **BLOCKED: PixelLab furniture sprites (desk, chair, sofa, server rack, etc.)**
- [ ] Zone position fine-tuning (after real sprites)

### Phase 3: Office Comes Alive -- NOT STARTED
- [ ] Mascot cat
- [ ] Day/night cycle
- [ ] Door open/close
- [ ] Enhanced ambient effects
- [ ] Fun features (cat sabotage, deploy chaos, Friday deploy)

### Phase 4: Widget -- KILLED

### Phase 5: Progression & Themes -- NOT STARTED
### Phase 6: Polish & Delight -- NOT STARTED

## Key Files

| File | Purpose |
|---|---|
| Package.swift | SPM project definition |
| Sources/App/AgentPongApp.swift | Main app, window, menu bar, CLI |
| Sources/SpriteEngine/OfficeScene.swift | Main scene, layers, session management |
| Sources/SpriteEngine/Nodes/CharacterNode.swift | Character state machine + animations |
| Sources/SpriteEngine/ZoneManager.swift | Zone coords mapped to background |
| Sources/SpriteEngine/Pathfinding.swift | BFS grid pathfinding |
| Sources/Shared/Session.swift | Session model |
| Sources/Shared/SessionReader.swift | Reads session JSON files |
| Sources/Shared/SessionWriter.swift | Writes session JSON from CLI |
| Sources/Shared/SpriteAssetLoader.swift | Loads sprites, fallback to placeholders |
| Scripts/pixellab-generate.py | PixelLab API generation (needs credits) |
| Scripts/generate-background.py | Gemini API background gen (needs billing) |
| Scripts/install-background.sh | Manual background install |
| docs/art-pixel-sizing-strategy.md | Full 130-sprite list, sizing, Retina strategy |
| docs/plans/pixel-office-widget-plan.md | Complete plan with all decisions |
| ~/.claude/skills/pixellab/SKILL.md | PixelLab API skill for reuse |

## Data Locations

| Path | Contents |
|---|---|
| ~/.agentpong/.env | API keys (GOOGLE_AI_API_KEY, PIXELLAB_API_KEY) |
| ~/.agentpong/sessions/*.json | Active session data |
| ~/.agentpong/themes/default.png | Room shell background (Gemini, 1024x1024) |
| ~/.agentpong/sprites/ | Sprite assets (currently empty, waiting for PixelLab) |

## Next Session Priority
1. Generate PixelLab sprites (wait for credits or upgrade to Tier 1)
   - Style reference first
   - Character with 4 directions
   - Desk, chair, sofa, server rack, plant, coffee machine
2. Wire sprites into SpriteAssetLoader
3. Fine-tune zone positions to match sprite placement
4. Remove placeholder colored squares and rectangles
5. Then Phase 3: cat, day/night, door
