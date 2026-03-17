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

        static func from(_ sessionStatus: SessionStatus) -> ScreenStatus {
            switch sessionStatus {
            case .running:    return .running
            case .needsInput: return .needsInput
            case .error:      return .error
            case .idle:       return .idle
            case .done, .unavailable: return .off
            }
        }

        var color: SKColor {
            switch self {
            case .off:        return SKColor(white: 0.05, alpha: 0.3)
            case .idle:       return SKColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 0.5)
            case .running:    return SKColor(red: 0.1, green: 0.6, blue: 0.2, alpha: 0.9)
            case .needsInput: return SKColor(red: 0.85, green: 0.65, blue: 0.1, alpha: 0.92)
            case .error:      return SKColor(red: 0.8, green: 0.15, blue: 0.15, alpha: 0.92)
            }
        }

        var glowColor: SKColor {
            switch self {
            case .off:        return .clear
            case .idle:       return SKColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.3)
            case .running:    return SKColor(red: 0.1, green: 0.5, blue: 0.15, alpha: 0.45)
            case .needsInput: return SKColor(red: 0.6, green: 0.5, blue: 0.05, alpha: 0.55)
            case .error:      return SKColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 0.6)
            }
        }
    }

    private let screenBg: SKShapeNode
    private let glowNode: SKShapeNode
    private let statusLabel: SKLabelNode
    private let detailLabel: SKLabelNode
    private let cropNode: SKCropNode
    private var contentSprite: SKSpriteNode?
    private var permissionBubble: SKNode?
    private var permissionCallback: ((Bool) -> Void)?
    private var hoverOverlay: SKShapeNode?

    private(set) var status: ScreenStatus = .off
    private(set) var sessions: [Session] = []
    /// First session in the category (for popover display).
    var session: Session? { sessions.first }

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

        // Glow behind screen (very subtle, barely beyond edges)
        let glowScale: CGFloat = 1.08
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
        statusLabel.fontSize = isSmall ? 8 : 7
        statusLabel.fontColor = SKColor(white: 0.9, alpha: 0.9)
        statusLabel.verticalAlignmentMode = .center
        statusLabel.position = CGPoint(x: 0, y: isSmall ? 0 : 3)

        detailLabel = SKLabelNode(fontNamed: "Menlo")
        detailLabel.fontSize = isSmall ? 3 : 5
        detailLabel.fontColor = SKColor(white: 0.7, alpha: 0.8)
        detailLabel.verticalAlignmentMode = .center
        detailLabel.position = CGPoint(x: 0, y: isSmall ? -4 : -4)

        // Crop node to prevent text/textures from extending beyond screen bounds.
        // CRITICAL: mask fillColor must be white (opaque) for content to show through.
        // SKShapeNode defaults to fillColor=.clear which makes the mask fully transparent!
        cropNode = SKCropNode()
        let maskShape = SKShapeNode(path: path)
        maskShape.fillColor = .white
        maskShape.strokeColor = .white
        cropNode.maskNode = maskShape

        super.init()

        self.position = CGPoint(x: centerX, y: centerY)
        self.name = "screen-node"

        addChild(glowNode)
        // screenBg INSIDE cropNode so it clips to the screen shape
        screenBg.zPosition = 0
        cropNode.addChild(screenBg)
        statusLabel.zPosition = 2
        cropNode.addChild(statusLabel)
        if !isSmall {
            detailLabel.zPosition = 2
            cropNode.addChild(detailLabel)
        }
        cropNode.zPosition = 1  // above glow
        addChild(cropNode)
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

    /// Assign a single session to this monitor.
    func assignSession(_ session: Session?) {
        let oldStatus = status

        if let session = session {
            let newStatus = ScreenStatus.from(session.status)
            self.status = newStatus
            self.sessions = [session]
        } else {
            self.status = .off
            self.sessions = []
        }

        updateVisuals()

        if status == .off {
            setHovered(false)
        }

        if status != oldStatus {
            animateStatusChange(to: status)
        }
    }

    /// Turn off this monitor.
    func turnOff() {
        assignSession(nil)
    }

    private func statusLabel(for status: ScreenStatus) -> String {
        switch status {
        case .running:    return "working"
        case .needsInput: return "waiting"
        case .error:      return "error"
        case .idle:       return "idle"
        case .off:        return ""
        }
    }

    private func updateVisuals() {
        // When a texture is displayed, keep the dark background so the status
        // color doesn't bleed through the margin around the scaled-down sprite.
        if contentSprite != nil {
            screenBg.fillColor = SKColor(red: 0.01, green: 0.01, blue: 0.02, alpha: 1.0)
        } else {
            screenBg.fillColor = status.color
        }

        glowNode.fillColor = status.glowColor
        glowNode.alpha = status == .off ? 0 : 1

        // No text on any monitor -- status is conveyed by color glow,
        // decorative textures (center), and the floor status text.
        // Text on perspective-distorted trapezoids looks bad at any size.
        statusLabel.text = ""
        detailLabel.text = ""

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

    // MARK: - Hover

    func setHovered(_ hovered: Bool) {
        if hovered {
            guard status != .off, hoverOverlay == nil else { return }
            let overlay = SKShapeNode(path: hitPath)
            overlay.fillColor = SKColor(white: 1.0, alpha: 0.1)
            overlay.strokeColor = .clear
            overlay.lineWidth = 0
            overlay.zPosition = 5
            addChild(overlay)
            hoverOverlay = overlay
        } else {
            guard hoverOverlay != nil else { return }
            hoverOverlay?.removeFromParent()
            hoverOverlay = nil
        }
    }

    // MARK: - Permission Bubbles

    func showPermissionBubble(text: String, onDecision: @escaping (Bool) -> Void) {
        removePermissionBubble()

        let bubble = SKNode()
        bubble.name = "permission-bubble"
        bubble.position = CGPoint(x: 0, y: screenHeight / 2 + 30)
        bubble.zPosition = 100

        let bgW: CGFloat = 140
        let bgH: CGFloat = 44
        let bg = SKShapeNode(rectOf: CGSize(width: bgW, height: bgH), cornerRadius: 4)
        bg.fillColor = SKColor(white: 0.06, alpha: 0.95)
        bg.strokeColor = SKColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 0.7)
        bg.lineWidth = 1
        bubble.addChild(bg)

        let label = SKLabelNode(fontNamed: "Menlo")
        label.text = String(text.prefix(30))
        label.fontSize = 7
        label.fontColor = SKColor(white: 0.9, alpha: 0.9)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 12)
        bubble.addChild(label)

        let allowBtn = SKShapeNode(rectOf: CGSize(width: 55, height: 18), cornerRadius: 3)
        allowBtn.fillColor = SKColor(red: 0.15, green: 0.5, blue: 0.2, alpha: 1.0)
        allowBtn.strokeColor = .clear
        allowBtn.position = CGPoint(x: -32, y: -10)
        allowBtn.name = "allow-btn"
        bubble.addChild(allowBtn)

        let allowLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        allowLabel.text = "Allow"
        allowLabel.fontSize = 8
        allowLabel.fontColor = .white
        allowLabel.verticalAlignmentMode = .center
        allowLabel.position = CGPoint(x: -32, y: -10)
        bubble.addChild(allowLabel)

        let denyBtn = SKShapeNode(rectOf: CGSize(width: 55, height: 18), cornerRadius: 3)
        denyBtn.fillColor = SKColor(red: 0.5, green: 0.15, blue: 0.15, alpha: 1.0)
        denyBtn.strokeColor = .clear
        denyBtn.position = CGPoint(x: 32, y: -10)
        denyBtn.name = "deny-btn"
        bubble.addChild(denyBtn)

        let denyLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        denyLabel.text = "Deny"
        denyLabel.fontSize = 8
        denyLabel.fontColor = .white
        denyLabel.verticalAlignmentMode = .center
        denyLabel.position = CGPoint(x: 32, y: -10)
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

        let allowArea = CGRect(x: -59.5, y: bubbleY - 19, width: 55, height: 18)
        if allowArea.contains(localPoint) {
            permissionCallback?(true)
            removePermissionBubble()
            return true
        }

        let denyArea = CGRect(x: 4.5, y: bubbleY - 19, width: 55, height: 18)
        if denyArea.contains(localPoint) {
            permissionCallback?(false)
            removePermissionBubble()
            return true
        }

        return false
    }

    // MARK: - Screen Content Textures

    /// Display a decorative texture inside the screen shape, hiding the status color fill.
    ///
    /// Content is scaled down on side monitors so the icon stays comfortably
    /// within the trapezoid crop area. No rotation -- the trapezoid crop and
    /// dark background naturally convey the monitor's perspective.
    func showTexture(_ texture: SKTexture) {
        contentSprite?.removeFromParent()
        contentSprite = nil

        // Compute the bounding box of the trapezoid to size the sprite
        let minX = min(localTopLeft.x, localBottomLeft.x)
        let maxX = max(localTopRight.x, localBottomRight.x)
        let minY = min(localBottomLeft.y, localBottomRight.y)
        let maxY = max(localTopLeft.y, localTopRight.y)
        let w = maxX - minX
        let h = maxY - minY
        let centerX = (minX + maxX) / 2

        texture.filteringMode = .nearest  // pixel-crisp

        // Texture is tall (3x screen height) for scrolling.
        // Show it at screen width, full texture height.
        let texAspect = texture.size().height / texture.size().width
        let spriteW = w * 0.95
        let spriteH = spriteW * texAspect

        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: spriteW, height: spriteH))
        // Start with bottom of texture aligned to bottom of screen
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        sprite.position = CGPoint(x: centerX, y: minY)
        sprite.zPosition = 1  // above screenBg (z:0) within the crop
        contentSprite = sprite
        cropNode.addChild(sprite)

        // Slow upward scroll: content scrolls through the crop window
        let scrollDistance = spriteH - h
        if scrollDistance > 2 {
            let scrollDuration = Double.random(in: 20...35)  // slow ambient scroll
            let scroll = SKAction.moveBy(x: 0, y: scrollDistance, duration: scrollDuration)
            let reset = SKAction.move(to: CGPoint(x: centerX, y: minY), duration: 0)
            sprite.run(SKAction.repeatForever(SKAction.sequence([scroll, reset])), withKey: "scroll")
        }

        statusLabel.isHidden = true
        detailLabel.isHidden = true
        screenBg.fillColor = SKColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1.0)
    }

    /// Revert to the status color fill (fallback when no textures are available).
    func showStatusColor() {
        contentSprite?.removeFromParent()
        contentSprite = nil
        statusLabel.isHidden = false
        detailLabel.isHidden = false
        updateVisuals()
    }
}
