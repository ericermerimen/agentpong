import SpriteKit
import Shared

/// The main SpriteKit scene -- pixel art office composed from individual sprites.
public class OfficeScene: SKScene {

    // MARK: - Properties

    private var sessions: [Session] = []
    private var characters: [String: CharacterNode] = [:]
    private let sessionReader = SessionReader()
    private let zoneManager = ZoneManager()
    private let assets = SpriteAssetLoader.shared

    private var lastPollTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private let pollInterval: TimeInterval = 5.0

    // Hook server for real-time events
    private struct PendingPermission {
        let event: HookEvent
        let respond: (HookDecision) -> Void
    }
    private var pendingPermissions: [String: PendingPermission] = [:]

    // Layers
    private let floorLayer = SKNode()       // z: -100
    private let furnitureLayer = SKNode()    // z: 0-40 (depth sorted)
    private let effectsLayer = SKNode()      // z: 45
    private let characterLayer = SKNode()    // z: 50+ (depth sorted)
    private let bubbleLayer = SKNode()       // z: 150
    private let uiLayer = SKNode()           // z: 200

    private var statusLabel: SKLabelNode?
    private var mascot: MascotNode?

    public var onSessionsUpdated: (([Session]) -> Void)?
    public var currentSessions: [Session] { sessions }

    public var hookServer: HookServer? {
        didSet { subscribeToHookEvents() }
    }

    // MARK: - Lifecycle

    public override func didMove(to view: SKView) {
        size = CGSize(width: 320, height: 320)
        scaleMode = .aspectFit
        backgroundColor = SKColor(red: 0.04, green: 0.03, blue: 0.02, alpha: 1.0)  // Match room border dark tone

        floorLayer.zPosition = -100
        furnitureLayer.zPosition = 0
        effectsLayer.zPosition = 45
        characterLayer.zPosition = 50
        bubbleLayer.zPosition = 150
        uiLayer.zPosition = 200

        addChild(floorLayer)
        addChild(furnitureLayer)
        addChild(effectsLayer)
        addChild(characterLayer)
        addChild(bubbleLayer)
        addChild(uiLayer)

        setupFloor()
        setupMascot()
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

        for (_, character) in characters {
            character.update(deltaTime: dt)
            character.zPosition = zoneManager.zPosition(for: character.position.y)
        }

        mascot?.update(deltaTime: dt)
        mascot?.zPosition = zoneManager.zPosition(for: mascot?.position.y ?? 0)
    }

    // MARK: - Floor

    private func setupFloor() {
        // Check for a custom background image first
        if loadBackgroundImage() { return }

        // Dark wood floor pattern
        let floorColor1 = SKColor(red: 0.12, green: 0.09, blue: 0.07, alpha: 1.0)
        let floorColor2 = SKColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 1.0)
        let tileSize: CGFloat = 16

        for x in stride(from: CGFloat(0), to: 320, by: tileSize) {
            for y in stride(from: CGFloat(0), to: 320, by: tileSize) {
                let isEven = (Int(x / tileSize) + Int(y / tileSize)) % 2 == 0
                let tile = SKSpriteNode(color: isEven ? floorColor1 : floorColor2, size: CGSize(width: tileSize, height: tileSize))
                tile.position = CGPoint(x: x + tileSize / 2, y: y + tileSize / 2)
                floorLayer.addChild(tile)
            }
        }

        // Walls (top and sides)
        let wallColor = SKColor(red: 0.06, green: 0.05, blue: 0.04, alpha: 1.0)
        let topWall = SKSpriteNode(color: wallColor, size: CGSize(width: 320, height: 40))
        topWall.position = CGPoint(x: 160, y: 300)
        floorLayer.addChild(topWall)

        let leftWall = SKSpriteNode(color: wallColor, size: CGSize(width: 20, height: 320))
        leftWall.position = CGPoint(x: 10, y: 160)
        floorLayer.addChild(leftWall)

