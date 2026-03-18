import AppKit
import SpriteKit
import SpriteEngine
import Shared

// MARK: - Window Size Presets

enum WindowPreset: String, CaseIterable {
    case small = "Small"
    case large = "Large"

    var size: NSSize {
        switch self {
        case .small: return NSSize(width: 170, height: 170)
        case .large: return NSSize(width: 364, height: 382)
        }
    }
}

// MARK: - Borderless Floating Panel

class BorderlessPanel: NSPanel {
    private var hoverOverlay: NSView?
    private var trackingArea: NSTrackingArea?
    weak var floatController: FloatingWindowController?

    override var canBecomeKey: Bool { true }

    func setupHoverControls() {
        guard let contentView = contentView else { return }

        // Subtle top overlay that appears on hover
        let overlay = NSView(frame: NSRect(x: 0, y: contentView.bounds.height - 24, width: contentView.bounds.width, height: 24))
        overlay.autoresizingMask = [.width, .minYMargin]
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor(white: 0, alpha: 0.4).cgColor
        overlay.layer?.cornerRadius = 12
        overlay.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        overlay.alphaValue = 0
        contentView.addSubview(overlay)
        hoverOverlay = overlay

        // Close button (left)
        let close = NSButton(frame: NSRect(x: 6, y: 2, width: 20, height: 20))
        close.bezelStyle = .circular
        close.title = ""
        close.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        close.imagePosition = .imageOnly
        close.isBordered = false
        close.contentTintColor = NSColor(white: 0.6, alpha: 1.0)
        close.target = self
        close.action = #selector(closePanel)
        overlay.addSubview(close)

        // Setup tracking area for hover
        let area = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(area)
        trackingArea = area
    }

