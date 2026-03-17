import SpriteKit
import Shared

/// The main SpriteKit scene -- cozy room with husky pet and reactive monitor screens.
///
/// Architecture:
///   Background (Gemini)  ->  z:-1000
///   Screen overlays       ->  z:40
///   Husky pet             ->  z:50+ (depth sorted)
///   Info overlay          ->  z:300
///   Permission bubbles    ->  z:150
///   UI (status text)      ->  z:200
public class OfficeScene: SKScene {

    // MARK: - Properties

    private var sessions: [Session] = []
    private let sessionReader = SessionReader()
    private let zoneManager = ZoneManager()

    private var lastPollTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private let pollInterval: TimeInterval = 5.0

    // Nodes
    private var screenNodes: [ScreenNode] = []  // [left, center, right]
    private var husky: HuskyNode?
    private var huskyShadow: SKNode?
    private var statusLabel: SKLabelNode?
    private var infoOverlay: SKNode?

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
    private let overlayLayer = SKNode()      // z: 300

    // Track nap timer
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
        overlayLayer.zPosition = 300

        addChild(effectsLayer)
        addChild(petLayer)
        addChild(uiLayer)
        addChild(overlayLayer)

        setupBackground()
        setupScreens()
        setupHusky()
        setupUI()
        refreshSessions()
    }

    public override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        if currentTime - lastPollTime >= pollInterval {
            lastPollTime = currentTime
            refreshSessions()
        }

        husky?.update(deltaTime: dt)
        if let h = husky {
            h.zPosition = zoneManager.zPosition(for: h.position.y)
            let pScale = zoneManager.perspectiveScale(for: h.position.y)
            h.setScale(pScale)

            huskyShadow?.position = CGPoint(x: h.position.x, y: h.position.y + HuskyNode.shadowYOffset)
            huskyShadow?.zPosition = h.zPosition - 0.1
            huskyShadow?.setScale(pScale)
        }

        // Nap timer
        let anyActive = screenNodes.contains { $0.status != .off }
        if !anyActive {
            allOffTimer += dt
            if allOffTimer >= napDelay {
                allOffTimer = -999
                husky?.goNap()
            }
        } else {
            allOffTimer = 0
        }
    }

    // MARK: - Background

    private func setupBackground() {
        if loadBackgroundImage() { return }

        let floorColor = SKColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 1.0)
        let floor = SKSpriteNode(color: floorColor, size: CGSize(width: 320, height: 320))
        floor.position = CGPoint(x: 160, y: 160)
        floor.zPosition = -1000
        addChild(floor)
    }

    private func loadBackgroundImage() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser

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

    // MARK: - Screens (Triple Monitor)

    private func setupScreens() {
        for corners in zoneManager.allMonitors {
            let screen = ScreenNode(corners: corners)
            screen.zPosition = 40
            addChild(screen)
            screenNodes.append(screen)
        }
    }

    /// Distribute sessions across monitors. Priority: running > needsInput > error > idle.
    /// Center monitor gets first session, then left, then right.
    private func distributeSessionsToScreens() {
        let visible = sessions.filter(\.isVisible)

        // Sort by priority: running first, then needsInput, error, idle
        let sorted = visible.sorted { a, b in
            priority(a.status) > priority(b.status)
        }

        // Assign: center (index 1) first, then left (0), then right (2)
        let assignOrder = [1, 0, 2]
        for (i, screenIdx) in assignOrder.enumerated() {
            guard screenIdx < screenNodes.count else { continue }
            if i < sorted.count {
                screenNodes[screenIdx].assignSession(sorted[i])
            } else {
                screenNodes[screenIdx].assignSession(nil)
            }
        }
    }

    private func priority(_ status: SessionStatus) -> Int {
        switch status {
        case .running: return 4
        case .needsInput: return 3
        case .error: return 2
        case .idle: return 1
        case .done, .unavailable: return 0
        }
    }

    /// The highest status across all screens (for husky reactions).
    private var highestScreenStatus: ScreenNode.ScreenStatus {
        screenNodes.map(\.status).max() ?? .off
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
        let oldStatus = highestScreenStatus

        sessions = newSessions
        distributeSessionsToScreens()
        updateStatusLabel()

        let newStatus = highestScreenStatus
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

        // Dismiss info overlay if shown (click outside)
        if infoOverlay != nil {
            dismissInfoOverlay()
            return
        }

        // Permission bubble first
        for screen in screenNodes {
            if screen.handlePermissionClick(scenePoint: location) { return }
        }

        // Click on a screen -> show info overlay
        for screen in screenNodes {
            if screen.hitTest(scenePoint: location), screen.session != nil {
                showInfoOverlay(for: screen)
                return
            }
        }

        // Click on husky
        if let h = husky, h.hitTest(location) {
            h.handleClick(currentTime: lastUpdateTime)
            return
        }
    }

    public override func mouseMoved(with event: NSEvent) {
        let location = event.location(in: self)

        if husky?.behavior == .watchingCursor {
            husky?.faceCursor(scenePoint: location)
        }
    }

    // MARK: - Info Overlay (RPG-style dialogue box)

    private func showInfoOverlay(for screen: ScreenNode) {
        guard let session = screen.session else { return }
        dismissInfoOverlay()

        let overlay = SKNode()
        overlay.name = "info-overlay"
        overlay.position = CGPoint(x: 160, y: 160)
        overlay.zPosition = 300

        // Dimmed backdrop
        let backdrop = SKShapeNode(rectOf: CGSize(width: 320, height: 320))
        backdrop.fillColor = SKColor(white: 0, alpha: 0.4)
        backdrop.strokeColor = .clear
        backdrop.name = "backdrop"
        overlay.addChild(backdrop)

        // RPG-style panel (dark box with pixel border)
        let panelW: CGFloat = 200
        let panelH: CGFloat = 90
        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 3)
        panel.fillColor = SKColor(red: 0.06, green: 0.05, blue: 0.08, alpha: 0.95)
        panel.strokeColor = screen.status.color.withAlphaComponent(0.8)
        panel.lineWidth = 1.5
        panel.name = "panel"
        overlay.addChild(panel)

        // Inner border (double-border RPG style)
        let inner = SKShapeNode(rectOf: CGSize(width: panelW - 6, height: panelH - 6), cornerRadius: 2)
        inner.fillColor = .clear
        inner.strokeColor = SKColor(white: 0.3, alpha: 0.3)
        inner.lineWidth = 0.5
        panel.addChild(inner)

        // Session name (title)
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = session.displayName
        title.fontSize = 8
        title.fontColor = screen.status.color
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 28)
        panel.addChild(title)

        // Status line
        let statusLine = SKLabelNode(fontNamed: "Menlo")
        statusLine.text = "status: \(session.status.rawValue)"
        statusLine.fontSize = 6
        statusLine.fontColor = SKColor(white: 0.7, alpha: 0.9)
        statusLine.verticalAlignmentMode = .center
        statusLine.position = CGPoint(x: 0, y: 16)
        panel.addChild(statusLine)

        // CWD
        if let cwd = session.cwd {
            let cwdLabel = SKLabelNode(fontNamed: "Menlo")
            let shortCwd = cwd.count > 35 ? "..." + String(cwd.suffix(32)) : cwd
            cwdLabel.text = shortCwd
            cwdLabel.fontSize = 4.5
            cwdLabel.fontColor = SKColor(white: 0.5, alpha: 0.8)
            cwdLabel.verticalAlignmentMode = .center
            cwdLabel.position = CGPoint(x: 0, y: 6)
            panel.addChild(cwdLabel)
        }

        // Jump button
        let jumpBtn = SKShapeNode(rectOf: CGSize(width: 60, height: 14), cornerRadius: 2)
        jumpBtn.fillColor = SKColor(red: 0.15, green: 0.4, blue: 0.6, alpha: 1.0)
        jumpBtn.strokeColor = SKColor(red: 0.2, green: 0.5, blue: 0.7, alpha: 0.8)
        jumpBtn.lineWidth = 0.5
        jumpBtn.position = CGPoint(x: -35, y: -22)
        jumpBtn.name = "jump-btn"
        panel.addChild(jumpBtn)

        let jumpLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        jumpLabel.text = "JUMP"
        jumpLabel.fontSize = 6
        jumpLabel.fontColor = .white
        jumpLabel.verticalAlignmentMode = .center
        jumpLabel.position = CGPoint(x: -35, y: -22)
        panel.addChild(jumpLabel)

        // Close button
        let closeBtn = SKShapeNode(rectOf: CGSize(width: 60, height: 14), cornerRadius: 2)
        closeBtn.fillColor = SKColor(white: 0.2, alpha: 0.8)
        closeBtn.strokeColor = SKColor(white: 0.4, alpha: 0.5)
        closeBtn.lineWidth = 0.5
        closeBtn.position = CGPoint(x: 35, y: -22)
        closeBtn.name = "close-btn"
        panel.addChild(closeBtn)

        let closeLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        closeLabel.text = "CLOSE"
        closeLabel.fontSize = 6
        closeLabel.fontColor = SKColor(white: 0.7, alpha: 0.9)
        closeLabel.verticalAlignmentMode = .center
        closeLabel.position = CGPoint(x: 35, y: -22)
        panel.addChild(closeLabel)

        // Animate in: scale up from small + fade
        overlay.setScale(0.3)
        overlay.alpha = 0
        overlay.run(SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.15),
            SKAction.fadeIn(withDuration: 0.15)
        ]))

        overlayLayer.addChild(overlay)
        infoOverlay = overlay

        // Store session ID for jump action
        overlay.userData = NSMutableDictionary()
        overlay.userData?["sessionId"] = session.id
    }

    private func dismissInfoOverlay() {
        guard let overlay = infoOverlay else { return }
        overlay.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 0.3, duration: 0.1),
                SKAction.fadeOut(withDuration: 0.1)
            ]),
            SKAction.removeFromParent()
        ]))
        infoOverlay = nil
    }

    private func handleOverlayClick(at location: CGPoint) -> Bool {
        guard let overlay = infoOverlay else { return false }

        // Convert to overlay-local coords (overlay is at scene center)
        let local = CGPoint(x: location.x - 160, y: location.y - 160)

        // Jump button: centered at (-35, -22) relative to panel (which is at 0,0 in overlay)
        let jumpArea = CGRect(x: -65, y: -30, width: 60, height: 16)
        if jumpArea.contains(local) {
            if let sessionId = overlay.userData?["sessionId"] as? String,
               let session = sessions.first(where: { $0.id == sessionId }) {
                WindowJumper.shared.jump(to: session)
            }
            dismissInfoOverlay()
            return true
        }

        // Close button: centered at (35, -22)
        let closeArea = CGRect(x: 5, y: -30, width: 60, height: 16)
        if closeArea.contains(local) {
            dismissInfoOverlay()
            return true
        }

        return false
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
        case "SessionEnd": writerEvent = "stop"
        case "Stop": writerEvent = "idle"
        case "PreToolUse", "PostToolUse": writerEvent = "active"
        case "Notification":
            if event.notificationType == "permission_prompt" {
                writerEvent = "needsInput"
            } else {
                writerEvent = "notify"
            }
        default: writerEvent = "active"
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let writer = SessionWriter()
            try? writer.report(
                sessionId: event.sessionId,
                event: writerEvent,
                cwd: event.cwd,
                pid: event.claudePid
            )
            DispatchQueue.main.async {
                self?.refreshSessions()
            }
        }
    }

    private func handlePermissionRequest(_ event: HookEvent, respond: @escaping (HookDecision) -> Void) {
        let sessionId = event.sessionId

        pendingPermissions[sessionId] = PendingPermission(event: event, respond: respond)
        refreshSessions()

        // Show permission bubble on the screen that has this session
        showPermissionOnScreen(event: event, respond: respond)
    }

    private func showPermissionOnScreen(event: HookEvent, respond: @escaping (HookDecision) -> Void) {
        // Find the screen showing this session
        let screen = screenNodes.first { $0.session?.id == event.sessionId } ?? screenNodes[safe: 1]
        guard let screen else { return }

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

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
