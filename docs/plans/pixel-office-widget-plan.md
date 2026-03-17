# AgentPong -- Cozy Room with Pet & Reactive Screens

## Overview

A macOS floating window showing a cozy pixel art room where a husky pet wanders around doing pet things. Monitors on the wall/desk react to active Claude Code sessions -- green for running, yellow for needs-input, red for errors. Click a screen to jump to that session or approve permissions. The pet reacts to screen state changes (barks at errors, naps when idle).

**Standalone app** -- no AgentPing dependency. Has its own Claude Code hook integration with real-time event delivery via local HTTP server.

## Key Design Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Primary metaphor | Pet + reactive screens | Simpler than character-per-session. Fewer sprites (~60 vs 130). Actually interactive. |
| Session visualization | 4 fixed monitor slots (green/yellow/red/dim) | Category-based dashboard, not 1:1 mapping. Scales infinitely. |
| Pet | Husky (one character, rich animations) | Star of the show. Reacts to session state. Charming with 0 sessions. |
| Interactivity | Click screens to jump/approve, click pet to play | Real utility, not just eye candy. Permission approval from the widget. |
| Real-time events | Local HTTP server (HookServer, port 49152) | Instant updates vs 5s polling. Enables permission holding. |
| Sprite source | PixelLab MCP (husky + monitor sprites) + Gemini (background) | PixelLab MCP tools for consistent sprite sheets. Gemini for atmospheric rooms. |
| Window | NSPanel floating, always-on-top, draggable | Same as before. SpriteKit 60fps inside. |

## Architecture

```
AgentPong.app
├── App/                              # Main app target
│   └── AgentPongApp.swift            # @main, window, menu bar, CLI, HookServer startup
│
├── SpriteEngine/                     # SpriteKit scene (floating window)
│   ├── OfficeScene.swift             # SKScene, 60fps loop, screen management, click handlers
│   ├── Nodes/
│   │   ├── ScreenNode.swift          # Monitor with color states, count label, glow, click target
│   │   ├── HuskyNode.swift           # Pet sprite + behaviors + screen reactions
│   │   ├── BubbleNode.swift          # Permission/info bubbles on screens
│   │   └── AmbientNode.swift         # Plants, lamp, decorative elements
│   └── ZoneManager.swift             # Screen positions, pet wander bounds
│
├── Shared/                           # Shared framework
│   ├── Session.swift                 # Codable model
│   ├── SessionReader.swift           # Reads ~/.agentpong/sessions/
│   ├── SessionWriter.swift           # Writes session JSON
│   ├── HookServer.swift              # Local HTTP server for real-time hook events
│   ├── HookEvent.swift               # Hook event model + permission decisions
│   ├── WindowJumper.swift            # Activate session terminal window (ported from AgentsHub)
│   ├── SpriteAssetLoader.swift       # Load sprites, placeholder fallback
│   └── ThemeManager.swift            # Background + palette per theme (future)
│
├── Scripts/
│   └── hook-sender.sh                # stdin→curl bridge for Claude Code hooks
└── Resources/
    └── progression-levels.json       # Level thresholds (future)
```

## Data Flow

```
Claude Code hooks (all events)
    │
    ▼
hook-sender.sh (reads stdin JSON, POSTs to localhost)
    │
    ▼
HookServer (port 49152, loopback only)
    │
    ├──► Regular events: SessionWriter writes to disk, immediate 200 OK
    │       │
    │       └──► OfficeScene.refreshSessions()
    │               ├──► Group sessions by status
    │               ├──► Update ScreenNode colors + counts
    │               └──► Trigger HuskyNode reactions
    │
    └──► Permission events (PreToolUse, permission_mode="ask"):
            │
            ├──► Hold HTTP connection open
            ├──► Show permission bubble on relevant screen
            ├──► User clicks Allow/Deny
            └──► Send HookDecision response, unblock hook script
```

### Backup: File Polling

SessionReader also polls `~/.agentpong/sessions/` every 5s as fallback. This handles:
- App started after sessions already running
- Hook server not yet started
- Optional AgentPing compat (`~/.agentping/sessions/`)

## Screen System

### 4 Fixed Monitor Slots

Screens represent **status categories with counts**, not individual sessions.

```
SLOT    COLOR     STATUS              SHOWS
────    ─────     ──────              ─────
  1     Green     Running             Count of active sessions
  2     Yellow    Needs input/perms   Count waiting for user
  3     Red       Error               Count with errors
  4     Dim/Off   Idle                Count of idle sessions
```

All 4 monitors are always visible in the room background. When a status has 0 sessions, that monitor is dark/off. When sessions enter that state, the monitor lights up with the corresponding color and shows the count.

### Screen States

```
  ┌─────┐                    ┌───────┐
  │ OFF │── sessions > 0 ──► │ GREEN │  steady glow, code scrolling
  │     │◄── sessions = 0 ──│       │
  └─────┘                    └───────┘

  ┌────────┐                 ┌───────┐
  │ YELLOW │  pulsing glow   │  RED  │  flashing
  └────────┘                 └───────┘
```

