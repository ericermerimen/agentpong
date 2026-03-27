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
    private let screenContentManager = ScreenContentManager()

    private var lastPollTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private let pollInterval: TimeInterval = 5.0

    // Nodes
    private var screenNodes: [ScreenNode] = []  // [left, center, right]
    private var husky: HuskyNode?
    private var huskyShadow: SKNode?
    private var statusLabel: SKLabelNode?
    private var statusShadowLabel: SKLabelNode?
    private var infoOverlay: SKNode?
    private var overlayRowNodes: [SKShapeNode] = []
    private var overlayRowBaseColors: [SKColor] = []
    private var hoveredRowIndex: Int = -1

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
        uiLayer.zPosition = 550       // above lamp (450) and foreground (500)
        overlayLayer.zPosition = 600   // above everything

        addChild(effectsLayer)
        addChild(petLayer)
        addChild(uiLayer)
        addChild(overlayLayer)

        setupBackground()
        setupForegroundObjects()
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

        // Screen content rotation (decorative textures)
        screenContentManager.update(deltaTime: dt, sessions: sessions, screenNodes: screenNodes)
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

        // Try background.png first (clean room without foreground objects)
        let bgPath = home.appendingPathComponent(".agentpong/themes/background.png")
        if FileManager.default.fileExists(atPath: bgPath.path),
           let bgImage = NSImage(contentsOfFile: bgPath.path) {
            let bgTex = SKTexture(image: bgImage)
            bgTex.filteringMode = .nearest
            let bg = SKSpriteNode(texture: bgTex, size: CGSize(width: 320, height: 320))
            bg.position = CGPoint(x: 160, y: 160)
            bg.zPosition = -1000
            addChild(bg)

            // Optional foreground overlay (full-scene layer)
            let fgPath = home.appendingPathComponent(".agentpong/themes/foreground.png")
            if FileManager.default.fileExists(atPath: fgPath.path),
               let fgImage = NSImage(contentsOfFile: fgPath.path) {
                let fgTex = SKTexture(image: fgImage)
                fgTex.filteringMode = .nearest
                let fg = SKSpriteNode(texture: fgTex, size: CGSize(width: 320, height: 320))
                fg.position = CGPoint(x: 160, y: 160)
                fg.zPosition = 500
                addChild(fg)
            }
            return true
        }

        // Fallback: single default image
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

    // MARK: - Foreground Objects

    /// Load isolated object sprites (lamp, plant, water bowl) as individual nodes.
    /// Positions measured by diffing original image vs clean background.
    /// These are placed in petLayer for proper depth sorting with the husky.
    private func setupForegroundObjects() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let objectsDir = home.appendingPathComponent(".agentpong/sprites/objects")
        let imgScale: CGFloat = 1024.0 / 320.0  // 3.2

        // Positions measured from original image diff (image center coords):
        //   Lamp:  (483, 244) -> scene (150.9, 243.9)
        //   Plant: (876, 836) -> scene (273.9, 58.9)
        //   Bowl:  (364, 941) -> scene (113.6, 25.9)

        // Lamp -- hangs from ceiling. Globe center measured at scene (160.2, 213.7).
        // Pole top at scene y=273.1. The sprite has pole at top, globe at bottom.
        // Anchor at top-center, position at pole top so it hangs naturally.
        // NOTE: pole x=126.5 but globe center x=160.2 -- the globe is off-center
        // in the sprite. Use globe-centered x so it matches the original image.
        if let lampImg = NSImage(contentsOfFile: objectsDir.appendingPathComponent("lamp.png").path) {
            let tex = SKTexture(image: lampImg)
            tex.filteringMode = .nearest
            let node = SKSpriteNode(texture: tex)
            node.size = CGSize(width: tex.size().width / imgScale, height: tex.size().height / imgScale)
            node.anchorPoint = CGPoint(x: 0.5, y: 1.0)
            node.position = CGPoint(x: 168.0, y: 310.0)
            node.zPosition = 400  // always above husky (ceiling object)
            petLayer.addChild(node)
        }

        // Plant -- bottom right, closer to camera, should occlude husky when behind
        if let plantImg = NSImage(contentsOfFile: objectsDir.appendingPathComponent("plant.png").path) {
            let tex = SKTexture(image: plantImg)
            tex.filteringMode = .nearest
            let node = SKSpriteNode(texture: tex)
            node.size = CGSize(width: tex.size().width / imgScale, height: tex.size().height / imgScale)
            node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            node.position = CGPoint(x: 273.9, y: 58.9)
            node.zPosition = zoneManager.zPosition(for: 58.9)
            petLayer.addChild(node)
        }

        // Water bowl -- small, on the floor
        if let bowlImg = NSImage(contentsOfFile: objectsDir.appendingPathComponent("water-bowl.png").path) {
            let tex = SKTexture(image: bowlImg)
            tex.filteringMode = .nearest
            let node = SKSpriteNode(texture: tex)
            node.size = CGSize(width: tex.size().width / imgScale, height: tex.size().height / imgScale)
            node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            node.position = CGPoint(x: 116.6, y: 26.9)
            node.zPosition = zoneManager.zPosition(for: 25.9)
            petLayer.addChild(node)
        }
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

    /// Distribute sessions across monitors: one session per screen.
    /// Sorted by priority (needsInput > error > running > idle).
    /// Center monitor gets the most important session, then left, then right.
    private func distributeSessionsToScreens() {
        let visible = sessions.filter(\.isVisible)
            .sorted { priority($0.status) > priority($1.status) }

        // Assign: center (index 1) first, then left (0), then right (2)
        let assignOrder = [1, 0, 2]
        for (i, screenIdx) in assignOrder.enumerated() {
            guard screenIdx < screenNodes.count else { continue }
            screenNodes[screenIdx].assignSession(i < visible.count ? visible[i] : nil)
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
        // Floor text: perspective values from user's browser tuner tool.
        // Tuner values: x=527, y=576, fs=80, rotateX=55, scaleX=0.75
        // Converted: position=(164.7, 140.0), fontSize=50, yScale=cos(55deg)=0.574
        // Dark color + multiply blend = text looks stenciled/painted on the wood floor.
        // Shadow label (offset slightly for deboss/3D effect)
        let shadow = SKLabelNode(fontNamed: "Menlo-Bold")
        shadow.fontSize = 38
        shadow.fontColor = SKColor(red: 0.08, green: 0.05, blue: 0.02, alpha: 0.15)
        shadow.horizontalAlignmentMode = .center
        shadow.verticalAlignmentMode = .center
        shadow.numberOfLines = 0
        shadow.preferredMaxLayoutWidth = 240
        shadow.position = CGPoint(x: 165.5, y: 139.0)  // offset down-right
        shadow.zRotation = 0
        shadow.xScale = 0.75
        shadow.yScale = 0.574
        shadow.blendMode = .multiply
        shadow.zPosition = 30  // below screens (40) and pet (50+)
        addChild(shadow)
        statusShadowLabel = shadow

        // Main label
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 38
        label.fontColor = SKColor(red: 0.12, green: 0.08, blue: 0.03, alpha: 0.45)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = 240
        label.position = CGPoint(x: 164.7, y: 140.0)
        label.zRotation = 0
        label.xScale = 0.75
        label.yScale = 0.574
        label.blendMode = .multiply
        label.zPosition = 31  // just above shadow, below screens (40) and pet (50+)
        addChild(label)
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
        let text: String
        if visible.isEmpty {
            text = ""
        } else {
            let r = visible.filter { $0.status == .running }.count
            let w = visible.filter { $0.status == .needsInput }.count
            let i = visible.filter { $0.status == .idle }.count
            let e = visible.filter { $0.status == .error }.count
            var lines: [String] = []
            if r > 0 { lines.append("\(r) working") }
            if w > 0 { lines.append("\(w) waiting") }
            if i > 0 { lines.append("\(i) idle") }
            if e > 0 { lines.append("\(e) error") }
            text = lines.joined(separator: "\n")
        }
        statusLabel?.text = text
        statusShadowLabel?.text = text
    }

    // MARK: - Mouse Interaction

    public override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)

        // Info overlay: check buttons first, dismiss only if click was outside
        if infoOverlay != nil {
            if handleOverlayClick(at: location) { return }
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
                // Clear all hover states before showing overlay
                screenNodes.forEach { $0.setHovered(false) }
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

        // Overlay hover: cursor + row highlight
        if let overlay = infoOverlay {
            let local = CGPoint(x: location.x - 160, y: location.y - 160)
            var overInteractive = false

            // Check close X button area
            if let closeY = overlay.userData?["closeY"] as? CGFloat,
               let panelW = overlay.userData?["panelW"] as? CGFloat {
                let closeArea = CGRect(x: panelW / 2 - 28, y: closeY - 10, width: 24, height: 24)
                if closeArea.contains(local) {
                    overInteractive = true
                }
            }

            // Check row areas for hover highlight
            var newHoveredRow = -1
            if let rows = overlay.userData?["rowAreas"] as? [[String: Any]] {
                for (i, row) in rows.enumerated() {
                    guard let x = row["x"] as? CGFloat,
                          let y = row["y"] as? CGFloat,
                          let w = row["w"] as? CGFloat,
                          let h = row["h"] as? CGFloat else { continue }
                    let area = CGRect(x: x, y: y, width: w, height: h)
                    if area.contains(local) {
                        newHoveredRow = i
                        overInteractive = true
                        break
                    }
                }
            }

            // Update row highlight if changed
            if newHoveredRow != hoveredRowIndex {
                // Reset previous
                if hoveredRowIndex >= 0, hoveredRowIndex < overlayRowNodes.count {
                    overlayRowNodes[hoveredRowIndex].fillColor = overlayRowBaseColors[hoveredRowIndex]
                }
                // Set new
                if newHoveredRow >= 0, newHoveredRow < overlayRowNodes.count {
                    overlayRowNodes[newHoveredRow].fillColor = overlayRowBaseColors[newHoveredRow]
                        .blended(withFraction: 0.3, of: SKColor(white: 0.4, alpha: 1.0)) ?? overlayRowBaseColors[newHoveredRow]
                }
                hoveredRowIndex = newHoveredRow
            }

            overInteractive ? NSCursor.pointingHand.set() : NSCursor.arrow.set()
            return
        }

        // Hover highlight on monitors
        for screen in screenNodes {
            screen.setHovered(screen.hitTest(scenePoint: location) && screen.session != nil)
        }

        // Cursor feedback: hand cursor over clickable elements
        let overClickable = screenNodes.contains { $0.hitTest(scenePoint: location) && $0.session != nil }
            || (husky?.hitTest(location) == true)
        NSCursor.current == NSCursor.pointingHand
            ? (overClickable ? () : NSCursor.arrow.set())
            : (overClickable ? NSCursor.pointingHand.set() : ())
    }

    public override func rightMouseDown(with event: NSEvent) {
        // Forward to the window's rightMouseDown which builds the context menu
        view?.window?.rightMouseDown(with: event)
    }

    // MARK: - Info Overlay (Fullscreen Session List)

    /// Show a fullscreen overlay listing ALL visible sessions as clickable rows.
    /// Click a row to jump to that session. X button to close.
    private func showInfoOverlay(for screen: ScreenNode) {
        dismissInfoOverlay()
        let visible = sessions.filter(\.isVisible)
            .sorted { priority($0.status) > priority($1.status) }
        guard !visible.isEmpty else { return }

        let overlay = SKNode()
        overlay.name = "info-overlay"
        overlay.position = CGPoint(x: 160, y: 160)

        // Dimmed backdrop (fullscreen)
        let backdrop = SKShapeNode(rectOf: CGSize(width: 320, height: 320))
        backdrop.fillColor = SKColor(white: 0, alpha: 0.6)
        backdrop.strokeColor = .clear
        overlay.addChild(backdrop)

        // Panel: nearly fullscreen with margin
        let panelW: CGFloat = 290
        let rowH: CGFloat = 48
        let headerH: CGFloat = 36
        let panelH = headerH + CGFloat(visible.count) * rowH + 12
        let maxH: CGFloat = 280
        let clampedH = min(panelH, maxH)

        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: clampedH), cornerRadius: 6)
        panel.fillColor = SKColor(red: 0.04, green: 0.03, blue: 0.05, alpha: 0.95)
        panel.strokeColor = SKColor(white: 0.3, alpha: 0.4)
        panel.lineWidth = 1
        panel.name = "panel"
        overlay.addChild(panel)

        // Close X button (top-right of panel)
        let closeX = SKLabelNode(fontNamed: "Menlo-Bold")
        closeX.text = "X"
        closeX.fontSize = 18
        closeX.fontColor = SKColor(white: 0.6, alpha: 0.9)
        closeX.verticalAlignmentMode = .center
        closeX.horizontalAlignmentMode = .center
        closeX.position = CGPoint(x: panelW / 2 - 20, y: clampedH / 2 - 18)
        closeX.name = "close-x"
        panel.addChild(closeX)

        // Title
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "Sessions"
        title.fontSize = 16
        title.fontColor = SKColor(white: 0.8, alpha: 0.9)
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: clampedH / 2 - 18)
        panel.addChild(title)

        // Session rows
        let startY = clampedH / 2 - headerH - rowH / 2
        var rowAreas: [(CGRect, String)] = []  // hit areas + session IDs
        overlayRowNodes = []
        overlayRowBaseColors = []
        hoveredRowIndex = -1

        for (i, session) in visible.prefix(6).enumerated() {
            let rowY = startY - CGFloat(i) * rowH
            let status = ScreenNode.ScreenStatus.from(session.status)

            // Row background (subtle, alternating)
            let rowBg = SKShapeNode(rectOf: CGSize(width: panelW - 16, height: rowH - 4), cornerRadius: 3)
            let baseColor = i % 2 == 0
                ? SKColor(white: 0.1, alpha: 0.5)
                : SKColor(white: 0.08, alpha: 0.3)
            rowBg.fillColor = baseColor
            rowBg.strokeColor = .clear
            rowBg.position = CGPoint(x: 0, y: rowY)
            panel.addChild(rowBg)
            overlayRowNodes.append(rowBg)
            overlayRowBaseColors.append(baseColor)

            // Status dot
            let dot = SKShapeNode(circleOfRadius: 5)
            dot.fillColor = status.color.withAlphaComponent(1.0)
            dot.strokeColor = .clear
            dot.position = CGPoint(x: -panelW / 2 + 22, y: rowY)
            panel.addChild(dot)

            // Session name
            let nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            nameLabel.text = session.displayName
            nameLabel.fontSize = 14
            nameLabel.fontColor = .white
            nameLabel.verticalAlignmentMode = .center
            nameLabel.horizontalAlignmentMode = .left
            nameLabel.position = CGPoint(x: -panelW / 2 + 36, y: rowY + 7)
            panel.addChild(nameLabel)

            // Status + CWD subtitle
            let sub = SKLabelNode(fontNamed: "Menlo")
            let cwdSuffix: String
            if let cwd = session.cwd {
                let parts = cwd.split(separator: "/")
                cwdSuffix = " - " + (parts.count >= 2 ? parts.suffix(2).joined(separator: "/") : String(parts.last ?? ""))
            } else {
                cwdSuffix = ""
            }
            sub.text = "\(session.status.rawValue)\(cwdSuffix)"
            sub.fontSize = 10
            sub.fontColor = SKColor(white: 0.5, alpha: 0.8)
            sub.verticalAlignmentMode = .center
            sub.horizontalAlignmentMode = .left
            sub.position = CGPoint(x: -panelW / 2 + 36, y: rowY - 9)
            panel.addChild(sub)

            // Store hit area (in overlay-local coords, panel is at 0,0 in overlay)
            let hitRect = CGRect(
                x: -panelW / 2 + 8,
                y: rowY - rowH / 2,
                width: panelW - 16,
                height: rowH
            )
            rowAreas.append((hitRect, session.id))
        }

        // Animate in
        overlay.setScale(0.5)
        overlay.alpha = 0
        overlay.run(SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.12),
            SKAction.fadeIn(withDuration: 0.12)
        ]))

        overlayLayer.addChild(overlay)
        infoOverlay = overlay

        // Store row hit areas for click handling
        overlay.userData = NSMutableDictionary()
        overlay.userData?["rowAreas"] = rowAreas.map { ["x": $0.0.origin.x, "y": $0.0.origin.y, "w": $0.0.width, "h": $0.0.height, "id": $0.1] }
        overlay.userData?["closeY"] = clampedH / 2 - 14
        overlay.userData?["panelW"] = panelW
        overlay.userData?["panelH"] = clampedH
    }

    private func dismissInfoOverlay() {
        guard let overlay = infoOverlay else { return }
        overlay.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 0.5, duration: 0.08),
                SKAction.fadeOut(withDuration: 0.08)
            ]),
            SKAction.removeFromParent()
        ]))
        infoOverlay = nil
        overlayRowNodes = []
        overlayRowBaseColors = []
        hoveredRowIndex = -1
    }

    private func handleOverlayClick(at location: CGPoint) -> Bool {
        guard let overlay = infoOverlay else { return false }

        // Convert to overlay-local coords (overlay centered at 160,160)
        let local = CGPoint(x: location.x - 160, y: location.y - 160)

        // Close X button (top-right area)
        if let closeY = overlay.userData?["closeY"] as? CGFloat,
           let panelW = overlay.userData?["panelW"] as? CGFloat {
            let closeArea = CGRect(x: panelW / 2 - 28, y: closeY - 10, width: 24, height: 20)
            if closeArea.contains(local) {
                dismissInfoOverlay()
                return true
            }
        }

        // Session row clicks
        if let rows = overlay.userData?["rowAreas"] as? [[String: Any]] {
            for row in rows {
                guard let x = row["x"] as? CGFloat,
                      let y = row["y"] as? CGFloat,
                      let w = row["w"] as? CGFloat,
                      let h = row["h"] as? CGFloat,
                      let sessionId = row["id"] as? String else { continue }
                let area = CGRect(x: x, y: y, width: w, height: h)
                if area.contains(local) {
                    if let session = sessions.first(where: { $0.id == sessionId }) {
                        WindowJumper.shared.jump(to: session)
                    }
                    dismissInfoOverlay()
                    return true
                }
            }
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
            self?.resolvePermission(sessionId: event.sessionId)
        }

        // Auto-allow after 5 minutes
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
            guard self?.pendingPermissions[event.sessionId] != nil else { return }
            respond(HookDecision(allow: true, reason: "auto-allowed: user did not respond in 5 minutes"))
            self?.pendingPermissions.removeValue(forKey: event.sessionId)
            screen.removePermissionBubble()
            self?.resolvePermission(sessionId: event.sessionId)
        }
    }

    /// Called after any permission decision (allow or deny).
    /// Writes the session back to "active" so the UI stops showing "waiting"
    /// even if no follow-up hook event arrives (blocked tools don't fire PostToolUse).
    private func resolvePermission(sessionId: String) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let writer = SessionWriter()
            try? writer.report(sessionId: sessionId, event: "active")
            DispatchQueue.main.async { [weak self] in
                self?.refreshSessions()
            }
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
