import Foundation
import Shared

/// Manages positions mapped to the Gemini-generated cozy room background.
///
/// Background: 1024x1024 pixels, displayed in a 320x320 SpriteKit scene.
/// Scale factor: 1024 / 320 = 3.2
///
/// Room layout (top-down, image coordinates):
///   - Monitor + desk against top wall (~y:100-280)
///   - Lamp in center (~x:400, y:360)
///   - Open floor (~y:400-830)
///   - Dog bed bottom-left (~x:240, y:870)
///   - Water bowl bottom-center (~x:410, y:920)
///   - Plant bottom-right (~x:830, y:870)
public class ZoneManager {

    public let sceneWidth: CGFloat = 320
    public let sceneHeight: CGFloat = 320

    private let scale: CGFloat = 1024.0 / 320.0  // 3.2

    /// Convert background image coordinates to SpriteKit scene coordinates.
    /// SpriteKit Y is bottom-up; image Y is top-down.
    private func imageToScene(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: x / scale, y: sceneHeight - (y / scale))
    }

    // MARK: - Monitor Screen

    /// Center of the monitor screen (dark area in background).
    public var monitorCenter: CGPoint {
        imageToScene(x: 640, y: 162)
    }

    /// Size of the monitor screen overlay in scene points.
    public var monitorSize: CGSize {
        CGSize(width: 200 / scale, height: 95 / scale)  // ~62x30
    }

    // MARK: - Pet Zones

    /// Dog bed center (bottom-left). Centered inside the cushion.
    public var dogBedPosition: CGPoint {
        imageToScene(x: 200, y: 940)
    }

    /// Water bowl position (bottom-center).
    public var waterBowlPosition: CGPoint {
        imageToScene(x: 410, y: 920)
    }

    /// Lamp pole center (exclusion zone for pet).
    public var lampPosition: CGPoint {
        imageToScene(x: 400, y: 360)
    }

    /// Lamp exclusion radius in scene points.
    public let lampExclusionRadius: CGFloat = 30

    /// Plant position (bottom-right).
    public var plantPosition: CGPoint {
        imageToScene(x: 830, y: 870)
    }

    /// Floor center (default husky position).
    public var floorCenter: CGPoint {
        imageToScene(x: 512, y: 620)
    }

    /// Walkable area for the husky (open floor only -- tight bounds).
    /// Image coords: x:300-750, y:520-780 (clear of walls, lamp, desk, dog bed, plant).
    public var walkableArea: CGRect {
        let topLeft = imageToScene(x: 300, y: 520)
        let bottomRight = imageToScene(x: 750, y: 780)
        return CGRect(
            x: bottomRight.x < topLeft.x ? bottomRight.x : topLeft.x,
            y: bottomRight.y < topLeft.y ? bottomRight.y : topLeft.y,
            width: abs(bottomRight.x - topLeft.x),
            height: abs(topLeft.y - bottomRight.y)
        )
    }

    // MARK: - Entry/Exit

    /// Off-screen position for arrivals/departures (bottom edge).
    public var doorPosition: CGPoint {
        imageToScene(x: 512, y: 1060)
    }

    // MARK: - Depth Sorting

    /// Z-position for depth sorting. Lower Y (closer to camera) = higher Z.
    public func zPosition(for sceneY: CGFloat) -> CGFloat {
        return sceneHeight - sceneY + 50
    }

    /// Perspective scale factor based on Y position.
    /// Objects at bottom of scene (closer to camera) appear larger.
    /// Objects at top (further away) appear smaller.
    ///
    /// Range: ~0.8 at top of walkable area to ~1.3 at bottom.
    public func perspectiveScale(for sceneY: CGFloat) -> CGFloat {
        let area = walkableArea
        let t = (sceneY - area.minY) / max(area.height, 1)  // 0=bottom, 1=top
        let minScale: CGFloat = 1.15  // at bottom (close to camera)
        let maxScale: CGFloat = 0.85  // at top (far from camera)
        return minScale + (maxScale - minScale) * t
    }

    /// Husky sprite size in scene points.
    public let huskySize: CGFloat = 48
}
