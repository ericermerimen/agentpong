import SpriteKit
import Shared

/// The main SpriteKit scene -- cozy room with husky pet and reactive monitor screen.
///
/// Architecture:
///   Background (Gemini)  →  z:-1000
///   Screen overlay        →  z:40
///   Husky pet             →  z:50+ (depth sorted)
///   Permission bubbles    →  z:150
///   UI (status text)      →  z:200
public class OfficeScene: SKScene {

    // MARK: - Properties

    private var sessions: [Session] = []
    private let sessionReader = SessionReader()
    private let zoneManager = ZoneManager()

    private var lastPollTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private let pollInterval: TimeInterval = 5.0

    // Nodes
    private var screenNode: ScreenNode?
    private var husky: HuskyNode?
    private var huskyShadow: SKNode?
    private var statusLabel: SKLabelNode?

    // Hook server for real-time events
    private struct PendingPermission {
        let event: HookEvent
        let respond: (HookDecision) -> Void
    }
    private var pendingPermissions: [String: PendingPermission] = [:]

    // Layers
    private let effectsLayer = SKNode()      // z: 45
    private let petLayer = SKNode()          // z: 50
    private let uiLayer = SKNode()           // z: 200

    // Track nap timer: how long all screens have been off
    private var allOffTimer: TimeInterval = 0
    private let napDelay: TimeInterval = 30.0

    public var onSessionsUpdated: (([Session]) -> Void)?
    public var currentSessions: [Session] { sessions }

    public var hookServer: HookServer? {
        didSet { subscribeToHookEvents() }
    }

    // MARK: - Lifecycle

    public override func didMove(to view: SKView) {
        size = CGSize(width: 320, height: 320)
        scaleMode = .aspectFit
        backgroundColor = SKColor(red: 0.04, green: 0.03, blue: 0.02, alpha: 1.0)

        effectsLayer.zPosition = 45
        petLayer.zPosition = 50
        uiLayer.zPosition = 200

        addChild(effectsLayer)
        addChild(petLayer)
        addChild(uiLayer)

        setupBackground()
        setupScreen()
        setupHusky()
        setupUI()
        refreshSessions()
    }

    public override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Poll sessions
        if currentTime - lastPollTime >= pollInterval {
            lastPollTime = currentTime
            refreshSessions()
        }

        // Update husky
        husky?.update(deltaTime: dt)
        if let h = husky {
            h.zPosition = zoneManager.zPosition(for: h.position.y)
            let pScale = zoneManager.perspectiveScale(for: h.position.y)
            h.setScale(pScale)

            huskyShadow?.position = CGPoint(x: h.position.x, y: h.position.y - 1)
            huskyShadow?.zPosition = h.zPosition - 0.1
            huskyShadow?.setScale(pScale)
        }

