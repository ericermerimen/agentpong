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

    /// Load desk texture by index and variant. desk_0.png, desk_0_alt.png, etc.
    public func deskTexture(index: Int, variant: Int = 0) -> SKTexture? {
        if variant == 0 {
            return texture(named: "desk_\(index).png")
        } else {
            return texture(named: "desk_\(index)_alt.png")
        }
    }

    /// Check if real sprites are available
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
