# AgentPong

## What is this

AgentPong is a macOS app that displays a cozy pixel art room with a husky pet and reactive monitor screens. Monitors light up based on active Claude Code sessions (green=running, yellow=needs input, red=error). Click a screen to jump to that session or approve permissions. The husky reacts to screen states (barks at errors, naps when idle).

**Standalone app** -- has its own Claude Code hook integration via local HTTP server. No AgentPing dependency (optional compatibility).

## Tech stack

- **Language**: Swift 5.9+
- **UI**: SpriteKit (floating window scene, 60fps)
- **Floating window**: NSPanel (always-on-top) + SKView
- **Real-time events**: NWListener HTTP server on loopback (port 49152)
- **Platform**: macOS 14 (Sonoma)+
- **Build**: Swift Package Manager
- **Sprites**: PixelLab MCP (husky, animations, monitors)
- **Backgrounds**: Gemini (cozy room scenes)
- **Dependencies**: None

## Architecture

```
AgentPong/
├── Sources/
│   ├── App/
│   │   └── AgentPongApp.swift            # @main, window, menu bar, CLI, HookServer startup
│   │
│   ├── SpriteEngine/
│   │   ├── OfficeScene.swift             # SKScene, 60fps loop, screen management, click handlers
│   │   ├── Nodes/
│   │   │   ├── ScreenNode.swift          # Monitor with color states, count, glow, click target
│   │   │   ├── HuskyNode.swift           # Pet sprite + behaviors + screen reactions
│   │   │   ├── BubbleNode.swift          # Permission/info bubbles on screens
│   │   │   └── AmbientNode.swift         # Plants, lamp, decorative
│   │   └── ZoneManager.swift             # Screen positions, pet wander bounds
│   │
│   └── Shared/
│       ├── Session.swift                 # Codable model
│       ├── SessionReader.swift           # Reads ~/.agentpong/sessions/
│       ├── SessionWriter.swift           # Writes session JSON
│       ├── HookServer.swift              # Local HTTP server for real-time hook events
│       ├── HookEvent.swift               # Hook event model + permission decisions
│       ├── WindowJumper.swift            # Activate session terminal window (from AgentsHub)
│       └── SpriteAssetLoader.swift       # Load sprites, placeholder fallback
│
├── Scripts/
│   └── hook-sender.sh                    # stdin→curl bridge for Claude Code hooks
└── Tests/
    └── SharedTests/                      # Session, HookEvent, HookServer, ZoneManager tests
```

## Data flow

```
Claude Code hooks (all events via stdin JSON)
    │
    ▼
hook-sender.sh (reads stdin, POSTs to localhost:49152)
    │
    ▼
HookServer (NWListener, loopback, TCP buffered reader)
    │
    ├──► Regular events → SessionWriter → disk → OfficeScene refresh
    │       └──► Update screen colors + counts, trigger pet reactions
    │
    └──► Permission events (PreToolUse, ask mode)
            └──► Hold connection → show Allow/Deny on screen → respond → unblock hook
```

Backup: SessionReader also polls `~/.agentpong/sessions/` every 5s.

## Screen system

4 fixed monitor slots, each representing a status category:

| Screen | Color | Status | Shows |
|--------|-------|--------|-------|
| 1 | Green | Running | Count of active sessions |
| 2 | Yellow | Needs input/perms | Count waiting for user |
| 3 | Red | Error | Count with errors |
| 4 | Dim/Off | Idle | Count of idle sessions |

Click a screen to jump to that session (WindowJumper activates terminal window).
Permission bubbles appear on yellow screen with Allow/Deny buttons.

## Session data

- **Primary**: `~/.agentpong/sessions/*.json`
- **Optional compat**: `~/.agentping/sessions/*.json`

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

## Husky pet

Always present. Wanders the room, does pet things. Reacts to screen state changes:
- Yellow screen: walks over, tilts head
- Red screen: barks, backs away
- All green: plays, wags tail
- All off: naps on dog bed
- Click pet: scare reaction (runs to corner)

## Phases

1. **Foundations** (DONE): SPM project, session model, CLI, floating window, SpriteKit scene, HookServer, permissions
2. **Screens + Jump**: ScreenNode, click-to-jump, WindowJumper, permission migration
3. **Husky Pet**: PixelLab MCP character generation, HuskyNode, behaviors
4. **Pet Reactions**: Screen-aware pet behaviors
5. **Themes & Polish**: day/night, multiple themes, sounds

## User setup

```bash
agentpong setup    # Installs hook-sender.sh + registers in ~/.claude/settings.json
```

## Build commands

```bash
swift build              # Debug build
swift build -c release   # Release build
swift run AgentPong      # Run the app
swift test               # Run tests (15 passing)
```

## Plan

Full plan: `docs/plans/pixel-office-widget-plan.md`
Progress: `docs/progress.md`
Art strategy: `docs/art-pixel-sizing-strategy.md`