        let rightWall = SKSpriteNode(color: wallColor, size: CGSize(width: 20, height: 320))
        rightWall.position = CGPoint(x: 310, y: 160)
        floorLayer.addChild(rightWall)
    }

    private func loadBackgroundImage() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser

        // 3-layer system: background -> characters -> foreground
        // Try split layers first, fall back to single default.png
        let bgPath = home.appendingPathComponent(".agentpong/themes/background.png")
        let fgPath = home.appendingPathComponent(".agentpong/themes/foreground.png")

        if FileManager.default.fileExists(atPath: bgPath.path),
           FileManager.default.fileExists(atPath: fgPath.path),
           let bgImage = NSImage(contentsOfFile: bgPath.path),
           let fgImage = NSImage(contentsOfFile: fgPath.path) {

            // Background layer (floor, walls, desk backs) -- behind everything
            let bgTex = SKTexture(image: bgImage)
            bgTex.filteringMode = .nearest
            let bg = SKSpriteNode(texture: bgTex, size: CGSize(width: 320, height: 320))
            bg.position = CGPoint(x: 160, y: 160)
            bg.zPosition = -1000
            addChild(bg)

            // Foreground layer (desk fronts, chairs, sofa) -- in front of characters
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
                floorLayer.addChild(bg)
                return true
            }
        }
        return false
    }

    // MARK: - Furniture Overlay (depth occlusion)

    private func loadFurnitureOverlay() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let path = home.appendingPathComponent(".agentpong/themes/overlay.png")
        guard FileManager.default.fileExists(atPath: path.path),
              let image = NSImage(contentsOfFile: path.path) else { return }

        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        let overlay = SKSpriteNode(texture: texture, size: CGSize(width: 320, height: 320))
        overlay.position = CGPoint(x: 160, y: 160)
        overlay.zPosition = 200  // Above characters, below UI
        addChild(overlay)
    }

    // MARK: - Mascot

    private func setupMascot() {
        // Cat roams the open floor between desks and sofa
        let roamZone = zoneManager.walkableArea
        let startPos = zoneManager.floorCenter
        let cat = MascotNode(startPosition: startPos, wanderZone: roamZone)
        characterLayer.addChild(cat)
        mascot = cat
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
        let oldIds = Set(sessions.filter(\.isVisible).map(\.id))
        let newIds = Set(newSessions.filter(\.isVisible).map(\.id))

        for id in oldIds.subtracting(newIds) { departCharacter(sessionId: id) }

        for session in newSessions where session.isVisible && !oldIds.contains(session.id) {
            arriveCharacter(session: session)
        }

        for session in newSessions where session.isVisible {
            if let old = sessions.first(where: { $0.id == session.id }), old.zone != session.zone {
                moveCharacterToZone(session: session)
            }
            updateCharacterBubble(session: session)
        }

        sessions = newSessions
        updateStatusLabel()
        onSessionsUpdated?(sessions)
    }

    private func arriveCharacter(session: Session) {
        let character = CharacterNode(
            sessionId: session.id,
            startPosition: zoneManager.doorPosition,
            size: zoneManager.characterSize
        )
        character.setName(session.displayName)
        characterLayer.addChild(character)
        characters[session.id] = character

        let target = zoneManager.targetPosition(zone: session.zone, sessionId: session.id)
        character.walkTo(target: target, speed: 60) { [weak self] in
            self?.applyZoneState(character: character, session: session)
            // Check for queued permission request that arrived before character walk-in
            if let pending = self?.pendingPermissions[session.id] {
                self?.showPermissionBubbleOnCharacter(character, event: pending.event, respond: pending.respond)
            }
        }
    }

    private func departCharacter(sessionId: String) {
        guard let character = characters[sessionId] else { return }
        character.walkTo(target: zoneManager.doorPosition, speed: 70) { [weak self, weak character] in
            character?.fadeOutImmediate { self?.characters.removeValue(forKey: sessionId) }
        }
    }

    private func moveCharacterToZone(session: Session) {
        guard let character = characters[session.id] else { return }
        let target = zoneManager.targetPosition(zone: session.zone, sessionId: session.id)
        character.walkTo(target: target, speed: 60) { [weak self] in
            self?.applyZoneState(character: character, session: session)
        }
    }

    private func applyZoneState(character: CharacterNode, session: Session) {
        switch session.zone {
        case .desk:
            let deskIdx = zoneManager.deskForSession(session.id)
            let facing = zoneManager.deskFacingDirections[deskIdx]
            character.startWorking(facingDirection: facing)
        case .lounge:
            character.startIdling()
            if session.status == .needsInput {
                character.showBubble(text: "?", color: SKColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1.0))
            } else if session.isFreshIdle == true {
                character.showBubble(text: "done", color: SKColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0))
            }
        case .debugStation:
            character.startAlerting()
            character.showBubble(text: "!", color: SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0))
        case .door: break
        }
    }

    private func updateCharacterBubble(session: Session) {
        guard let character = characters[session.id] else { return }
        // Don't clobber an active permission bubble with a status bubble
        if character.hasPermissionBubble { return }
        switch session.status {
        case .needsInput: character.showBubble(text: "?", color: SKColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1.0))
        case .error: character.showBubble(text: "!", color: SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0))
        case .idle where session.isFreshIdle == true: character.showBubble(text: "done", color: SKColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0))
        default: character.removeBubble()
        }
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

        // Check permission bubbles first (highest priority)
        for (_, character) in characters {
            if character.handleClick(at: location) {
                return
            }
        }

        // Click on cat to scare it
        if let cat = mascot, cat.hitTest(location) {
            cat.scare()
        }
    }

    public override func mouseMoved(with event: NSEvent) {
        // Hover tooltips handled by AppKit popover in future
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
        // Map Claude Code hook event names to SessionWriter event names
        // SessionWriter expects: "start", "stop", "active", "idle", "error", "needsInput", "notify"
        let writerEvent: String
        switch event.hookEventName {
        case "SessionStart": writerEvent = "start"
        case "SessionEnd", "Stop": writerEvent = "stop"
        case "PreToolUse", "PostToolUse": writerEvent = "active"
        case "Notification": writerEvent = "notify"
        default: writerEvent = "active"
        }

        // Do file I/O on background queue, then refresh on main
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

        // Store the pending permission
        pendingPermissions[sessionId] = PendingPermission(
            event: event,
            respond: respond
        )

        // Force refresh to show the character
        refreshSessions()

        // Show interactive permission bubble on the character
        if let character = characters[sessionId] {
            showPermissionBubbleOnCharacter(character, event: event, respond: respond)
        }
        // If character hasn't arrived yet (first event is PreToolUse),
        // the pending permission is stored and checked in arriveCharacter's completion.
    }

    private func showPermissionBubbleOnCharacter(_ character: CharacterNode, event: HookEvent, respond: @escaping (HookDecision) -> Void) {
        let toolDesc = "\(event.toolName ?? "tool"): \(truncate(event.toolInputDescription, to: 30))"
        character.showPermissionBubble(text: toolDesc) { [weak self] allowed in
            respond(HookDecision(allow: allowed))
            self?.pendingPermissions.removeValue(forKey: event.sessionId)
            character.removeBubble()
        }

        // Server-side timeout: auto-allow after 5 minutes to prevent connection leak
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
            guard self?.pendingPermissions[event.sessionId] != nil else { return }
            respond(HookDecision(allow: true, reason: "auto-allowed: user did not respond in 5 minutes"))
            self?.pendingPermissions.removeValue(forKey: event.sessionId)
            character.removeBubble()
        }
    }

    private func truncate(_ s: String, to length: Int) -> String {
        s.count > length ? String(s.prefix(length)) + "..." : s
    }
}
