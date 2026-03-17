import Foundation
import Shared

/// Manages positions mapped to the Gemini-generated cozy room background.
///
/// Background: 1024x1024 pixels, displayed in a 320x320 SpriteKit scene.
/// Scale factor: 1024 / 320 = 3.2
///
/// Room layout (top-down, image coordinates):
///   - Triple monitor desk against top wall
///     - Left monitor:   x=467-505, y=165-213 (small, angled left)
///     - Center monitor:  x=614-771, y=134-213 (large, straight-on)
///     - Right monitor:   x=790-848, y=140-215 (medium, angled right)
///   - Lamp in center (~x:400, y:360)
///   - Open floor (~y:400-830)
///   - Dog bed bottom-left (~x:200, y:940)
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

    // MARK: - Monitor Screens (Triple Setup)

    /// Monitor corner data for creating ScreenNodes.
    public struct MonitorCorners {
        public let topLeft: CGPoint
        public let topRight: CGPoint
        public let bottomLeft: CGPoint
        public let bottomRight: CGPoint
    }

    /// Left monitor -- small, slightly angled. Measured via edge detection.
    /// Image coords: x=467-505, y=165-213 (after top reflection bar).
    public var leftMonitor: MonitorCorners {
        MonitorCorners(
            topLeft: imageToScene(x: 468, y: 166),
            topRight: imageToScene(x: 505, y: 160),
            bottomLeft: imageToScene(x: 468, y: 212),
            bottomRight: imageToScene(x: 505, y: 212)
        )
    }

    /// Center monitor -- large, straight-on view. Measured via edge detection.
    /// Image coords: x=614-771, y=134-213.
    public var centerMonitor: MonitorCorners {
        MonitorCorners(
            topLeft: imageToScene(x: 614, y: 134),
            topRight: imageToScene(x: 771, y: 134),
            bottomLeft: imageToScene(x: 614, y: 212),
            bottomRight: imageToScene(x: 771, y: 212)
        )
    }

    /// Right monitor -- medium, angled right. Measured via edge detection.
    /// Image coords: x=790-848, y=140-215 (perspective angles top edge).
    public var rightMonitor: MonitorCorners {
        MonitorCorners(
            topLeft: imageToScene(x: 790, y: 140),
            topRight: imageToScene(x: 847, y: 150),
            bottomLeft: imageToScene(x: 790, y: 214),
            bottomRight: imageToScene(x: 847, y: 214)
        )
    }

    /// All monitors in order (left, center, right).
    public var allMonitors: [MonitorCorners] {
        [leftMonitor, centerMonitor, rightMonitor]
    }

    /// Center of all monitors combined (for husky reactions).
    public var monitorCenter: CGPoint {
        let c = centerMonitor
        return CGPoint(
            x: (c.topLeft.x + c.topRight.x + c.bottomLeft.x + c.bottomRight.x) / 4,
            y: (c.topLeft.y + c.topRight.y + c.bottomLeft.y + c.bottomRight.y) / 4
        )
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
    public func perspectiveScale(for sceneY: CGFloat) -> CGFloat {
        let area = walkableArea
        let t = (sceneY - area.minY) / max(area.height, 1)
        let minScale: CGFloat = 1.15
        let maxScale: CGFloat = 0.85
        return minScale + (maxScale - minScale) * t
    }

    /// Husky sprite size in scene points.
    public let huskySize: CGFloat = 48
}
