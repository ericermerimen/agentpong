import AppKit
import SpriteKit

/// Loads sprite assets from ~/.agentpong/sprites/
/// Falls back to colored placeholders if sprites are missing.
public final class SpriteAssetLoader {

    public static let shared = SpriteAssetLoader()

    private let spritesDir: URL
    private var textureCache: [String: SKTexture] = [:]
    private var frameCache: [String: [SKTexture]] = [:]

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        spritesDir = home.appendingPathComponent(".agentpong/sprites")
    }

    /// Load a texture by filename. Returns nil if not found.
    public func texture(named name: String) -> SKTexture? {
        if let cached = textureCache[name] { return cached }

        let path = spritesDir.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: path.path),
              let image = NSImage(contentsOfFile: path.path) else {
            return nil
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest  // Pixel-perfect scaling
        textureCache[name] = texture
        return texture
    }

    /// Load character texture for a direction. Falls back to south.
    public func characterTexture(direction: String) -> SKTexture? {
        texture(named: "char_\(direction).png") ?? texture(named: "char_south.png")
    }

    /// Load cat texture for a direction. Falls back to south.
    public func catTexture(direction: String) -> SKTexture? {
        texture(named: "cat_\(direction).png") ?? texture(named: "cat_south.png")
    }

    /// Load animation frames by prefix and direction.
    /// Scans for {prefix}_{direction}_0.png, {prefix}_{direction}_1.png, etc.
    public func animationFrames(prefix: String, direction: String) -> [SKTexture] {
        let key = "\(prefix)_\(direction)"
        if let cached = frameCache[key] { return cached }

        var frames: [SKTexture] = []
        for i in 0..<20 {  // Max 20 frames
            if let tex = texture(named: "\(key)_\(i).png") {
                frames.append(tex)
            } else {
                break
            }
        }
        if !frames.isEmpty { frameCache[key] = frames }
        return frames
    }

    /// Load character walk frames (PixelLab naming: char_walking_{dir}_{frame}.png)
    public func characterWalkFrames(direction: String) -> [SKTexture] {
        animationFrames(prefix: "char_walking", direction: direction)
    }

    /// Load character sitting frame (first frame of crouching animation).
    public func characterSittingTexture(direction: String) -> SKTexture? {
        texture(named: "char_sitting_\(direction)_0.png")
    }

    /// Load cat walk frames (PixelLab naming: cat_slow-run_{dir}_{frame}.png)
    public func catWalkFrames(direction: String) -> [SKTexture] {
        animationFrames(prefix: "cat_slow-run", direction: direction)
    }

    // MARK: - Husky Sprites

    /// Load husky texture for a direction. Sprites at husky/{direction}.png
    public func huskyTexture(direction: String) -> SKTexture? {
        texture(named: "husky/\(direction).png")
            ?? texture(named: "husky/south.png")
    }

    /// Load husky animation frames for exact direction only.
    /// Returns empty if no frames for that direction -- caller handles fallback.
    /// Never substitutes a wrong-direction animation (e.g. south walk for north movement).
    public func huskyAnimFrames(animation: String, direction: String) -> [SKTexture] {
        let exact = animationFrames(prefix: "husky/\(animation)", direction: direction)
        if !exact.isEmpty { return exact }

        // Only fall back to the SAME visual direction:
        // south-west can use west, south-east can use south, etc.
        // But NEVER use south frames when moving north.
        let safeFallbacks: [String: [String]] = [
            "south": ["south-west", "south-east"],
            "south-west": ["west", "south"],
            "south-east": ["south"],
            "west": ["south-west"],
            "east": [],           // use west flipped -- handled by caller
            "north": [],          // no south substitution
            "north-west": ["west"],
            "north-east": [],     // use north-west flipped -- handled by caller
        ]
        for fb in safeFallbacks[direction] ?? [] {
            let frames = animationFrames(prefix: "husky/\(animation)", direction: fb)
            if !frames.isEmpty { return frames }
        }
        return []
    }

    /// Convenience loaders for specific animations.
    public func huskyWalkFrames(direction: String) -> [SKTexture] {
        huskyAnimFrames(animation: "walk-6-frames", direction: direction)
    }

    public func huskyIdleFrames(direction: String = "south") -> [SKTexture] {
        huskyAnimFrames(animation: "idle", direction: direction)
    }

    public func huskyBarkFrames() -> [SKTexture] {
        huskyAnimFrames(animation: "bark", direction: "south")
    }

    public func huskySneakFrames(direction: String) -> [SKTexture] {
        huskyAnimFrames(animation: "sneaking", direction: direction)
    }

    public func huskyRunFrames(direction: String) -> [SKTexture] {
        huskyAnimFrames(animation: "running-6-frames", direction: direction)
    }

    public func huskySleepingFrames() -> [SKTexture] {
        huskyAnimFrames(animation: "husky-sleeping", direction: "south")
    }

    public func huskyDrinkingFrames() -> [SKTexture] {
        huskyAnimFrames(animation: "husky-drinking", direction: "south")
    }

    public func huskyPlayingFrames() -> [SKTexture] {
        huskyAnimFrames(animation: "husky-playing", direction: "south")
    }

    public func huskySittingFrames() -> [SKTexture] {
        huskyAnimFrames(animation: "husky-sitting", direction: "south")
    }

    public var hasHuskySprites: Bool {
        texture(named: "husky/south.png") != nil
    }

    // MARK: - Legacy (kept for backward compat during transition)

    /// Load desk texture by index and variant.
    public func deskTexture(index: Int, variant: Int = 0) -> SKTexture? {
        if variant == 0 {
            return texture(named: "desk_\(index).png")
        } else {
            return texture(named: "desk_\(index)_alt.png")
        }
    }

    public var hasCharacterSprites: Bool {
        texture(named: "char_south.png") != nil
    }

    public var hasCatSprites: Bool {
        texture(named: "cat_south.png") != nil
    }

    public var hasFurnitureSprites: Bool {
        texture(named: "desk_0.png") != nil
    }
}
