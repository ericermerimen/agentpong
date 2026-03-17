# AgentPong

## What is this

AgentPong is a macOS app that displays a pixel art office scene where animated characters represent active Claude Code sessions. Characters walk between zones (desks, lounge, debug station) with smooth SpriteKit animation in a floating window. A companion WidgetKit widget provides ambient snapshot views.

**Standalone app** -- has its own Claude Code hook integration. No AgentPing dependency (optional compatibility).

## Tech stack

- **Language**: Swift 5.9+
- **UI**: SwiftUI (settings, widget) + SpriteKit (floating window scene)
- **Floating window**: NSPanel (always-on-top) + SKView (60fps SpriteKit scene)
- **Widget**: WidgetKit + Core Graphics compositing (static snapshots)
- **Platform**: macOS 14 (Sonoma)+
- **Build**: Swift Package Manager (Phase 1-3), Xcode project (Phase 4+ for WidgetKit)
- **Dependencies**: None

## Architecture

```
AgentPong/
├── Sources/
│   ├── App/                              # Main app target
│   │   ├── AgentPongApp.swift        # @main, app lifecycle
│   │   ├── FloatingWindowController.swift # NSPanel, always-on-top, draggable
│   │   ├── SettingsView.swift            # Theme, size, level
│   │   └── MenuBarController.swift       # Tray icon show/hide
│   │
│   ├── SpriteEngine/                     # SpriteKit scene (floating window)
│   │   ├── OfficeScene.swift             # SKScene, 60fps game loop
│   │   ├── Nodes/
│   │   │   ├── CharacterNode.swift       # Agent sprite + state machine
│   │   │   ├── MascotNode.swift          # Permanent cat
│   │   │   ├── BubbleNode.swift          # Speech/thought/alert
│   │   │   ├── DeskNode.swift            # Desk + monitor (lit/dark)
│   │   │   └── AmbientNode.swift         # Coffee machine, fan, plants
│   │   ├── Pathfinding.swift             # BFS grid navigation
│   │   ├── ZoneManager.swift             # Zone coordinates
│   │   └── AnimationLibrary.swift        # Sprite sheet frames
│   │
│   ├── Widget/                           # WidgetKit extension (Phase 4)
│   │   ├── Provider.swift                # TimelineProvider
│   │   ├── WidgetViews.swift             # S/M/L SwiftUI views
│   │   └── SnapshotRenderer.swift        # CG compositing
│   │
│   ├── CLI/                              # Built-in hook integration
│   │   └── ReportCommand.swift           # `agentpong report`
│   │
│   └── Shared/                           # Shared framework
│       ├── Session.swift                 # Codable model
│       ├── SessionReader.swift           # Reads ~/.agentpong/sessions/
│       ├── SessionWriter.swift           # Writes session JSON
│       ├── AppGroupRelay.swift           # App Group UserDefaults bridge
│       ├── ProgressionTracker.swift      # Level-up system
│       ├── ThemeManager.swift            # Backgrounds + palettes
│       └── SpriteAssetLoader.swift       # Load sprites, placeholder fallback
│
├── Assets/                               # Git-ignored, generated/downloaded
├── Scripts/
│   ├── generate-background.py            # Gemini API theme generator
│   └── download-assets.sh                # Asset setup script
└── Resources/
    ├── room-skeleton.png                 # Zone reference for Gemini
    └── progression-levels.json           # Level thresholds
```

## Data flow

```
Claude Code hooks (SessionStart, Stop, PreToolUse, etc.)
    │
    ▼
agentpong report --session $ID --event $EVENT
    │
    ▼
~/.agentpong/sessions/SESSION_ID.json
    │
    ├──► Main App (SessionReader) polls every 5s
    │       ├──► OfficeScene (SpriteKit, 60fps)
    │       └──► AppGroupRelay → Widget Extension (every 60s)
    │
    └──► OPTIONAL: also reads ~/.agentping/sessions/ if present
```

## Session data

- **Primary**: `~/.agentpong/sessions/*.json` (written by built-in CLI)
- **Optional compat**: `~/.agentping/sessions/*.json` (if AgentPing installed)

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

## State-to-scene mapping

| Session Status | Zone | Character Visual |
|---------------|------|-----------------|
| running | desk | Sitting, typing animation |
| idle | lounge | Standing idle, breathing |
| ready (isFreshIdle) | lounge | "done!" bubble |
| needsInput | lounge | Pulsing "?" bubble |
| error | debug station | "!" alert bubble |
| done | door → removed | Walks out, fades |

## Always-alive office

The office is permanent. 4 desks, lounge sofa, debug station, coffee machine, plants always present. Mascot cat always wanders. Ambient objects always animate. Day/night cycle from system clock. Empty desks have dark monitors. Characters come and go through the door.

## Widget sizes

| Size | Dimensions | Content |
|------|-----------|---------|
| Small | 160x160 | Character count + status dots |
| Medium | 320x160 | Horizontal strip, characters at zones |
| **Large** | **320x320** | **Full office scene, primary target** |

## Art pipeline

- **Backgrounds**: Google AI Studio / Gemini API (free) -- skeleton-reference approach
- **Characters/sprites**: PixelLab API Tier 1 ($12/mo) -- walk cycles, idle, typing animations
- **Assets NOT checked into git** -- downloaded/generated at build time

## Phases

1. **Foundations**: SPM project, session model, CLI hooks, floating window shell, empty SpriteKit scene
2. **Characters Walk**: state machine, BFS pathfinding, walk/idle/work animations, arrival/departure
3. **Office Alive**: mascot cat, ambient objects, day/night, speech bubbles
4. **Widget**: WidgetKit extension, Core Graphics snapshots, App Group relay
5. **Progression & Themes**: level-up system, Gemini backgrounds, theme switcher
6. **Polish**: micro-interactions, overflow, sounds, keyboard shortcuts

## User setup

```bash
# Install app, then:
agentpong setup    # Registers Claude Code hooks automatically
```

## Build commands

```bash
swift build              # Debug build
swift build -c release   # Release build
swift run AgentPong  # Run the app
```

## Plan

Full plan with architecture diagrams, competitive analysis, error handling: `docs/plans/pixel-office-widget-plan.md`
