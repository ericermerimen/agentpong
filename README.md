# AgentPong

A macOS floating window showing a cozy pixel art room with a husky pet and reactive monitor screens. Monitors light up based on active Claude Code sessions. Click a screen to jump to that session or approve permissions. The husky reacts to screen states -- barks at errors, naps when idle.

![AgentPong screenshot](https://github.com/ericermerimen/agentpong/assets/screenshot.png)

## Features

- **Reactive monitors** -- 3 screens show session status (green=running, yellow=waiting, red=error)
- **Click to jump** -- click a monitor to switch to that terminal session
- **Permission approval** -- approve/deny Claude Code tool use from the widget
- **Husky pet** -- 12+ behaviors: wander, sit, sleep, play, drink, zoomies, watch your cursor
- **Pet reactions** -- barks at errors, tilts head at warnings, naps when all quiet
- **Real-time events** -- local HTTP server receives Claude Code hooks instantly
- **Decorative screens** -- monitors show pixel art content (code editor, chat, social feeds) that changes with session state
- **Always-on-top** -- borderless floating window, draggable, two size presets

## Requirements

- macOS 14 (Sonoma) or later
- Claude Code CLI installed
- Optional: `jq` (enables click-to-jump to the correct terminal window)

## Installation

### Homebrew (recommended)

```bash
brew tap ericermerimen/tap
brew install agentpong
```

Start AgentPong and auto-launch on login:

```bash
brew services start agentpong
```

Then configure Claude Code hooks:

```bash
agentpong setup
```

### From source

```bash
git clone https://github.com/ericermerimen/agentpong.git
cd agentpong
make install    # Builds, links to /Applications, runs setup
```

### Manual build

```bash
git clone https://github.com/ericermerimen/agentpong.git
cd agentpong
make app                          # Build .app bundle
open build/AgentPong.app          # Run it
./build/AgentPong.app/Contents/MacOS/agentpong setup   # Configure hooks
```

## Running the App

### From Launchpad / Applications

After `brew services start agentpong` or `make install`, AgentPong appears in your Applications folder and Launchpad. It runs as a menu bar app (no dock icon) with a cube icon in the menu bar.

### From the terminal

```bash
# If installed via Homebrew
agentpong          # Launch the GUI

# If built from source
open build/AgentPong.app
# or
swift run AgentPong
```

### Startup on login

**Homebrew** (recommended):
```bash
brew services start agentpong
```
This registers a LaunchAgent that starts AgentPong at login and keeps it alive.

**Manual** (from source build):
```bash
make link    # Symlink to /Applications
```
Then add AgentPong to System Settings > General > Login Items manually.

To stop auto-launching:
```bash
brew services stop agentpong
```

## Setup

Run once after installation:

```bash
agentpong setup
```

This does two things:
1. Installs `hook-sender.sh` to `~/.agentpong/hooks/`
2. Adds hook entries to `~/.claude/settings.json`

Restart any running Claude Code sessions for hooks to take effect.

## Updating

### Homebrew

```bash
brew upgrade agentpong && brew services restart agentpong
```

The `post_install` hook automatically kills the old running instance. `brew services restart` launches the new version. If you have `KeepAlive` enabled (the default with `brew services start`), the new version restarts automatically after upgrade -- no manual restart needed.

Check your current version:
```bash
agentpong --version
```

Check if an update is available:
```bash
brew outdated agentpong
```

### From source

```bash
git pull
make install
# Kill the running instance -- launchd or manual relaunch picks up the new binary
pkill -x AgentPong && open /Applications/AgentPong.app
```

## How It Works

```
Claude Code hooks (all events via stdin JSON)
    |
    v
hook-sender.sh (reads stdin, POSTs to localhost:52775)
    |
    v
HookServer (NWListener, loopback only, TCP buffered reader)
    |
    |--- Regular events --> SessionWriter --> disk --> OfficeScene refresh
    |       |--- Update screen colors + decorative textures
    |       |--- Trigger husky reactions
    |
    |--- Permission events (PreToolUse, ask mode)
            |--- Hold HTTP connection open
            |--- Show Allow/Deny bubble on screen
            |--- User clicks --> respond --> unblock hook
```

Backup: SessionReader also polls `~/.agentpong/sessions/` every 5 seconds.

## Screen System

3 monitors, each showing one session (highest priority in center):

| Screen | Position | Priority |
|--------|----------|----------|
| Center | Main desk | Highest priority session |
| Left | Side desk | Second priority |
| Right | Side desk | Third priority |

Priority order: needsInput > error > running > idle.

Monitors display decorative pixel art textures that rotate based on the overall status category (working, waiting, idle, error). Status glow and pulse effects overlay the textures.

## Husky Pet

Always present in the room. Behaviors are weighted-random with screen-driven interrupts:

| Behavior | Trigger | What happens |
|----------|---------|--------------|
| Wander | Timer | Walks to random floor spot |
| Sit | Random | Sits down for a bit |
| Lie down | Random | Walks to dog bed, lies down |
| Sleep | All screens off >30s | Curls up on dog bed |
| Play | Random | Playful rolling animation |
| Drink | Random | Walks to water bowl |
| Zoomies | Random (rare) | Sprint zigzag across room |
| Look around | Random | Cycles through directions |
| Watch cursor | Random | Follows your mouse |
| Bark at errors | Red screen appears | Runs to monitor, barks |
| Head tilt | Yellow screen appears | Walks to monitor, tilts head |
| Scare | Click pet 3x | Sprints to far corner |

## CLI Commands

```bash
agentpong             # Launch the GUI app
agentpong setup       # Install hooks + configure Claude Code
agentpong status      # List active sessions
agentpong report      # Report a session event (used by hooks)
agentpong --version   # Print version
```

## Window Controls

- **Drag** anywhere to move
- **Right-click** for context menu (size presets, session list, quit)
- **Hover** top edge for close button
- **Click monitor** to see session list overlay, click a row to jump
- **Click husky** to interact (3x = scare)

Size presets: Small (170x170) / Large (364x382)

## Data

| Path | Contents |
|------|----------|
| `~/.agentpong/sessions/*.json` | Active session data |
| `~/.agentpong/hooks/hook-sender.sh` | Hook bridge script |
| `~/.agentpong/server-port` | HTTP server port (written on startup) |
| `~/.agentpong/themes/background.png` | Room background (Gemini) |
| `~/.agentpong/themes/foreground.png` | Room foreground layer |
| `~/.agentpong/sprites/` | Sprite assets (PixelLab) |

## Uninstalling

### Homebrew

```bash
brew services stop agentpong
brew uninstall agentpong
rm -rf ~/.agentpong
```

Remove AgentPong hooks from `~/.claude/settings.json` (search for "agentpong").

### From source

```bash
make uninstall
```

## Building

```bash
swift build              # Debug build
swift build -c release   # Release build
swift test               # Run tests
make app                 # Build .app bundle
make archive             # Build + create .tar.gz for Homebrew
```

## Tech Stack

- **Language**: Swift 5.9+
- **UI**: SpriteKit (60fps pixel art rendering)
- **Window**: NSPanel (borderless, always-on-top, draggable)
- **Real-time events**: NWListener HTTP server on loopback
- **Platform**: macOS 14 (Sonoma)+
- **Build**: Swift Package Manager
- **Sprites**: PixelLab MCP (husky, animations)
- **Backgrounds**: Gemini (cozy room scenes)
- **Dependencies**: None

## License

[PolyForm Noncommercial 1.0.0](LICENSE)