        // Nap timer: if all screens off for 30s, husky goes to bed
        if screenNode?.highestStatus == .off || screenNode?.highestStatus == nil {
            allOffTimer += dt
            if allOffTimer >= napDelay {
                allOffTimer = -999  // Don't re-trigger
                husky?.goNap()
            }
        } else {
            allOffTimer = 0
        }
    }

    // MARK: - Background

    private func setupBackground() {
        if loadBackgroundImage() { return }

        // Fallback: dark wood floor
        let floorColor = SKColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 1.0)
        let floor = SKSpriteNode(color: floorColor, size: CGSize(width: 320, height: 320))
        floor.position = CGPoint(x: 160, y: 160)
        floor.zPosition = -1000
        addChild(floor)
    }

    private func loadBackgroundImage() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser

        // Try split layers first (background + foreground for depth occlusion)
        let bgPath = home.appendingPathComponent(".agentpong/themes/background.png")
        let fgPath = home.appendingPathComponent(".agentpong/themes/foreground.png")

        if FileManager.default.fileExists(atPath: bgPath.path),
           FileManager.default.fileExists(atPath: fgPath.path),
           let bgImage = NSImage(contentsOfFile: bgPath.path),
           let fgImage = NSImage(contentsOfFile: fgPath.path) {

            let bgTex = SKTexture(image: bgImage)
            bgTex.filteringMode = .nearest
            let bg = SKSpriteNode(texture: bgTex, size: CGSize(width: 320, height: 320))
            bg.position = CGPoint(x: 160, y: 160)
            bg.zPosition = -1000
            addChild(bg)

            let fgTex = SKTexture(image: fgImage)
            fgTex.filteringMode = .nearest
            let fg = SKSpriteNode(texture: fgTex, size: CGSize(width: 320, height: 320))
            fg.position = CGPoint(x: 160, y: 160)
            fg.zPosition = 500
            addChild(fg)

            return true
        }

        // Fallback: single background image
        for ext in ["png", "jpg", "webp"] {
            let path = home.appendingPathComponent(".agentpong/themes/default.\(ext)")
            if FileManager.default.fileExists(atPath: path.path),
               let image = NSImage(contentsOfFile: path.path) {
                let texture = SKTexture(image: image)
                texture.filteringMode = .nearest
                let bg = SKSpriteNode(texture: texture, size: CGSize(width: 320, height: 320))
                bg.position = CGPoint(x: 160, y: 160)
                bg.zPosition = -1000
                addChild(bg)
                return true
            }
        }
        return false
    }

    // MARK: - Screen

    private func setupScreen() {
        let screen = ScreenNode(
            center: zoneManager.monitorCenter,
            size: zoneManager.monitorSize
        )
        screen.zPosition = 40
        addChild(screen)
        screenNode = screen
    }

    // MARK: - Husky

    private func setupHusky() {
        let h = HuskyNode(
            startPosition: zoneManager.floorCenter,
            wanderZone: zoneManager.walkableArea,
            spriteSize: zoneManager.huskySize
        )
        h.dogBedPosition = zoneManager.dogBedPosition
        h.waterBowlPosition = zoneManager.waterBowlPosition
        h.monitorPosition = zoneManager.monitorCenter
        h.lampPosition = zoneManager.lampPosition
        h.lampExclusionRadius = zoneManager.lampExclusionRadius
        petLayer.addChild(h)
        husky = h

        // Shadow is a SEPARATE node in the scene, not a child of HuskyNode.
        // This way perspective setScale() on the husky doesn't distort the shadow.
        let shadowNode = h.shadow
        shadowNode.position = h.position
        petLayer.addChild(shadowNode)
        huskyShadow = shadowNode
    }

    // MARK: - UI

    private func setupUI() {
        let label = SKLabelNode(fontNamed: "Menlo")
        label.fontSize = 6
        label.fontColor = SKColor(white: 0.5, alpha: 0.7)
        label.position = CGPoint(x: 160, y: 6)
        uiLayer.addChild(label)
        statusLabel = label
        updateStatusLabel()
    }

    // MARK: - Session Management

    private func refreshSessions() {
        let newSessions = sessionReader.readAll()
        let oldStatus = screenNode?.highestStatus ?? .off

        sessions = newSessions
        screenNode?.updateFromSessions(sessions)
        updateStatusLabel()

        // Trigger husky reaction on status change
        let newStatus = screenNode?.highestStatus ?? .off
        if newStatus != oldStatus {
            husky?.reactToScreenStatus(newStatus)
        }

        onSessionsUpdated?(sessions)
    }

    private func updateStatusLabel() {
        let visible = sessions.filter(\.isVisible)
        if visible.isEmpty {
            statusLabel?.text = "office is quiet"
        } else {
            let r = visible.filter { $0.status == .running }.count
            let i = visible.filter { $0.status == .idle || $0.status == .needsInput }.count
            let e = visible.filter { $0.status == .error }.count
            var p: [String] = []
            if r > 0 { p.append("\(r) working") }
            if i > 0 { p.append("\(i) idle") }
            if e > 0 { p.append("\(e) error") }
            statusLabel?.text = p.joined(separator: " | ")
        }
    }

    // MARK: - Mouse Interaction

    public override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)

        // Permission bubble first (highest priority)
        if let screen = screenNode, screen.handlePermissionClick(scenePoint: location) {
            return
        }

        // Click on screen → jump to session
        if let screen = screenNode, screen.hitTest(scenePoint: location) {
            handleScreenClick(screen)
            return
        }

        // Click on husky → playful or scared depending on click frequency
        if let h = husky, h.hitTest(location) {
            h.handleClick(currentTime: lastUpdateTime)
            return
        }
    }

    private func handleScreenClick(_ screen: ScreenNode) {
        let sessions = screen.sessionsForClick()
        guard let session = sessions.first else { return }

        // Jump to session via PID activation
        if let pid = session.pid {
            let app = NSRunningApplication(processIdentifier: pid_t(pid))
            app?.activate()
        }
    }

    public override func mouseMoved(with event: NSEvent) {
        let location = event.location(in: self)

        // If husky is watching cursor, update its facing direction
        if husky?.behavior == .watchingCursor {
            husky?.faceCursor(scenePoint: location)
        }
    }

    // MARK: - Hook Server Integration

    private func subscribeToHookEvents() {
        hookServer?.onEvent = { [weak self] event in
            self?.handleHookEvent(event)
        }

        hookServer?.onPermissionRequest = { [weak self] event, respond in
            self?.handlePermissionRequest(event, respond: respond)
        }
    }

    private func handleHookEvent(_ event: HookEvent) {
        let writerEvent: String
        switch event.hookEventName {
        case "SessionStart": writerEvent = "start"
        case "SessionEnd", "Stop": writerEvent = "stop"
        case "PreToolUse", "PostToolUse": writerEvent = "active"
        case "Notification": writerEvent = "notify"
        default: writerEvent = "active"
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let writer = SessionWriter()
            try? writer.report(
                sessionId: event.sessionId,
                event: writerEvent,
                cwd: event.cwd
            )
            DispatchQueue.main.async {
                self?.refreshSessions()
            }
        }
    }

    private func handlePermissionRequest(_ event: HookEvent, respond: @escaping (HookDecision) -> Void) {
        let sessionId = event.sessionId

        pendingPermissions[sessionId] = PendingPermission(event: event, respond: respond)

        // Force refresh to show session
        refreshSessions()

        // Show permission bubble on screen
        showPermissionOnScreen(event: event, respond: respond)
    }

    private func showPermissionOnScreen(event: HookEvent, respond: @escaping (HookDecision) -> Void) {
        guard let screen = screenNode else { return }

        let toolDesc = "\(event.toolName ?? "tool"): \(truncate(event.toolInputDescription, to: 30))"
        screen.showPermissionBubble(text: toolDesc) { [weak self] allowed in
            respond(HookDecision(allow: allowed))
            self?.pendingPermissions.removeValue(forKey: event.sessionId)
        }

        // Auto-allow after 5 minutes
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
            guard self?.pendingPermissions[event.sessionId] != nil else { return }
            respond(HookDecision(allow: true, reason: "auto-allowed: user did not respond in 5 minutes"))
            self?.pendingPermissions.removeValue(forKey: event.sessionId)
            screen.removePermissionBubble()
        }
    }

    private func truncate(_ s: String, to length: Int) -> String {
        s.count > length ? String(s.prefix(length)) + "..." : s
    }
}
