import Foundation
import Shared

/// Manages office zones mapped to the actual Gemini-generated background image.
///
/// Background is 871x847 pixels, displayed in a 320x320 SpriteKit scene.
/// Uses separate X/Y scale factors since the image is not perfectly square.
///
/// The background contains painted furniture. Characters overlay on top.
/// Zone positions are mapped to WHERE THE CHAIRS ARE in the background.
public class ZoneManager {

    // Scene dimensions
    public let sceneWidth: CGFloat = 320
    public let sceneHeight: CGFloat = 320

    // Scale factors: background image pixels -> scene points
    private let scaleX: CGFloat = 871.0 / 320.0  // 2.722
    private let scaleY: CGFloat = 847.0 / 320.0  // 2.647

    /// Convert background image coordinates to scene coordinates.
    /// Note: SpriteKit Y is bottom-up, image Y is top-down.
    private func imageToScene(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: x / scaleX, y: sceneHeight - (y / scaleY))
    }

    // MARK: - Desk Zone (running sessions)
    // Background layout:
    //   - 2 main desks against TOP wall (chairs face south/toward camera)
    //   - 1 side desk on LEFT wall (chair faces east)
    //   - 1 side desk on RIGHT wall (chair faces west)

    /// Chair positions where characters sit when working.
    public var deskPositions: [CGPoint] {
        [
            imageToScene(x: 125, y: 523),   // left wall side desk
            imageToScene(x: 320, y: 474),   // main desk left
            imageToScene(x: 509, y: 474),   // main desk right
            imageToScene(x: 751, y: 523),   // right wall side desk
        ]
    }

    /// Which direction the character faces when seated at each desk.
    public let deskFacingDirections: [String] = [
        "west",   // left wall desk faces west (toward left wall monitor)
        "north",  // main desk left faces north (toward top wall monitor)
        "north",  // main desk right faces north (toward top wall monitor)
        "east",   // right wall desk faces east (toward right wall monitor)
    ]

    // MARK: - Lounge Zone (idle/needsInput sessions)

    /// Sofa seating positions for idle characters.
    public var loungePositions: [CGPoint] {
        [
            imageToScene(x: 340, y: 670),   // sofa left
            imageToScene(x: 435, y: 670),   // sofa center
            imageToScene(x: 530, y: 670),   // sofa right
        ]
    }

    // MARK: - Debug Station (error sessions)

    /// Position near the server rack for error characters.
    public var debugPosition: CGPoint {
        imageToScene(x: 750, y: 480)
    }

    // MARK: - Entry/Exit (no door in this background, use bottom-center)

    public var doorPosition: CGPoint {
        imageToScene(x: 435, y: 870)  // Bottom center, just off-screen
    }

    // MARK: - Ambient positions

    public var serverRackPosition: CGPoint {
        imageToScene(x: 790, y: 260)
    }

    public var coffeePosition: CGPoint {
        imageToScene(x: 140, y: 390)
    }

    public var ceilingLampPosition: CGPoint {
        imageToScene(x: 435, y: 170)
    }

    /// Floor center (for mascot cat wandering)
    public var floorCenter: CGPoint {
        imageToScene(x: 435, y: 540)
    }

    /// Walkable area bounds (the open floor space between desks and sofa)
    public var walkableArea: CGRect {
        let topLeft = imageToScene(x: 120, y: 450)
        let bottomRight = imageToScene(x: 750, y: 640)
        return CGRect(
            x: topLeft.x, y: bottomRight.y,
            width: bottomRight.x - topLeft.x,
            height: topLeft.y - bottomRight.y
        )
    }

    // MARK: - Assignment

    /// Assign a desk index to a session (stable hash-based).
    public func deskForSession(_ sessionId: String) -> Int {
        abs(sessionId.hashValue) % deskPositions.count
    }

    /// Assign a lounge position to a session.
    public func loungeForSession(_ sessionId: String) -> Int {
        abs(sessionId.hashValue) % loungePositions.count
    }

    /// Get target scene position for a zone.
    public func targetPosition(zone: OfficeZone, sessionId: String) -> CGPoint {
        switch zone {
        case .desk:
            return deskPositions[deskForSession(sessionId)]
        case .lounge:
            return loungePositions[loungeForSession(sessionId)]
        case .debugStation:
            return debugPosition
        case .door:
            return doorPosition
        }
    }

    /// Character sprite size in scene points.
    /// Sized to match the painted chairs (~35px visible character on chair).
    public let characterSize: CGFloat = 90

    /// Z-position for depth sorting. Lower Y = further back = lower Z.
    public func zPosition(for sceneY: CGFloat) -> CGFloat {
        return sceneHeight - sceneY + 50
    }
}
