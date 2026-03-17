import SpriteKit
import Shared

/// Monitor screen overlay that shows session status with colored glow.
///
/// The background image has a single dark monitor. This node overlays on top
/// of it with colored sections for each status category:
///
///   ┌─────────────────────────────┐
///   │  [green 3] [yellow 1] [red] │  <- status indicators inside monitor
///   │           [idle 2]          │
///   └─────────────────────────────┘
///
/// Priority: red > yellow > green > idle.
/// The monitor's overall glow color matches the highest-priority active status.
/// Click to jump to session or approve permissions.
class ScreenNode: SKNode {

    /// Session groups by status category.
    struct StatusGroup {
        let status: ScreenStatus
        var sessions: [Session]
    }

    enum ScreenStatus: Int, Comparable {
        case off = 0
        case idle = 1
        case running = 2
        case needsInput = 3
        case error = 4

        static func < (lhs: ScreenStatus, rhs: ScreenStatus) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var color: SKColor {
            switch self {
            case .off:        return SKColor(white: 0.05, alpha: 0.3)
            case .idle:       return SKColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 0.5)
            case .running:    return SKColor(red: 0.1, green: 0.6, blue: 0.2, alpha: 0.7)
            case .needsInput: return SKColor(red: 0.85, green: 0.65, blue: 0.1, alpha: 0.8)
            case .error:      return SKColor(red: 0.8, green: 0.15, blue: 0.15, alpha: 0.8)
            }
        }