    func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        // Dynamic session categories
        if let controller = floatController {
            let sessions = controller.activeSessions

            let categories: [(String, [Session])] = [
                ("Working", sessions.filter { $0.status == .running }),
                ("Waiting", sessions.filter { $0.status == .needsInput }),
                ("Idle", sessions.filter { $0.status == .idle }),
            ]

            for (label, group) in categories where !group.isEmpty {
                let catItem = NSMenuItem(title: "\(label) (\(group.count))", action: nil, keyEquivalent: "")
                let submenu = NSMenu()
                for session in group {
                    let item = NSMenuItem(title: session.displayName, action: #selector(jumpToSession(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = session
                    submenu.addItem(item)
                }
                catItem.submenu = submenu
                menu.addItem(catItem)
            }

            if !sessions.isEmpty {
                menu.addItem(NSMenuItem.separator())
            }
        }

        // Size presets
        for preset in WindowPreset.allCases {
            let item = NSMenuItem(title: preset.rawValue, action: #selector(setSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset
            if preset == (floatController?.currentPreset ?? .small) {
                item.state = .on
            }
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Hide", action: #selector(closePanel), keyEquivalent: ""))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: ""))
        menu.items.last?.target = self

        return menu
    }

    @objc private func jumpToSession(_ sender: NSMenuItem) {
        guard let session = sender.representedObject as? Session else { return }
        WindowJumper.shared.jump(to: session)
    }

    @objc private func closePanel() {
        orderOut(nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func setSize(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? WindowPreset else { return }
        floatController?.setPreset(preset)
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            hoverOverlay?.animator().alphaValue = 1.0
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            hoverOverlay?.animator().alphaValue = 0
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = buildContextMenu()
        NSMenu.popUpContextMenu(menu, with: event, for: contentView!)
    }
}

// MARK: - Floating Window Controller

/// Custom SKView that enables mouse tracking for hover tooltips
class TrackingSKView: SKView {
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        scene?.mouseMoved(with: event)
    }
}

class FloatingWindowController {
    private var window: BorderlessPanel?
    private var skView: SKView?
    var currentPreset: WindowPreset = .small
    private var hookServer: HookServer?

    private let shadowPad: CGFloat = 16

    func showWindow() {
        if window != nil {
            window?.makeKeyAndOrderFront(nil)
            return
        }
        rebuildWindow()
    }

    private func rebuildWindow() {
        window?.orderOut(nil)
        window = nil
        skView = nil

        let preset = currentPreset
        let totalSize = NSSize(
            width: preset.size.width + shadowPad * 2,
            height: preset.size.height + shadowPad * 2
        )

        let panel = BorderlessPanel(
            contentRect: NSRect(origin: .zero, size: totalSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.floatController = self

        // Container
        let container = NSView(frame: NSRect(origin: .zero, size: totalSize))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = container

        // Inner view with floating shadow
        let innerFrame = NSRect(x: shadowPad, y: shadowPad, width: preset.size.width, height: preset.size.height)
        let innerView = NSView(frame: innerFrame)
        innerView.wantsLayer = true
        innerView.layer?.cornerRadius = 14
        innerView.layer?.masksToBounds = false
        innerView.layer?.backgroundColor = NSColor(red: 0.04, green: 0.03, blue: 0.02, alpha: 1.0).cgColor
        innerView.layer?.shadowColor = NSColor.black.cgColor
        innerView.layer?.shadowOpacity = 0.6
        innerView.layer?.shadowOffset = CGSize(width: 0, height: -4)
        innerView.layer?.shadowRadius = 12
        container.addSubview(innerView)

        // Clip view for rounded corners
        let clipView = NSView(frame: innerView.bounds)
        clipView.wantsLayer = true
        clipView.layer?.cornerRadius = 14
        clipView.layer?.masksToBounds = true
        clipView.autoresizingMask = [.width, .height]
        innerView.addSubview(clipView)

        // SpriteKit view with mouse tracking
        let view = TrackingSKView(frame: clipView.bounds)
        view.ignoresSiblingOrder = true
        view.allowsTransparency = true
        view.wantsLayer = true

        let scene = OfficeScene()
        scene.scaleMode = .aspectFit
        scene.size = CGSize(width: 320, height: 320)
        view.presentScene(scene)

        clipView.addSubview(view)
        self.skView = view

        // Position bottom-right
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: sf.maxX - totalSize.width - 8, y: sf.minY + 8))
        }

        panel.makeKeyAndOrderFront(nil)
        panel.setupHoverControls()
        self.window = panel

        // Re-wire hookServer to the new scene
        if let server = hookServer {
            passHookServer(server)
        }
    }

    func setPreset(_ preset: WindowPreset) {
        currentPreset = preset
        rebuildWindow()
    }

    func toggleWindow() {
        if let window = window, window.isVisible {
            window.orderOut(nil)
        } else {
            showWindow()
        }
    }

    var activeSessions: [Session] {
        (skView?.scene as? OfficeScene)?.currentSessions.filter(\.isVisible) ?? []
    }

    func passHookServer(_ server: HookServer) {
        self.hookServer = server
        if let scene = skView?.scene as? OfficeScene {
            scene.hookServer = server
        }
    }
}

// MARK: - Menu Bar Controller

class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let windowController: FloatingWindowController
    /// Set to the new version string (e.g. "1.1.0") when brew has a newer version.
    private var updateAvailable: String?

    init(windowController: FloatingWindowController) {
        self.windowController = windowController
        super.init()
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // dog.fill requires macOS 14+ (which we target)
            button.image = NSImage(systemSymbolName: "dog.fill", accessibilityDescription: "AgentPong")
                ?? NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "AgentPong")
        }

        // Dynamic menu: rebuilt every time it opens to show current sessions
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu

