import SpriteKit
import Shared

/// The office mascot cat -- always present, wanders around the office.
class MascotNode: SKNode {

    private let sprite: SKSpriteNode
    private let assets = SpriteAssetLoader.shared
    private let hasRealSprites: Bool
    private let catScale: CGFloat = 3.0

    private var wanderTimer: TimeInterval = 0
    private var nextWanderDelay: TimeInterval = 5.0
    private let wanderZone: CGRect

    init(startPosition: CGPoint, wanderZone: CGRect) {
        self.wanderZone = wanderZone

        if let tex = assets.catTexture(direction: "south") {
            sprite = SKSpriteNode(texture: tex)
            sprite.setScale(catScale)
            hasRealSprites = true
        } else {
            sprite = SKSpriteNode(color: SKColor(red: 0.9, green: 0.5, blue: 0.1, alpha: 1.0),
                                  size: CGSize(width: 16, height: 12))
            hasRealSprites = false
        }
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.0)

        super.init()
        addChild(sprite)
        position = startPosition
        name = "mascot-cat"

        startIdleAnimation()
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(deltaTime: TimeInterval) {
        wanderTimer += deltaTime
        if wanderTimer >= nextWanderDelay {
            wanderTimer = 0
            nextWanderDelay = Double.random(in: 4...12)
            wanderToRandomSpot()
        }
    }

    /// Check if a scene point is within the cat's hit area.
    func hitTest(_ point: CGPoint) -> Bool {
        let catFrame = CGRect(
            x: position.x - 20, y: position.y - 5,
            width: 40, height: 50
        )
        return catFrame.contains(point)
    }

    /// Cat gets scared and runs to a random far corner.
    func scare() {
        removeAction(forKey: "wander")
        sprite.removeAction(forKey: "idle")
        sprite.removeAction(forKey: "walkAnim")
        sprite.removeAction(forKey: "walkBob")
        sprite.position = .zero

        // Pick a corner far from current position
        let corners = [
            CGPoint(x: wanderZone.minX, y: wanderZone.minY),
            CGPoint(x: wanderZone.maxX, y: wanderZone.minY),
            CGPoint(x: wanderZone.minX, y: wanderZone.maxY),
            CGPoint(x: wanderZone.maxX, y: wanderZone.maxY),
        ]
        let farthest = corners.max(by: {
            hypot($0.x - position.x, $0.y - position.y) <
            hypot($1.x - position.x, $1.y - position.y)
        }) ?? corners[0]

        let dir = dominantDirection(toward: farthest)
        let isWest = (dir == "west")
        setSpriteDirection(isWest ? "east" : dir, flipX: isWest)

        // Fast run animation
        let animDir = isWest ? "east" : dir
        let walkFrames = assets.catWalkFrames(direction: animDir)
        if !walkFrames.isEmpty {
            let animate = SKAction.animate(with: walkFrames, timePerFrame: 1.0 / 14.0)
            sprite.run(SKAction.repeatForever(animate), withKey: "walkAnim")
        }

        // Quick bounce
        let bounce = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 2, duration: 0.06),
            SKAction.moveBy(x: 0, y: -2, duration: 0.06),
        ])
        sprite.run(SKAction.repeatForever(bounce), withKey: "walkBob")

        let distance = hypot(farthest.x - position.x, farthest.y - position.y)
        let move = SKAction.move(to: farthest, duration: TimeInterval(distance / 80))
        move.timingMode = .easeOut

        let done = SKAction.run { [weak self] in
            self?.sprite.removeAction(forKey: "walkBob")
            self?.sprite.removeAction(forKey: "walkAnim")
            self?.sprite.position = .zero
            self?.setSpriteDirection("south", flipX: false)
            self?.startIdleAnimation()
            self?.wanderTimer = 0
            self?.nextWanderDelay = Double.random(in: 6...15)
        }

        run(SKAction.sequence([move, done]), withKey: "wander")
    }

    private func wanderToRandomSpot() {
        let target = CGPoint(
            x: CGFloat.random(in: wanderZone.minX...wanderZone.maxX),
            y: CGFloat.random(in: wanderZone.minY...wanderZone.maxY)
        )

        let dir = dominantDirection(toward: target)

        let distance = hypot(target.x - position.x, target.y - position.y)
        let speed: CGFloat = 20
        let duration = TimeInterval(distance / speed)

        // Clear all previous animations
        sprite.removeAction(forKey: "idle")
        sprite.removeAction(forKey: "walkAnim")
        sprite.removeAction(forKey: "walkBob")
        sprite.position = .zero

        // Set direction -- flip horizontally for west using east frames
        let isWest = (dir == "west")
        let animDir = isWest ? "east" : dir
        setSpriteDirection(dir, flipX: isWest)

        // Walk animation
        let walkFrames = assets.catWalkFrames(direction: animDir)
        if !walkFrames.isEmpty {
            let animate = SKAction.animate(with: walkFrames, timePerFrame: 1.0 / 8.0)
            sprite.run(SKAction.repeatForever(animate), withKey: "walkAnim")
        } else {
            // Fallback: try south frames, then bob
            let fallbackFrames = assets.catWalkFrames(direction: "south")
            if !fallbackFrames.isEmpty {
                let animate = SKAction.animate(with: fallbackFrames, timePerFrame: 1.0 / 8.0)
                sprite.run(SKAction.repeatForever(animate), withKey: "walkAnim")
            } else {
                let bob = SKAction.sequence([
                    SKAction.moveBy(x: 0, y: 1.5, duration: 0.12),
                    SKAction.moveBy(x: 0, y: -1.5, duration: 0.12),
                ])
                sprite.run(SKAction.repeatForever(bob), withKey: "walkBob")
            }
        }

        let move = SKAction.move(to: target, duration: max(duration, 0.3))
        move.timingMode = .easeInEaseOut

        let done = SKAction.run { [weak self] in
            self?.sprite.removeAction(forKey: "walkBob")
            self?.sprite.removeAction(forKey: "walkAnim")
            self?.sprite.position = .zero
            self?.setSpriteDirection("south", flipX: false)
            self?.startIdleAnimation()
        }

        run(SKAction.sequence([move, done]), withKey: "wander")
    }

    private func startIdleAnimation() {
        // Reset to normal scale (un-flipped)
        sprite.xScale = catScale
        let breathe = SKAction.sequence([
            SKAction.scaleY(to: catScale * 1.04, duration: 2.0),
            SKAction.scaleY(to: catScale, duration: 2.0),
        ])
        sprite.run(SKAction.repeatForever(breathe), withKey: "idle")
    }

    private func dominantDirection(toward target: CGPoint) -> String {
        let dx = target.x - position.x
        let dy = target.y - position.y
        if abs(dx) > abs(dy) {
            return dx > 0 ? "east" : "west"
        } else {
            return dy > 0 ? "north" : "south"
        }
    }

    /// Set sprite texture + handle horizontal flip for west direction.
    private func setSpriteDirection(_ direction: String, flipX: Bool) {
        guard hasRealSprites else { return }
        // For west, load east texture and flip
        let texDir = flipX ? "east" : direction
        if let tex = assets.catTexture(direction: texDir) {
            sprite.texture = tex
            sprite.texture?.filteringMode = .nearest
        }
        sprite.xScale = flipX ? -catScale : catScale
    }
}