        var glowColor: SKColor {
            switch self {
            case .off:        return .clear
            case .idle:       return SKColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.15)
            case .running:    return SKColor(red: 0.1, green: 0.5, blue: 0.15, alpha: 0.25)
            case .needsInput: return SKColor(red: 0.6, green: 0.5, blue: 0.05, alpha: 0.3)
            case .error:      return SKColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 0.35)
            }
        }
    }

    private let screenBg: SKSpriteNode
    private let glowNode: SKSpriteNode
    private let statusLabel: SKLabelNode
    private let detailLabel: SKLabelNode
    private var permissionBubble: SKNode?
    private var permissionCallback: ((Bool) -> Void)?

    private(set) var highestStatus: ScreenStatus = .off
    private(set) var statusGroups: [ScreenStatus: [Session]] = [:]
    private let screenSize: CGSize

    /// Whether a permission bubble is currently showing.
    var hasPermissionBubble: Bool {
        permissionBubble != nil
    }

    init(center: CGPoint, size: CGSize) {
        self.screenSize = size

        // Semi-transparent overlay on the monitor area
        screenBg = SKSpriteNode(color: ScreenStatus.off.color, size: size)
        screenBg.position = .zero

        // Glow effect (larger, blurred behind the screen)
        let glowSize = CGSize(width: size.width * 1.8, height: size.height * 2.0)
        glowNode = SKSpriteNode(color: .clear, size: glowSize)
        glowNode.position = CGPoint(x: 0, y: -size.height * 0.3)
        glowNode.alpha = 0
        glowNode.zPosition = -1

        // Status summary text (e.g., "3 running")
        statusLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        statusLabel.fontSize = 6
        statusLabel.fontColor = SKColor(white: 0.9, alpha: 0.9)
        statusLabel.verticalAlignmentMode = .center
        statusLabel.position = CGPoint(x: 0, y: 2)

        // Detail text below (e.g., "1 waiting | 1 error")
        detailLabel = SKLabelNode(fontNamed: "Menlo")
        detailLabel.fontSize = 4.5
        detailLabel.fontColor = SKColor(white: 0.7, alpha: 0.8)
        detailLabel.verticalAlignmentMode = .center
        detailLabel.position = CGPoint(x: 0, y: -5)

        super.init()

        self.position = center
        self.name = "screen-node"

        addChild(glowNode)
        addChild(screenBg)
        addChild(statusLabel)
        addChild(detailLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Update

    /// Update screen state from current sessions.
    func updateFromSessions(_ sessions: [Session]) {
        // Group sessions by screen status
        var groups: [ScreenStatus: [Session]] = [:]
        for session in sessions where session.isVisible {
            let status = screenStatus(for: session)
            groups[status, default: []].append(session)
        }
        statusGroups = groups

        // Find highest priority active status
        let oldStatus = highestStatus
        highestStatus = groups.keys.max() ?? .off

        updateVisuals()

        // Animate transition if status changed
        if highestStatus != oldStatus {
            animateStatusChange(from: oldStatus, to: highestStatus)
        }
    }

    private func screenStatus(for session: Session) -> ScreenStatus {
        switch session.status {
        case .running:    return .running
        case .needsInput: return .needsInput
        case .error:      return .error
        case .idle:       return .idle
        case .done, .unavailable: return .off
        }
    }

    private func updateVisuals() {
        // Screen background color
        screenBg.color = highestStatus.color

        // Glow
        glowNode.color = highestStatus.glowColor
        glowNode.alpha = highestStatus == .off ? 0 : 1

        // Build status text
        let running = statusGroups[.running]?.count ?? 0
        let waiting = statusGroups[.needsInput]?.count ?? 0
        let errors = statusGroups[.error]?.count ?? 0
        let idle = statusGroups[.idle]?.count ?? 0
        let total = running + waiting + errors + idle

        if total == 0 {
            statusLabel.text = ""
            detailLabel.text = ""
        } else {
            // Main label: highest priority status
            switch highestStatus {
            case .error:      statusLabel.text = "\(errors) error\(errors > 1 ? "s" : "")"
            case .needsInput: statusLabel.text = "\(waiting) waiting"
            case .running:    statusLabel.text = "\(running) running"
            case .idle:       statusLabel.text = "\(idle) idle"
            case .off:        statusLabel.text = ""
            }

            // Detail line: other statuses
            var parts: [String] = []
            if running > 0 && highestStatus != .running { parts.append("\(running) run") }
            if waiting > 0 && highestStatus != .needsInput { parts.append("\(waiting) wait") }
            if errors > 0 && highestStatus != .error { parts.append("\(errors) err") }
            if idle > 0 && highestStatus != .idle { parts.append("\(idle) idle") }
            detailLabel.text = parts.joined(separator: " | ")
        }

        // Pulsing for urgent states
        removeAction(forKey: "pulse")
        if highestStatus == .error {
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.7, duration: 0.4),
                SKAction.fadeAlpha(to: 1.0, duration: 0.4),
            ])
            screenBg.run(SKAction.repeatForever(pulse), withKey: "pulse")
        } else if highestStatus == .needsInput {
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.85, duration: 0.6),
                SKAction.fadeAlpha(to: 1.0, duration: 0.6),
            ])
            screenBg.run(SKAction.repeatForever(pulse), withKey: "pulse")
        } else {
            screenBg.removeAction(forKey: "pulse")
            screenBg.alpha = 1.0
        }
    }

    private func animateStatusChange(from oldStatus: ScreenStatus, to newStatus: ScreenStatus) {
        // Brief flash on status change
        let flash = SKSpriteNode(color: newStatus.color.withAlphaComponent(0.9), size: screenSize)
        flash.position = .zero
        flash.zPosition = 10
        addChild(flash)

        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Click Handling

    /// Check if a scene point hits this screen. Returns true if consumed.
    func hitTest(scenePoint: CGPoint) -> Bool {
        let local = convert(scenePoint, from: scene!)
        let hitRect = CGRect(
            x: -screenSize.width / 2 - 4,
            y: -screenSize.height / 2 - 4,
            width: screenSize.width + 8,
            height: screenSize.height + 8
        )
        return hitRect.contains(local)
    }

    /// Handle a click on this screen. Returns the sessions in the highest-priority category.
    func sessionsForClick() -> [Session] {
        return statusGroups[highestStatus] ?? []
    }

    // MARK: - Permission Bubbles

    /// Show an interactive permission bubble above the screen.
    func showPermissionBubble(text: String, onDecision: @escaping (Bool) -> Void) {
        removePermissionBubble()

        let bubble = SKNode()
        bubble.name = "permission-bubble"
        bubble.position = CGPoint(x: 0, y: screenSize.height / 2 + 20)
        bubble.zPosition = 100

        // Background
        let bgW: CGFloat = 90
        let bgH: CGFloat = 28
        let bg = SKShapeNode(rectOf: CGSize(width: bgW, height: bgH), cornerRadius: 4)
        bg.fillColor = SKColor(white: 0.06, alpha: 0.95)
        bg.strokeColor = SKColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 0.7)
        bg.lineWidth = 1
        bubble.addChild(bg)

        // Tool description
        let label = SKLabelNode(fontNamed: "Menlo")
        label.text = String(text.prefix(35))
        label.fontSize = 4.5
        label.fontColor = SKColor(white: 0.9, alpha: 0.9)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 5)
        bubble.addChild(label)

        // Allow button
        let allowBtn = SKShapeNode(rectOf: CGSize(width: 32, height: 10), cornerRadius: 2)
        allowBtn.fillColor = SKColor(red: 0.15, green: 0.5, blue: 0.2, alpha: 1.0)
        allowBtn.strokeColor = .clear
        allowBtn.position = CGPoint(x: -20, y: -7)
        allowBtn.name = "allow-btn"
        bubble.addChild(allowBtn)

        let allowLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        allowLabel.text = "Allow"
        allowLabel.fontSize = 5
        allowLabel.fontColor = .white
        allowLabel.verticalAlignmentMode = .center
        allowLabel.position = CGPoint(x: -20, y: -7)
        bubble.addChild(allowLabel)

        // Deny button
        let denyBtn = SKShapeNode(rectOf: CGSize(width: 32, height: 10), cornerRadius: 2)
        denyBtn.fillColor = SKColor(red: 0.5, green: 0.15, blue: 0.15, alpha: 1.0)
        denyBtn.strokeColor = .clear
        denyBtn.position = CGPoint(x: 20, y: -7)
        denyBtn.name = "deny-btn"
        bubble.addChild(denyBtn)

        let denyLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        denyLabel.text = "Deny"
        denyLabel.fontSize = 5
        denyLabel.fontColor = .white
        denyLabel.verticalAlignmentMode = .center
        denyLabel.position = CGPoint(x: 20, y: -7)
        bubble.addChild(denyLabel)

        // Pulse attention
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5),
        ])
        bubble.run(SKAction.repeatForever(pulse))

        addChild(bubble)
        permissionBubble = bubble
        permissionCallback = onDecision
    }

    func removePermissionBubble() {
        permissionBubble?.removeFromParent()
        permissionBubble = nil
        permissionCallback = nil
    }

    /// Handle click on permission bubble buttons. Returns true if consumed.
    func handlePermissionClick(scenePoint: CGPoint) -> Bool {
        guard let bubble = permissionBubble, let parentScene = scene else { return false }

        let localPoint = convert(scenePoint, from: parentScene)
        let bubbleY = bubble.position.y

        // Allow button hit area
        let allowArea = CGRect(x: -36, y: bubbleY - 14, width: 32, height: 12)
        if allowArea.contains(localPoint) {
            permissionCallback?(true)
            removePermissionBubble()
            return true
        }

        // Deny button hit area
        let denyArea = CGRect(x: 4, y: bubbleY - 14, width: 32, height: 12)
        if denyArea.contains(localPoint) {
            permissionCallback?(false)
            removePermissionBubble()
            return true
        }

        return false
    }

    // MARK: - Tooltip

    /// Build tooltip text for hover display.
    func tooltipText() -> String? {
        let allSessions = statusGroups.values.flatMap { $0 }
        guard !allSessions.isEmpty else { return nil }

        if allSessions.count == 1, let s = allSessions.first {
            return "\(s.displayName) (\(s.status.rawValue))"
        }

        return allSessions.prefix(4).map { "\($0.displayName): \($0.status.rawValue)" }.joined(separator: "\n")
    }
}