        // Check for updates on launch (background, non-blocking)
        checkBrewUpdate()
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // Session summary
        let sessions = windowController.activeSessions
        if sessions.isEmpty {
            let item = NSMenuItem(title: "No active sessions", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            let running = sessions.filter { $0.status == .running }.count
            let waiting = sessions.filter { $0.status == .needsInput }.count
            let idle = sessions.filter { $0.status == .idle }.count
            let errors = sessions.filter { $0.status == .error }.count

            var parts: [String] = []
            if running > 0 { parts.append("\(running) working") }
            if waiting > 0 { parts.append("\(waiting) waiting") }
            if idle > 0 { parts.append("\(idle) idle") }
            if errors > 0 { parts.append("\(errors) error") }

            let summary = NSMenuItem(title: parts.joined(separator: ", "), action: nil, keyEquivalent: "")
            summary.isEnabled = false
            menu.addItem(summary)
            menu.addItem(NSMenuItem.separator())

            // Individual sessions (click to jump)
            for session in sessions.prefix(6) {
                let statusDot: String
                switch session.status {
                case .running:    statusDot = "🟢"
                case .needsInput: statusDot = "🟡"
                case .error:      statusDot = "🔴"
                case .idle:       statusDot = "⚪"
                default:          statusDot = "⚫"
                }
                let item = NSMenuItem(
                    title: "\(statusDot) \(session.displayName)",
                    action: #selector(jumpToSession(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = session
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Show/Hide
        let toggle = NSMenuItem(title: "Show/Hide Office", action: #selector(toggleWindow), keyEquivalent: "o")
        toggle.target = self
        menu.addItem(toggle)

        // Size presets submenu
        let sizeMenu = NSMenu()
        for preset in WindowPreset.allCases {
            let item = NSMenuItem(title: preset.rawValue, action: #selector(setSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset
            if preset == windowController.currentPreset { item.state = .on }
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        // Setup (only adds AgentPong hooks, preserves existing settings)
        let setupItem = NSMenuItem(title: "Install Claude Hooks", action: #selector(runSetup), keyEquivalent: "")
        setupItem.target = self
        menu.addItem(setupItem)

        menu.addItem(NSMenuItem.separator())

        // Update notification (only shown when an update is available)
        if let newVersion = updateAvailable {
            let updateItem = NSMenuItem(title: "Update to \(newVersion)", action: #selector(copyUpgradeCommand), keyEquivalent: "")
            updateItem.target = self
            updateItem.attributedTitle = NSAttributedString(
                string: "Update to \(newVersion)",
                attributes: [.foregroundColor: NSColor.systemOrange]
            )
            menu.addItem(updateItem)
        }

        // Version (static, not clickable)
        let versionItem = NSMenuItem(title: "AgentPong v\(AppVersion.display)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        // Quit
        let quit = NSMenuItem(title: "Quit AgentPong", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func jumpToSession(_ sender: NSMenuItem) {
        guard let session = sender.representedObject as? Session else { return }
        WindowJumper.shared.jump(to: session)
    }

    @objc private func setSize(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? WindowPreset else { return }
        windowController.setPreset(preset)
    }

    @objc private func toggleWindow() {
        windowController.toggleWindow()
    }

    @objc private func runSetup() {
        _ = handleSetup()
    }

    @objc private func copyUpgradeCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("brew upgrade agentpong && brew services restart agentpong", forType: .string)

        let alert = NSAlert()
        alert.messageText = "Upgrade command copied"
        alert.informativeText = "Paste in terminal:\nbrew upgrade agentpong && brew services restart agentpong"
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.runModal()
    }

    /// Check `brew info agentpong` for a newer version in the background.
    private func checkBrewUpdate() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            guard let brewPath = brewPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }

            let task = Process()
            task.executableURL = URL(fileURLWithPath: brewPath)
            task.arguments = ["info", "--json=v2", "agentpong"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let formulae = json["formulae"] as? [[String: Any]],
                   let formula = formulae.first,
                   let versions = formula["versions"] as? [String: Any],
                   let stable = versions["stable"] as? String,
                   stable != AppVersion.display {
                    DispatchQueue.main.async {
                        self?.updateAvailable = stable
                    }
                }
            } catch {}
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowController = FloatingWindowController()
    private var menuBarController: MenuBarController?
    private let hookServer = HookServer(port: 52775)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (we live in the menu bar)
        NSApp.setActivationPolicy(.accessory)

        // Setup menu bar
        menuBarController = MenuBarController(windowController: windowController)
        menuBarController?.setup()

        // Show the floating window
        windowController.showWindow()

        // Start hook server for real-time Claude Code events
        do {
            try hookServer.start()
            NSLog("[AgentPong] Hook server started on port \(hookServer.actualPort)")
            // Write port file so hook-sender.sh can find us
            writePortFile(port: hookServer.actualPort)
        } catch {
            NSLog("[AgentPong] Failed to start hook server: \(error)")
        }

        // Pass hookServer to the OfficeScene
        windowController.passHookServer(hookServer)
    }

    private func writePortFile(port: UInt16) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let portFile = home.appendingPathComponent(".agentpong/server-port")
        try? String(port).write(to: portFile, atomically: true, encoding: .utf8)
    }
}

// MARK: - CLI Mode

func handleCLI() -> Bool {
    let args = CommandLine.arguments
    guard args.count >= 2 else { return false }

    let command = args[1]

    switch command {
    case "--version", "-v", "version":
        print("AgentPong \(AppVersion.display)")
        return true
    case "report":
        return handleReport(args: Array(args.dropFirst(2)))
    case "setup":
        return handleSetup()
    case "status":
        return handleStatus()
    default:
        return false
    }
}

func handleReport(args: [String]) -> Bool {
    var sessionId: String?
    var event: String?
    var status: String?
    var cwd: String?

    var i = 0
    while i < args.count {
        switch args[i] {
        case "--session":
            i += 1; if i < args.count { sessionId = args[i] }
        case "--event":
            i += 1; if i < args.count { event = args[i] }
        case "--status":
            i += 1; if i < args.count { status = args[i] }
        case "--cwd":
            i += 1; if i < args.count { cwd = args[i] }
        default:
            break
        }
        i += 1
    }

    guard let sid = sessionId, let evt = event else {
        print("Usage: agentpong report --session ID --event EVENT [--status STATUS] [--cwd CWD]")
        return true
    }

    do {
        let writer = SessionWriter()
        try writer.report(sessionId: sid, event: evt, status: status, cwd: cwd)
    } catch {
        print("Error: \(error.localizedDescription)")
    }
    return true
}

func handleSetup() -> Bool {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let hooksDir = home.appendingPathComponent(".agentpong/hooks")
    let hookScript = hooksDir.appendingPathComponent("hook-sender.sh")

    // Create hooks directory
    try? FileManager.default.createDirectory(at: hooksDir, withIntermediateDirectories: true)

    // Write hook-sender.sh
    // NOTE: This reads JSON from stdin (Claude Code's hook API) and forwards
    // it directly to the local HTTP server. No string interpolation = no
    // JSON injection risk. Uses jq to extract fields for timeout logic.
    // Read hook-sender.sh from the repo Scripts/ dir or use the embedded version.
    // The script handles jq-less fallback and reads port from server-port file.
    let scriptContent = """
    #!/bin/bash
    set -euo pipefail
    PORT_FILE="$HOME/.agentpong/server-port"
    PORT=$(cat "$PORT_FILE" 2>/dev/null || echo "52775")
    URL="http://localhost:${PORT}/hook"
    INPUT=$(cat)
    if command -v jq >/dev/null 2>&1; then
      INPUT=$(echo "$INPUT" | jq --argjson pid "$PPID" '. + {claude_pid: $pid}')
      EVENT_NAME=$(echo "$INPUT" | jq -r '.hook_event_name // ""')
      PERM_MODE=$(echo "$INPUT" | jq -r '.permission_mode // ""')
    else
      EVENT_NAME=$(echo "$INPUT" | grep -o '"hook_event_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//' || echo "")
      PERM_MODE=$(echo "$INPUT" | grep -o '"permission_mode"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//' || echo "")
    fi
    if [ "$EVENT_NAME" = "PreToolUse" ] && [ "$PERM_MODE" = "ask" ]; then
      TIMEOUT=300
    else
      TIMEOUT=5
    fi
    RESPONSE=$(echo "$INPUT" | curl -s --max-time "$TIMEOUT" -X POST -H "Content-Type: application/json" -D /dev/stderr -d @- "$URL" 2>/tmp/agentpong-hook-headers.$$ || true)
    if [ "$EVENT_NAME" = "PreToolUse" ] && [ "$PERM_MODE" = "ask" ] && [ -n "$RESPONSE" ]; then
      echo "$RESPONSE"
      EXIT_CODE=$(grep -i "X-Hook-Exit-Code" /tmp/agentpong-hook-headers.$$ 2>/dev/null | tr -dc '0-9' || echo "0")
      rm -f /tmp/agentpong-hook-headers.$$
      exit "${EXIT_CODE:-0}"
    fi
    rm -f /tmp/agentpong-hook-headers.$$ 2>/dev/null
    exit 0
    """

    do {
        try scriptContent.write(to: hookScript, atomically: true, encoding: .utf8)
        // Make executable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: hookScript.path
        )
    } catch {
        print("Error writing hook script: \(error)")
        return true
    }

    // Update Claude settings -- append hooks, don't overwrite existing ones
    let claudeSettings = home.appendingPathComponent(".claude/settings.json")
    var settings: [String: Any] = [:]
    if let data = try? Data(contentsOf: claudeSettings),
       let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        settings = existing
    }

    let hookPath = hookScript.path
    let hookEvents = [
        "SessionStart", "SessionEnd", "Stop",
        "PreToolUse", "PostToolUse",
        "Notification"
    ]

    var hooks = settings["hooks"] as? [String: Any] ?? [:]
    // Claude Code hooks format: each event has an array of hook groups.
    // Each group has an optional "matcher" and a "hooks" array of command entries.
    let agentPongGroup: [String: Any] = [
        "hooks": [["type": "command", "command": hookPath]]
    ]
    for event in hookEvents {
        var eventGroups = hooks[event] as? [[String: Any]] ?? []
        // Don't duplicate: remove any existing AgentPong hook group
        eventGroups.removeAll { group in
            guard let groupHooks = group["hooks"] as? [[String: Any]] else { return false }
            return groupHooks.contains { ($0["command"] as? String)?.contains("agentpong") == true }
        }
        // Append our hook group (preserves other tools' hooks)
        eventGroups.append(agentPongGroup)
        hooks[event] = eventGroups
    }
    settings["hooks"] = hooks

    if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
        try? data.write(to: claudeSettings, options: .atomic)
    }

    // Ensure sessions directory exists
    do {
        let writer = SessionWriter()
        try writer.ensureDirectory()
    } catch {
        print("Warning: could not create sessions directory: \(error.localizedDescription)")
    }

    print("AgentPong hooks installed!")
    print("  Hook script: \(hookPath)")
    print("  Claude settings updated: \(claudeSettings.path)")
    print("  Events: \(hookEvents.joined(separator: ", "))")
    print("\nRestart Claude Code for hooks to take effect.")
    return true
}

func handleStatus() -> Bool {
    let reader = SessionReader()
    let sessions = reader.readAll()

    if sessions.isEmpty {
        print("No active sessions.")
        print("Run `agentpong setup` to configure Claude Code hooks.")
    } else {
        print("\(sessions.count) active session(s):")
        for s in sessions {
            print("  [\(s.status.rawValue)] \(s.displayName) (\(s.id.prefix(8)))")
        }
    }
    return true
}

// MARK: - Entry Point

// Check if running in CLI mode
if handleCLI() {
    exit(0)
}

// GUI mode
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