### Click Interaction

```
USER ACTION           SYSTEM RESPONSE
──────────────────────────────────────────────
hover any screen  →   tooltip: session name, status, cwd, cost, context%
                      (if multiple: list all sessions in that category)

click screen      →   1 session in category → WindowJumper.jumpTo(session)
                      2+ sessions → show picker tooltip, click to jump

right-click       →   context menu: "Jump to session", "Copy session ID"

permission bubble →   Allow/Deny buttons on yellow screen
on screen             (replaces character permission bubbles)
```

### Permission Flow on Screens

When PreToolUse with `permission_mode="ask"` arrives:

1. Yellow screen pulses more urgently
2. Permission bubble appears near/above the screen: tool name + description
3. Allow / Deny buttons
4. Click Allow → HookDecision(allow: true) sent, hook unblocked
5. Click Deny → HookDecision(allow: false, reason: "denied by user")
6. Auto-allow after 5 minutes (prevents connection leak)

## Husky Pet

### Core Behaviors (always running)

```
BEHAVIOR          TRIGGER                  ANIMATION
────────          ───────                  ─────────
Wander            Timer (4-12s)            Walk to random point, sniff
Idle              Between wanders          Breathing, tail wag, look around
Nap               All screens off (>30s)   Curl up on dog bed, zzz
Play              Random (low chance)      Chase tail, play with toy
Drink             Random                   Walk to water bowl, drink
Scare             User clicks pet          Run to far corner (existing)
```

### Screen Reactions (session-driven)

```
SCREEN EVENT        HUSKY REACTION
────────────        ──────────────
New yellow screen   Walk toward screen, tilt head, whimper
New red screen      Bark, run to screen, back away
All screens green   Play, wag tail, happy bounce
All screens off     Walk to dog bed, nap
Session done        Brief celebration (jump, spin)
```

The pet IS the notification system. It draws your eye to the screen that needs attention.

### Sprite Requirements (PixelLab)

```
HUSKY ANIMATIONS (PixelLab MCP: create_character + animate_character):
  Standing (4 directions)         4 sprites
  Walk cycle (4 dirs x 6 frames)  24 frames
  Idle: tail wag                  4 frames
  Idle: head tilt                 4 frames
  Idle: sniff ground              4 frames
  Idle: yawn                      4 frames
  Sleep (curled up)               2 frames
  Drink water                     4 frames
  Bark / alert                    4 frames
  Sit                             2 frames
  Play (chase tail / toy)         6 frames
  ──────────────────────────────
  TOTAL: ~62 frames

MONITOR SPRITES (PixelLab MCP: create_map_object):
  Monitor off                     1 sprite
  Monitor green (code)            2 frames (scrolling)
  Monitor yellow (warning)        2 frames (pulsing)
  Monitor red (error)             2 frames (flashing)
  ──────────────────────────────
  TOTAL: ~7 sprites

GRAND TOTAL: ~70 sprites (vs 130 in old plan)
```

## Session JSON Format

```json
{
  "id": "session-uuid",
  "status": "running|idle|done|needsInput|error|unavailable",
  "name": "project-name",
  "cwd": "/path/to/project",
  "app": "VSCode",
  "pid": 12345,
  "taskDescription": "Fixing the login bug",
  "contextPercent": 34.5,
  "cost": 0.42,
  "isFreshIdle": false,
  "lastUpdated": "2026-03-15T12:00:00Z"
}
```

## WindowJumper (ported from AgentsHub)

Handles click-to-jump: activate the terminal window running the Claude session.

```
LOOKUP PRIORITY:
  1. Bundle ID match (most reliable)
  2. App name match
  3. PID parent walk (find UI process from child PID)

WINDOW CYCLING:
  - osascript subprocess (TCC workaround)
  - Cmd+` to cycle windows, match by cwd in title
  - Ghostty special case: TTY-based tab switching

SUPPORTED APPS:
  VS Code, Cursor, Terminal.app, iTerm2, Ghostty, Warp, Alacritty, Kitty, etc.
