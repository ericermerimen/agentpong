import SpriteKit
import Shared

/// A single monitor screen overlay showing one session's status.
///
/// Each monitor in the room gets its own ScreenNode. The node overlays
/// a perspective-correct trapezoidal shape with status color, glow, and text.
class ScreenNode: SKNode {

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

    private let screenBg: SKShapeNode
    private let glowNode: SKShapeNode
    private let statusLabel: SKLabelNode
    private let detailLabel: SKLabelNode
    private var permissionBubble: SKNode?
    private var permissionCallback: ((Bool) -> Void)?

    private(set) var status: ScreenStatus = .off
    private(set) var session: Session?

    private let localTopLeft: CGPoint
    private let localTopRight: CGPoint
    private let localBottomLeft: CGPoint
    private let localBottomRight: CGPoint
    private let hitPath: CGPath
    private let screenHeight: CGFloat
    private let isSmall: Bool  // left/right monitors are small, fewer text

    var hasPermissionBubble: Bool { permissionBubble != nil }

    /// Initialize with 4 corner points in scene coordinates.
    init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) {
        let centerX = (topLeft.x + topRight.x + bottomLeft.x + bottomRight.x) / 4
        let centerY = (topLeft.y + topRight.y + bottomLeft.y + bottomRight.y) / 4

        localTopLeft = CGPoint(x: topLeft.x - centerX, y: topLeft.y - centerY)
        localTopRight = CGPoint(x: topRight.x - centerX, y: topRight.y - centerY)
        localBottomLeft = CGPoint(x: bottomLeft.x - centerX, y: bottomLeft.y - centerY)
        localBottomRight = CGPoint(x: bottomRight.x - centerX, y: bottomRight.y - centerY)
        screenHeight = topLeft.y - bottomLeft.y

        // Detect if small monitor (side screens are < 20 scene pts wide)
        let width = topRight.x - topLeft.x
        isSmall = width < 20

        let path = CGMutablePath()
        path.move(to: localTopLeft)
        path.addLine(to: localTopRight)
        path.addLine(to: localBottomRight)
        path.addLine(to: localBottomLeft)
        path.closeSubpath()
        hitPath = path

        screenBg = SKShapeNode(path: path)
        screenBg.fillColor = ScreenStatus.off.color
        screenBg.strokeColor = .clear
        screenBg.lineWidth = 0

        // Glow behind screen
        let glowScale: CGFloat = 1.6
        let glowPath = CGMutablePath()
        glowPath.move(to: CGPoint(x: localTopLeft.x * glowScale, y: localTopLeft.y * glowScale))
        glowPath.addLine(to: CGPoint(x: localTopRight.x * glowScale, y: localTopRight.y * glowScale))
        glowPath.addLine(to: CGPoint(x: localBottomRight.x * glowScale, y: (localBottomRight.y - 8) * glowScale))
        glowPath.addLine(to: CGPoint(x: localBottomLeft.x * glowScale, y: (localBottomLeft.y - 8) * glowScale))
        glowPath.closeSubpath()

        glowNode = SKShapeNode(path: glowPath)
        glowNode.fillColor = .clear
        glowNode.strokeColor = .clear
        glowNode.alpha = 0
        glowNode.zPosition = -1

        statusLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        statusLabel.fontSize = isSmall ? 4 : 6
        statusLabel.fontColor = SKColor(white: 0.9, alpha: 0.9)
        statusLabel.verticalAlignmentMode = .center
        statusLabel.position = CGPoint(x: 0, y: isSmall ? 0 : 2)

        detailLabel = SKLabelNode(fontNamed: "Menlo")
        detailLabel.fontSize = isSmall ? 3 : 4.5
        detailLabel.fontColor = SKColor(white: 0.7, alpha: 0.8)
        detailLabel.verticalAlignmentMode = .center
        detailLabel.position = CGPoint(x: 0, y: isSmall ? -4 : -5)

        super.init()

        self.position = CGPoint(x: centerX, y: centerY)
        self.name = "screen-node"

        addChild(glowNode)
        addChild(screenBg)
        addChild(statusLabel)
        if !isSmall { addChild(detailLabel) }
    }

    /// Convenience init from ZoneManager.MonitorCorners.
    convenience init(corners: ZoneManager.MonitorCorners) {
        self.init(
            topLeft: corners.topLeft,
            topRight: corners.topRight,
            bottomLeft: corners.bottomLeft,
            bottomRight: corners.bottomRight
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Update

    /// Assign a session to this monitor (or nil to turn it off).
    func assignSession(_ newSession: Session?) {
        let oldStatus = status
        session = newSession

        if let s = newSession {
            status = screenStatus(for: s)
        } else {
            status = .off
        }

        updateVisuals()

        if status != oldStatus {
            animateStatusChange(to: status)
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
        screenBg.fillColor = status.color

        glowNode.fillColor = status.glowColor
        glowNode.alpha = status == .off ? 0 : 1

        if let s = session {
            if isSmall {
                // Small monitor: just show abbreviated status
                statusLabel.text = String(s.displayName.prefix(6))
            } else {
                statusLabel.text = s.displayName
                detailLabel.text = s.status.rawValue
            }
        } else {
            statusLabel.text = ""
            detailLabel.text = ""
        }

        // Pulsing for urgent states
        screenBg.removeAction(forKey: "pulse")
        if status == .error {
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.7, duration: 0.4),
                SKAction.fadeAlpha(to: 1.0, duration: 0.4),
            ])
            screenBg.run(SKAction.repeatForever(pulse), withKey: "pulse")
        } else if status == .needsInput {
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.85, duration: 0.6),
                SKAction.fadeAlpha(to: 1.0, duration: 0.6),
            ])
            screenBg.run(SKAction.repeatForever(pulse), withKey: "pulse")
        } else {
            screenBg.alpha = 1.0
        }
    }

    private func animateStatusChange(to newStatus: ScreenStatus) {
        guard newStatus != .off else { return }
        let flashPath = CGMutablePath()
        flashPath.move(to: localTopLeft)
        flashPath.addLine(to: localTopRight)
        flashPath.addLine(to: localBottomRight)
        flashPath.addLine(to: localBottomLeft)
        flashPath.closeSubpath()

        let flash = SKShapeNode(path: flashPath)
        flash.fillColor = newStatus.color.withAlphaComponent(0.9)
        flash.strokeColor = .clear
        flash.zPosition = 10
        addChild(flash)

        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Hit Testing

    func hitTest(scenePoint: CGPoint) -> Bool {
        guard let parentScene = scene else { return false }
        let local = convert(scenePoint, from: parentScene)
        let margin: CGFloat = 4
        let expandedPath = CGMutablePath()
        expandedPath.move(to: CGPoint(x: localTopLeft.x - margin, y: localTopLeft.y + margin))
        expandedPath.addLine(to: CGPoint(x: localTopRight.x + margin, y: localTopRight.y + margin))
        expandedPath.addLine(to: CGPoint(x: localBottomRight.x + margin, y: localBottomRight.y - margin))
        expandedPath.addLine(to: CGPoint(x: localBottomLeft.x - margin, y: localBottomLeft.y - margin))
        expandedPath.closeSubpath()
        return expandedPath.contains(local)
    }

    // MARK: - Permission Bubbles

    func showPermissionBubble(text: String, onDecision: @escaping (Bool) -> Void) {
        removePermissionBubble()

        let bubble = SKNode()
        bubble.name = "permission-bubble"
        bubble.position = CGPoint(x: 0, y: screenHeight / 2 + 20)
        bubble.zPosition = 100

        let bgW: CGFloat = 90
        let bgH: CGFloat = 28
        let bg = SKShapeNode(rectOf: CGSize(width: bgW, height: bgH), cornerRadius: 4)
        bg.fillColor = SKColor(white: 0.06, alpha: 0.95)
        bg.strokeColor = SKColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 0.7)
        bg.lineWidth = 1
        bubble.addChild(bg)

        let label = SKLabelNode(fontNamed: "Menlo")
        label.text = String(text.prefix(35))
        label.fontSize = 4.5
        label.fontColor = SKColor(white: 0.9, alpha: 0.9)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 5)
        bubble.addChild(label)

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

    func handlePermissionClick(scenePoint: CGPoint) -> Bool {
        guard let bubble = permissionBubble, let parentScene = scene else { return false }

        let localPoint = convert(scenePoint, from: parentScene)
        let bubbleY = bubble.position.y

        let allowArea = CGRect(x: -36, y: bubbleY - 14, width: 32, height: 12)
        if allowArea.contains(localPoint) {
            permissionCallback?(true)
            removePermissionBubble()
            return true
        }

        let denyArea = CGRect(x: 4, y: bubbleY - 14, width: 32, height: 12)
        if denyArea.contains(localPoint) {
            permissionCallback?(false)
            removePermissionBubble()
            return true
        }

        return false
    }
}
