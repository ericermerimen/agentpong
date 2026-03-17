import SpriteKit
import Shared

/// Character state in the office
enum CharacterState {
    case idle
    case walking
    case working
    case alerting
    case departing
}

/// A character node representing an agent session.
class CharacterNode: SKNode {

    let sessionId: String
    private(set) var characterState: CharacterState = .idle

    private let sprite: SKSpriteNode
    private let nameLabel: SKLabelNode
    private var bubbleNode: SKNode?
    private let characterColor: SKColor
    private let hasRealSprites: Bool
    private let tintColor: SKColor
    private let spriteScale: CGFloat
    private let spriteCanvasSize: CGFloat

    // MARK: - Init

    init(sessionId: String, startPosition: CGPoint, size: CGFloat) {
        self.sessionId = sessionId

        // Deterministic color from session ID (used as fallback tint)
        let hash = abs(sessionId.hashValue)
        let hue = CGFloat(hash % 360) / 360.0
        self.characterColor = SKColor(hue: hue, saturation: 0.5, brightness: 0.75, alpha: 1.0)
        self.tintColor = SKColor(hue: hue, saturation: 0.4, brightness: 0.9, alpha: 1.0)

        // Scale: size is desired scene height. Detect canvas size from sprite.
        let assets = SpriteAssetLoader.shared
        let canvasSize: CGFloat
        if let tex = assets.characterTexture(direction: "south") {
            canvasSize = tex.size().height
        } else {
            canvasSize = 64
        }
        self.spriteCanvasSize = canvasSize
        self.spriteScale = size / canvasSize

        // Use real sprite if available, otherwise colored square
        if let tex = assets.characterTexture(direction: "south") {
            sprite = SKSpriteNode(texture: tex)
            sprite.setScale(spriteScale)
            sprite.colorBlendFactor = 0.15
            sprite.color = SKColor(hue: hue, saturation: 0.3, brightness: 0.9, alpha: 1.0)
            hasRealSprites = true
        } else {
            sprite = SKSpriteNode(color: characterColor, size: CGSize(width: size * 0.6, height: size))
            hasRealSprites = false
        }
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.0)

        // Name label -- positioned above the rendered sprite
        let renderedHeight = spriteCanvasSize * spriteScale
        nameLabel = SKLabelNode(fontNamed: "Menlo")
        nameLabel.fontSize = 6
        nameLabel.fontColor = SKColor(white: 0.9, alpha: 0.85)
        nameLabel.verticalAlignmentMode = .bottom
        nameLabel.position = CGPoint(x: 0, y: renderedHeight + 2)

        super.init()

        addChild(sprite)
        addChild(nameLabel)

        position = startPosition
        alpha = 0
        run(SKAction.fadeIn(withDuration: 0.3))
        startBreathing()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Update

    func update(deltaTime: TimeInterval) {
        // Future: sprite frame animation updates
    }

    // MARK: - Public API

    func setName(_ name: String) {
        nameLabel.text = String(name.prefix(12))
    }

