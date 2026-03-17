import SpriteKit
import Shared

/// A desk workstation with chair, lamp glow, and swappable item variants.
/// Each desk has a unique sprite. Lamp glows when occupied.
class DeskNode: SKNode {

    let deskIndex: Int
    private(set) var occupantId: String?

    private let deskSprite: SKSpriteNode
    private let chairSprite: SKSpriteNode
    private let glowNode: SKSpriteNode
    private var personalItem: SKSpriteNode?

    private let assets = SpriteAssetLoader.shared
    private let deskScale: CGFloat = 0.55
    private let chairScale: CGFloat = 0.55

    // Item swap
    private var deskVariants: [SKTexture] = []
    private var currentVariant: Int = 0
    private var swapTimer: TimeInterval = 0
    private var nextSwapDelay: TimeInterval = 60

    // Personal items that devs "bring" to their desk
    private static let personalItems = ["item_duck", "item_cactus", "item_coffee", "item_books"]

    init(deskIndex: Int, deskPosition: CGPoint, chairOffset: CGPoint, effectsLayer: SKNode) {
        self.deskIndex = deskIndex

        // Load unique desk texture, fallback to generic
        let deskTex = assets.deskTexture(index: deskIndex) ?? assets.deskTexture(index: 0)
        if let tex = deskTex {
            deskSprite = SKSpriteNode(texture: tex)
            deskSprite.setScale(deskScale)
        } else {
            deskSprite = SKSpriteNode(color: SKColor(red: 0.18, green: 0.12, blue: 0.08, alpha: 1.0),
                                      size: CGSize(width: 50, height: 30))
        }
        deskSprite.anchorPoint = CGPoint(x: 0.5, y: 0.0)

        // Load all variants for this desk
        // (will be populated if desk_X_alt.png exists)

        // Chair
        if let chairTex = assets.texture(named: "chair.png") {
            chairSprite = SKSpriteNode(texture: chairTex)
            chairSprite.setScale(chairScale)
        } else {
            chairSprite = SKSpriteNode(color: SKColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0),
                                       size: CGSize(width: 18, height: 20))
        }
        chairSprite.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        chairSprite.position = chairOffset

        // Lamp glow (additive blend, warm amber)
        glowNode = SKSpriteNode(color: SKColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 0.0),
                                size: CGSize(width: 40, height: 30))
        glowNode.blendMode = .add
        glowNode.alpha = 0

        super.init()

        self.position = deskPosition
        self.name = "desk-\(deskIndex)"

        addChild(deskSprite)
        addChild(chairSprite)

        // Glow goes into effects layer at desk's world position
        let glowWorldPos = CGPoint(x: deskPosition.x, y: deskPosition.y + 15)
        glowNode.position = glowWorldPos
        glowNode.zPosition = 45
        effectsLayer.addChild(glowNode)

        // Load variant textures for swapping
        loadVariants()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Occupy / Vacate

    var isOccupied: Bool { occupantId != nil }

    func occupy(sessionId: String) {
        guard occupantId == nil else { return }
        occupantId = sessionId

        // Lamp glow on
        glowNode.removeAllActions()
        glowNode.run(SKAction.fadeAlpha(to: 0.25, duration: 0.5))
        let flicker = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 1.8),
            SKAction.fadeAlpha(to: 0.2, duration: 1.8),
        ])
        glowNode.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.repeatForever(flicker)
        ]), withKey: "flicker")

        // Personal item pops in
        addPersonalItem(sessionId: sessionId)

        // Reset swap timer
        swapTimer = 0
        nextSwapDelay = Double.random(in: 45...90)
    }

    func vacate() {
        occupantId = nil

        // Lamp glow off
        glowNode.removeAction(forKey: "flicker")
        glowNode.run(SKAction.fadeAlpha(to: 0, duration: 0.8))

        // Personal item pops out
        removePersonalItem()
    }

    // MARK: - Update

    func update(deltaTime: TimeInterval) {
        guard isOccupied, deskVariants.count > 1 else { return }

        swapTimer += deltaTime
        if swapTimer >= nextSwapDelay {
            swapTimer = 0
            nextSwapDelay = Double.random(in: 45...90)
            swapToNextVariant()
        }
    }

    // MARK: - Private

    private func loadVariants() {
        // Load desk_X.png and desk_X_alt.png as variants
        if let primary = assets.deskTexture(index: deskIndex) {
            deskVariants.append(primary)
        }
        if let alt = assets.deskTexture(index: deskIndex, variant: 1) {
            deskVariants.append(alt)
        }
    }

    private func swapToNextVariant() {
        guard deskVariants.count > 1 else { return }
        currentVariant = (currentVariant + 1) % deskVariants.count
        let newTex = deskVariants[currentVariant]

        deskSprite.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.3),
            SKAction.run { [weak self] in
                self?.deskSprite.texture = newTex
                self?.deskSprite.texture?.filteringMode = .nearest
            },
            SKAction.fadeAlpha(to: 1.0, duration: 0.3),
        ]))
    }

    private func addPersonalItem(sessionId: String) {
        let hash = abs(sessionId.hashValue)
        let itemName = DeskNode.personalItems[hash % DeskNode.personalItems.count]

        if let tex = assets.texture(named: "\(itemName).png") {
            let item = SKSpriteNode(texture: tex)
            item.setScale(0.4)
            item.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            item.position = CGPoint(x: -15, y: 12)
            item.zPosition = 2
            item.setScale(0)
            addChild(item)
            item.run(SKAction.scale(to: 0.4, duration: 0.2))
            personalItem = item
        }
    }

    private func removePersonalItem() {
        personalItem?.run(SKAction.sequence([
            SKAction.scale(to: 0, duration: 0.2),
            SKAction.removeFromParent()
        ]))
        personalItem = nil
    }
}