```

## Always-Alive Room

The room is permanent and cozy. Husky always present. Monitors always visible (dark when no sessions).

Room elements:
- Monitors on wall/desk (4 slots)
- Dog bed (husky naps here)
- Water bowl (husky drinks here)
- Plants, lamp, window with day/night
- Warm lighting, cozy atmosphere

Empty room (0 sessions): husky naps, monitors dark, "office is quiet" text. Still charming.

## Art Pipeline

### Background: Gemini (free)

New room design optimized for pet + screens concept:

```
Prompt concept:
"cozy pixel art room, top-down view, warm den/study with 3-4 monitors
on desk against wall, open floor space, dog bed in corner, water bowl,
warm lamp lighting, nighttime atmosphere, no characters, retro RPG
pixel style, 320x320 pixels"
```

Background rendered as empty room. Monitors baked in as "off" state. SpriteKit overlays colored glows when sessions active.

### Sprites: PixelLab MCP

Use the PixelLab MCP server tools directly from Claude Code sessions:

1. `mcp__pixellab__create_character` -- husky with 4 directional views
2. `mcp__pixellab__animate_character` -- walk cycle, idle, sleep, bark, play animations
3. `mcp__pixellab__create_map_object` -- monitor screen sprites (off/green/yellow/red)
4. Style reference from first generation used across all subsequent calls

No scripts or manual API calls needed. MCP handles auth, retries, and asset download.

## Phases

### Phase 1: Foundations -- DONE
- [x] SPM project, Session model, SessionReader, SessionWriter
- [x] CLI: report, setup, status
- [x] Floating window (borderless, shadow, rounded corners, presets)
- [x] Menu bar icon, right-click context menu
- [x] SpriteKit scene with background loading
- [x] Background generated (Gemini)
- [x] HookServer (local HTTP, real-time events)
- [x] HookEvent model + HookDecision
- [x] hook-sender.sh (stdin->curl bridge)
- [x] Permission holding (PreToolUse with ask mode)
- [x] Interactive permission bubbles (Allow/Deny)
- [x] Hook setup command (writes to ~/.claude/settings.json)
- [x] 15 tests passing

### Phase 2: Screens + Jump -- NEW
- [ ] ScreenNode (4 fixed monitors, color states, count labels, glow effects)
- [ ] Session-to-screen mapping (group by status, assign to priority slots)
- [ ] Screen click handler (hover tooltip, click to jump)
- [ ] Port WindowJumper from AgentsHub
- [ ] Migrate permission bubbles from CharacterNode to ScreenNode
- [ ] Delete CharacterNode, Pathfinding, DeskNode
- [ ] Rewrite ZoneManager for screen positions + pet bounds
- [ ] Regenerate Gemini background (cozy room with monitors, dog bed, open floor)
- [ ] Update SpriteAssetLoader for new sprite categories

### Phase 3: Husky Pet -- NEW
- [ ] Generate husky via PixelLab MCP `create_character` (4 dirs)
- [ ] Generate walk cycle via PixelLab MCP `animate_character`
- [ ] HuskyNode (adapted from MascotNode) with wander/scare behaviors
- [ ] Additional PixelLab MCP animations (sleep, drink, bark, play, sit)
- [ ] Rich idle behaviors (tail wag, head tilt, sniff, yawn)
- [ ] Dog bed zone (husky naps when all screens off)
- [ ] Water bowl zone (random drink behavior)

### Phase 4: Pet-Screen Reactions -- NEW
- [ ] Husky walks toward yellow/red screens
- [ ] Bark animation at error screens
- [ ] Head tilt at yellow screens
- [ ] Happy bounce when all green
- [ ] Nap when all screens off for >30s
- [ ] Celebration on session completion

### Phase 5: Themes & Polish
- [ ] Day/night cycle (window + lighting tint from system clock)
- [ ] Multiple room themes (Gemini generation pipeline)
- [ ] Theme switcher in settings
- [ ] Sound effects (optional, toggleable)
- [ ] Keyboard shortcuts (show/hide, resize)
- [ ] PixelLab monitor sprites (replace SpriteKit glow overlays)

### Phase 6: Progression (Future)
- [ ] ProgressionTracker (total tasks, sessions, time)
- [ ] Room upgrades at milestones
- [ ] Pet accessories / toys
- [ ] Multiple pets

## Error Handling

| Failure | Response | User sees |
|---------|----------|-----------|
| No sessions directory | Return empty array | Cozy room, husky naps, all screens off |
| Corrupt JSON file | Skip file, log warning | Other sessions OK |
| Missing sprite asset | Colored rectangle placeholder | Degraded but functional |
| Click jump: PID dead | Show "session ended" tooltip | Brief tooltip then clean up |
| Click jump: app not found | Show "can't find app" tooltip | Brief tooltip |
| Hook server port in use | Log warning, fall back to file polling | Normal but no real-time |
| Permission auto-timeout | Allow after 5 min | Hook unblocked, no user action |
| >9 sessions same status | Screen shows count as "9+" | Still readable |

## Not in Scope

- Character-per-session visualization (old concept, deleted)
- WidgetKit extension (killed in Phase 4 of old plan)
- iOS/iPadOS version
- Multiple pets (future Phase 6)
- CI/deploy screen integration (future)
- Community theme marketplace (future)

## References

- [AgentsHub](../../../agentshub/) -- WindowJumper code, session model patterns
- PixelLab MCP server -- `mcp__pixellab__*` tools for character, animation, and map object generation
- [Google AI Studio](https://aistudio.google.com/) -- Gemini background generation