    /// Walk to a target position at given speed (points per second).
    func walkTo(target: CGPoint, speed: CGFloat, completion: (() -> Void)? = nil) {
        removeAction(forKey: "walk")
        characterState = .walking

        let distance = hypot(target.x - position.x, target.y - position.y)
        let duration = TimeInterval(distance / speed)

        // Set sprite direction based on movement vector
        updateSpriteDirection(toward: target)

        // Walk animation: use sprite sheet frames if available, otherwise bob
        sprite.removeAction(forKey: "breathe")
        sprite.removeAction(forKey: "walkAnim")
        sprite.removeAction(forKey: "walkBob")
        sprite.position = .zero

        // Use east walk frames for west (sprite is flipped)
        let dir = dominantDirection(toward: target)
        let animDir = (dir == "west") ? "east" : dir
        let walkFrames = SpriteAssetLoader.shared.characterWalkFrames(direction: animDir)
        if !walkFrames.isEmpty {
            let animate = SKAction.animate(with: walkFrames, timePerFrame: 1.0 / 10.0)
            sprite.run(SKAction.repeatForever(animate), withKey: "walkAnim")
        }

        // RPG-style bounce: hop up-down while walking
        let bounce = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 3, duration: 0.12),
            SKAction.moveBy(x: 0, y: -3, duration: 0.12),
        ])
        sprite.run(SKAction.repeatForever(bounce), withKey: "walkBob")

        let move = SKAction.move(to: target, duration: max(duration, 0.3))
        move.timingMode = .easeInEaseOut

        let done = SKAction.run { [weak self] in
            self?.sprite.removeAction(forKey: "walkBob")
            self?.sprite.removeAction(forKey: "walkAnim")
            self?.sprite.position = .zero
            self?.characterState = .idle
            self?.setSpriteTexture(direction: "south")
            self?.startBreathing()
            completion?()
        }

        run(SKAction.sequence([move, done]), withKey: "walk")
    }

    /// Update sprite texture to face the movement direction.
    private func updateSpriteDirection(toward target: CGPoint) {
        let dir = dominantDirection(toward: target)
        setSpriteTexture(direction: dir)
    }

    /// Determine the dominant cardinal direction toward a target.
    private func dominantDirection(toward target: CGPoint) -> String {
        let dx = target.x - position.x
        let dy = target.y - position.y
        if abs(dx) > abs(dy) {
            return dx > 0 ? "east" : "west"
        } else {
            return dy > 0 ? "north" : "south"
        }
    }

    /// Set sprite texture to a specific direction. Flips horizontally for west.
    private func setSpriteTexture(direction: String) {
        guard hasRealSprites else { return }
        let isWest = (direction == "west")
        let texDir = isWest ? "east" : direction
        if let tex = SpriteAssetLoader.shared.characterTexture(direction: texDir) {
            sprite.texture = tex
            sprite.texture?.filteringMode = .nearest
        }
        sprite.xScale = isWest ? -spriteScale : spriteScale
    }

    func startWorking(facingDirection: String = "north") {
        removeAction(forKey: "walk")
        characterState = .working
        sprite.removeAction(forKey: "breathe")
        sprite.removeAction(forKey: "walkBob")
        sprite.removeAction(forKey: "walkAnim")
        sprite.position = .zero

        // Use sitting sprite if available, otherwise standing direction
        let isWest = (facingDirection == "west")
        let texDir = isWest ? "east" : facingDirection
        if let sitTex = SpriteAssetLoader.shared.characterSittingTexture(direction: texDir) {
            sprite.texture = sitTex
            sprite.texture?.filteringMode = .nearest
            sprite.xScale = isWest ? -spriteScale : spriteScale
        } else {
            setSpriteTexture(direction: facingDirection)
        }
    }

    func startAlerting() {
        removeAction(forKey: "walk")
        characterState = .alerting
        sprite.removeAction(forKey: "breathe")
        sprite.removeAction(forKey: "walkBob")
        sprite.removeAction(forKey: "walkAnim")
        sprite.removeAction(forKey: "typing")
        sprite.position = .zero
        sprite.color = SKColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 1.0)
    }

    func startIdling() {
        removeAction(forKey: "walk")
        characterState = .idle
        sprite.removeAction(forKey: "walkBob")
        sprite.removeAction(forKey: "walkAnim")
        sprite.removeAction(forKey: "typing")
        sprite.position = .zero
        sprite.color = tintColor
        setSpriteTexture(direction: "south")
        startBreathing()
    }

    func fadeOutImmediate(completion: @escaping () -> Void) {
        removeAllActions()
        sprite.removeAllActions()
        run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.run(completion),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Bubbles

    func showBubble(text: String, color: SKColor) {
        removeBubble()

        let renderedHeight = spriteCanvasSize * spriteScale
        let bubble = SKNode()
        bubble.name = "bubble"
        bubble.position = CGPoint(x: 0, y: renderedHeight + 12)
        bubble.zPosition = 100

        let bgW = CGFloat(text.count) * 6 + 10
        let bg = SKShapeNode(rectOf: CGSize(width: bgW, height: 12), cornerRadius: 3)
        bg.fillColor = SKColor(white: 0.08, alpha: 0.9)
        bg.strokeColor = color.withAlphaComponent(0.5)
        bg.lineWidth = 0.5
        bubble.addChild(bg)

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 7
        label.fontColor = color
        label.verticalAlignmentMode = .center
        bubble.addChild(label)

        if text == "!" || text == "?" {
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.15, duration: 0.4),
                SKAction.scale(to: 1.0, duration: 0.4),
            ])
            bubble.run(SKAction.repeatForever(pulse))
        }

        addChild(bubble)
        bubbleNode = bubble
    }

    func removeBubble() {
        bubbleNode?.removeFromParent()
        bubbleNode = nil
    }

    // MARK: - Private

    private func startBreathing() {
        sprite.removeAction(forKey: "breathe")
        // Very subtle breathing -- just enough to feel alive, not enough to notice
        let baseScale = spriteScale
        let breathe = SKAction.sequence([
            SKAction.scaleY(to: baseScale * 1.01, duration: 2.5),
            SKAction.scaleY(to: baseScale, duration: 2.5),
        ])
        sprite.run(SKAction.repeatForever(breathe), withKey: "breathe")
    }
}
