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
  "cwd": "/path/to/project",          // display name: last path component, or "~" if home dir
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

## CI / Release

- Tag-triggered release workflow (`.github/workflows/release.yml`)
- Builds `.app` bundle + `.tar.gz` archive for Homebrew
- Auto-generates `appcast.xml` for Sparkle auto-updates (Ed25519 signed)
- Pushes updated Homebrew formula to `homebrew-tap` repo with retry+rebase for race conditions
- Version source of truth: `VERSION` file (also hardcoded fallback in `Sources/Shared/Version.swift`)

## Hard rules (non-negotiable)

### Sprite animation consistency
All animation frames/states for the same element MUST have identical scale, anchor point, and bounding box. When switching states (idle->walk, walk->bark, etc.), the sprite must not visibly jump, shrink, or grow. Before committing any sprite animation work:
- Verify all frames share the same pixel dimensions or are scaled to match
- Check anchor points are consistent across all states
- Test state transitions to confirm no visual "pop" or "different object" feel

### Collision detection and position mapping
This app relies heavily on correct collision detection and position mapping against the background image. These must be designed and verified BEFORE presenting to the user:
- Zone boundaries must match the visual background (walls, furniture edges, walkable areas)
- Hit targets for clickable elements must align with their visual representation
- Test edge cases: pet at boundaries, overlapping zones, click regions near edges
- Never present untested collision/position work

### Small and large window scaling
This app has small and large display modes. Both MUST look correct:
- All sprite positioning, scaling, and collision zones must be tested at BOTH sizes
- Use relative coordinates and scale factors, not hardcoded pixel values
- If it looks good at one size but broken at another, it is not done
- Verify both sizes before presenting any visual change

### Quality bar
Do not present half-baked solutions. Think deeply before implementing:
- If a solution requires the user to "keep tuning the same thing," the approach is wrong -- rethink it
- Verify your work compiles, runs, and looks correct before showing it
- If you're unsure about visual output, say so explicitly rather than shipping and hoping
- One well-thought-out solution beats three iterative attempts

### Debugging Approach
- **When stuck on a bug, stop speculating and gather real information first**
- If a root cause isn't obvious from reading the code, add logging/instrumentation and ask the user to run it -- don't keep re-theorising without data
- Avoid the "wait, actually the real issue is..." loop: form one clear hypothesis, test it, then reassess based on evidence

## Plan

Full plan: `docs/plans/pixel-office-widget-plan.md`
Progress: `docs/progress.md`
Art strategy: `docs/art-pixel-sizing-strategy.md`
