# AgentPong -- macOS Pixel Office App

## Overview

A macOS app that displays a pixel art office scene where animated characters represent active Claude Code sessions. Characters walk between zones (desks, lounge, debug station) with smooth 60fps SpriteKit animation. A companion WidgetKit widget provides ambient snapshot views in the widget sidebar.

**Standalone app** -- no AgentPing dependency required. Has its own built-in Claude Code hook integration.

Inspired by [Star-Office-UI](https://github.com/ringhyacinth/Star-Office-UI), [Pixel Agents](https://github.com/pablodelucca/pixel-agents), and [Agent Office](https://github.com/harishkotra/agent-office).

## Key Design Decisions (from CEO Review 2026-03-15)

| Decision | Choice | Why |
|----------|--------|-----|
| Primary experience | SpriteKit floating window (60fps) | WidgetKit cannot do continuous animation. Smooth walking requires a game loop. |
| Secondary experience | WidgetKit widget (snapshot every 60s) | Ambient presence in widget sidebar/desktop. Static snapshot with SwiftUI transitions. |
| Data source | Built-in session tracker | Standalone -- no AgentPing dependency. Reads `~/.agentpong/sessions/`. Optional AgentPing compat. |
| Widget data relay | App Group shared UserDefaults | Widget extension is sandboxed, can't read arbitrary paths. Main app relays via App Group. |
| Sprite source | PixelLab API (characters/animations) + Gemini (backgrounds) | PixelLab excels at consistent pixel art sprites + walk cycles. Gemini excels at themed background scenes. |
| Office permanence | Always alive, furniture always present | Empty desks with dark monitors when no sessions. Office is a place, not a data visualization. |
| Desk count | 4 permanent desks | Covers 90% of real usage. Overflow: characters double-up or stand behind desks. |
| Alive elements | Mascot cat, ambient objects, day/night cycle, progression system | Makes the scene worth looking at even with 0 sessions. |
| Build order | Floating window first, widget after | Ship the wow-factor (smooth walking) before the ambient view (static widget). |
| Distribution | Direct download first, App Store later | Avoids sandbox complications. GitHub Releases / DMG. |

## Architecture

```
AgentPong.app
├── App/                              # Main app target
│   ├── AgentPongApp.swift        # @main, app lifecycle
│   ├── FloatingWindowController.swift # NSPanel always-on-top, draggable
│   ├── SettingsView.swift            # Theme picker, size, level display
│   └── MenuBarController.swift       # Tray icon to show/hide window
│
├── SpriteEngine/                     # SpriteKit scene (floating window)
│   ├── OfficeScene.swift             # SKScene, 60fps update loop
│   ├── Nodes/
│   │   ├── CharacterNode.swift       # Agent sprite + state machine
│   │   ├── MascotNode.swift          # Permanent cat, autonomous behaviors
│   │   ├── BubbleNode.swift          # Speech/thought/alert bubbles
│   │   ├── DeskNode.swift            # Desk + monitor (lit/dark state)
│   │   └── AmbientNode.swift         # Coffee machine, fan, plants
│   ├── Pathfinding.swift             # BFS grid navigation
│   ├── ZoneManager.swift             # Desk/lounge/debug/door zone coords
│   └── AnimationLibrary.swift        # Sprite sheet frame sequences
│
├── Widget/                           # WidgetKit extension target
│   ├── Provider.swift                # TimelineProvider (reads App Group)
│   ├── WidgetViews.swift             # Small/Medium/Large SwiftUI views
│   └── SnapshotRenderer.swift        # Core Graphics compositing
│
├── CLI/                              # Built-in session tracker
│   └── ReportCommand.swift           # `agentpong report` -- writes session JSON
│
└── Shared/                           # Shared framework
    ├── Session.swift                 # Codable model
    ├── SessionReader.swift           # Reads ~/.agentpong/sessions/
    ├── SessionWriter.swift           # Writes session JSON from hook events
    ├── AppGroupRelay.swift           # Write/read via App Group UserDefaults
    ├── ProgressionTracker.swift      # Level-up system, task counts
    ├── ThemeManager.swift            # Background + palette per theme
    └── SpriteAssetLoader.swift       # Load sprite sheets, fallback to placeholder
```

## Data Flow

```
Claude Code hooks (SessionStart, Stop, PreToolUse, etc.)
    │
    ▼
agentpong report --session $ID --event $EVENT --status $STATUS
    │
    ▼
~/.agentpong/sessions/SESSION_ID.json
    │
    ├──► Main App (SessionReader) reads directly, polls every 5s
    │       │
    │       ├──► OfficeScene (SpriteKit) -- 60fps character animation
    │       │
    │       └──► AppGroupRelay -- writes snapshot to App Group UserDefaults
    │               │
    │               └──► Widget Extension (Provider) -- reads every 60s
    │
    └──► OPTIONAL: also reads ~/.agentping/sessions/ if AgentPing installed
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

## State Machine (SpriteKit Characters)

```
  ┌──────────┐   status changes    ┌──────────┐
  │  IDLE    │──────────────────────►  WALKING  │
  │ (lounge) │                      │ (to zone) │
  │          │◄─────────────────────│          │
  └──────────┘   arrived            └──────────┘
       │                                  │
       │ status == running                │ arrived at desk
       ▼                                  ▼
  ┌──────────┐                      ┌──────────┐
  │ WALKING  │──── arrived ─────────►  WORKING  │
  │ (to desk)│                      │ (typing)  │
  └──────────┘                      └──────────┘
                                         │
                                         │ status == error
                                         ▼
                                    ┌──────────┐
                                    │ WALKING  │──► ALERTING (! bubble)
                                    │(to debug) │
                                    └──────────┘

  NEW session  → character fades in at door, walks to assigned zone
  Session gone → character walks to door, fades out
  Session gone mid-walk → fade out from current position

  IDLE BEHAVIORS (idle >10s):
    0.3% chance/frame → wander to random nearby point, return
    Continuous breathing animation
    Occasional look-around
```

## State-to-Zone Mapping

| Session Status | Zone | Character Visual |
|---------------|------|-----------------|
| running | desk | Sitting at desk, typing animation |
| idle | lounge | Standing idle, breathing |
| ready (isFreshIdle) | lounge | Standing with "done!" bubble |
| needsInput | lounge | Standing with pulsing "?" bubble |
| error | debug station | Standing with "!" alert bubble |
| done | door → removed | Walks to door, fades out |

## Always-Alive Office

The office is a permanent space, not a data visualization. All furniture is always present:

```
┌─────────────────────────────────────────────────────┐
│  [window]  [poster]                    [server rack] │
│  day/night                              (debug zone) │
│                                                      │
│  [desk1] [desk2] [desk3] [desk4]      [coffee       │
│                                         machine]     │
│                                                      │
│        [sofa / lounge area]            cat (mascot)  │
│                                                      │
│  [plant]              [plant]          [door]        │
└─────────────────────────────────────────────────────┘
```

- **Empty desks**: dark monitors, empty chairs
- **Occupied desks**: lit monitors, character typing
- **Mascot cat**: always present, wanders, naps, watches workers, gets coffee
- **Ambient objects**: coffee machine steams, monitors flicker, fan spins, clock shows real time
- **Day/night cycle**: window and lighting tint from system clock
- **Progression**: office upgrades visually at milestones (total tasks completed)

## Progression System

| Level | Threshold | Visual Change |
|-------|-----------|--------------|
| 1 | 0 tasks | Bare startup: folding chairs, one sad plant |
| 5 | 50 tasks | Proper office: real desks, coffee machine appears |
| 10 | 200 tasks | Nice office: posters, second plant, better lighting |
| 20 | 500 tasks | Luxury: aquarium, neon sign, custom theme unlocked |

Tracked in UserDefaults. Persists across sessions.

## Widget Sizes

| Size | Dimensions | Content |
|------|-----------|---------|
| Small | 160x160 | Character count + status dots, mini background |
| Medium | 320x160 | Horizontal strip, characters at zone positions |
| **Large** | **320x320** | **Full office scene snapshot, primary target** |

Widget shows static snapshot (Core Graphics composited). SwiftUI transitions between timeline entries for smooth state changes.

## Art Pipeline

### Backgrounds: Google AI Studio (Gemini) -- FREE
1. Create room-skeleton.png (bare room layout with zone markers)
2. Feed skeleton + prompt to Gemini API for themed backgrounds
3. Skeleton ensures consistent zone positions across themes

Prompt template:
```
Use a top-down pixel room composition compatible with an office game scene.
STRICTLY preserve the same room geometry, camera angle, wall/floor boundaries
and major object placement as the provided reference image.
Keep region layout stable (left work area, center lounge, right debug area).
Only change visual style/theme/material/lighting according to: [THEME].
Do not add text or watermark. Retro 8-bit RPG style.
Dark color palette, nighttime atmosphere, warm lamp lighting.
Target size: 320x320 pixels.
```

### Characters & Sprites: PixelLab API (Tier 1, $12/mo)
- Characters: `POST /create-character-with-4-directions` (32x32 or 48x48)
- Walk cycles: `POST /animate-character` with template animations
- Furniture: `POST /map-objects`
- Style reference feature for consistency across all sprites
- Generate background + characters in matched style to avoid scale mismatch

### Asset Storage
- NOT checked into git (generated art, potentially paid tools)
- Git-ignored `Assets/` directory
- Setup script downloads/generates on first build
- Or: private assets repo as git submodule

## User Setup (Standalone)

```bash
# 1. Download and install
# Download AgentPong.dmg from GitHub Releases, drag to /Applications

# 2. Register Claude Code hooks
agentpong setup
# This registers hooks in ~/.claude/hooks/:
#   SessionStart  → agentpong report --session $SESSION_ID --event start
#   Stop          → agentpong report --session $SESSION_ID --event stop
#   PreToolUse    → agentpong report --session $SESSION_ID --event active
#   Notification  → agentpong report --session $SESSION_ID --event notify

# 3. Launch app -- floating window appears
# Characters will appear when Claude Code sessions are active
```

First-launch onboarding detects no sessions, shows setup instructions in-app.

## Phases

### Phase 1: Foundations
- Swift Package project structure (SPM, no Xcode required yet)
- Session model + SessionWriter + SessionReader
- CLI: `agentpong report` command
- CLI: `agentpong setup` command (registers Claude Code hooks)
- Floating window shell (NSPanel, always-on-top, draggable, resizable)
- Empty SpriteKit scene with static background image
- First-launch onboarding
- **Ship**: app launches, shows empty office background, setup works

### Phase 2: Characters Walk
- CharacterNode with state machine (idle/walking/working/alerting)
- BFS pathfinding on tile grid
- ZoneManager (4 desks, lounge, debug station, door)
- Walk animation (4 directions, 4+ frames each, 12fps)
- Idle animation (breathing, look-around)
- Working animation (typing at desk)
- Session-to-character mapping (hash session ID for stability)
- Arrival: walk in through door -> assigned zone
- Departure: walk to door -> fade out
- State change: walk from current zone -> new zone
- **Ship**: characters walk smoothly between zones based on session state

### Phase 3: Office Comes Alive
- MascotNode (cat) with autonomous behaviors (wander, nap, coffee, watch workers)
- Ambient objects (coffee machine steam, monitor flicker, fan rotation)
- Day/night cycle (tint overlay from system clock)
- Speech/thought bubbles ("!", "?", "done!", truncated task description)
- **Ship**: office feels alive, mascot wanders, ambient animations

### Phase 4: Widget
- WidgetKit timeline provider (reads from App Group)
- SnapshotRenderer (Core Graphics compositing)
- Large/Medium/Small widget views
- Widget tap -> opens floating window or specific session
- **Ship**: widget appears in macOS widget gallery and sidebar

### Phase 5: Progression & Themes
- ProgressionTracker (total tasks, sessions, time)
- Level-up visual milestones (L1 -> L5 -> L10 -> L20)
- Gemini background generation pipeline
- Theme pool (cozy night, cyberpunk, forest cabin, space station)
- Theme switcher (widget configuration intent)
- **Ship**: users progress, office evolves, multiple themes

### Phase 6: Polish & Delight
- Character micro-interactions (high-five, chat bubbles between idle chars)
- Overflow handling (>4 at desks: stand behind, share)
- Sound effects (optional, toggleable)
- Keyboard shortcuts (show/hide, resize)
- Menu bar icon to toggle floating window

## Error Handling

| Failure | Response | User sees |
|---------|----------|-----------|
| No sessions directory | Return empty array | Empty alive office |
| Corrupt JSON file | Skip file, log warning | Other sessions OK |
| App Group not configured | Show setup instructions | "Setup required" in widget |
| Missing sprite asset | Colored circle placeholder | Degraded but functional |
| Session disappears mid-walk | Fade out from current position | Character dissolves |
| >4 running sessions (overflow) | Characters double-up / stand behind desks | Busy office visual |
| AgentPing not installed | Works fine (standalone) | Normal operation |

## Not in Scope

- Modifying AgentPing (read-only compat)
- iOS/iPadOS version
- Multi-monitor support
- Community theme marketplace (future)
- Character customization editor (future)
- Live Activities / Dynamic Island (future macOS)

## Competitive Landscape

| Feature | Star-Office-UI | Pixel Agents | Agent Office | AgentPong |
|---------|---------------|-------------|-------------|---------------|
| Platform | Web + Tauri | VS Code ext | Web | macOS native |
| Walking | No (web) / 4fr (Tauri) | Yes (BFS) | Yes (tween) | Yes (SpriteKit) |
| Smooth | Jumpy | Decent | Smooth | Target: smooth |
| Always alive | No | No | Yes (autonomous) | Yes (mascot + ambient) |
| Progression | No | No | No | Yes (level-up) |
| Standalone | Needs backend | Needs VS Code | Needs server | Standalone app |
| Widget | No | No | No | Yes (WidgetKit) |

## References

- [Star-Office-UI](https://github.com/ringhyacinth/Star-Office-UI) -- inspiration, Gemini prompt, architecture reference
- [Pixel Agents](https://github.com/pablodelucca/pixel-agents) -- VS Code extension, BFS pathfinding, office editor
- [Agent Office](https://github.com/harishkotra/agent-office) -- Phaser.js, tween interpolation, autonomous agents
- [PixelLab API](https://api.pixellab.ai/v2/llms.txt) -- sprite generation (Tier 1, $12/mo)
- [Google AI Studio](https://aistudio.google.com/) -- Gemini background generation (free)
- [LimeZu Modern Interiors](https://limezu.itch.io/moderninteriors) -- reference sprite style
- Apple WidgetKit docs -- animation limitations, timeline providers
- Apple SpriteKit docs -- game loop, sprite nodes, pathfinding
