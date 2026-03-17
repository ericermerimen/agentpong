import SpriteKit
import Shared

/// Manages decorative screen textures on the 3 monitors based on session state.
///
/// Uses procedurally generated dark textures (ScreenTextureGenerator) that
/// look like dim monitors seen from across a cozy dark room. Rotates
/// within the same category every 45-60s.
final class ScreenContentManager {

    // MARK: - Status Category

    enum StatusCategory: Equatable {
        case working
        case waiting
        case idle
        case noSessions
        case error
    }

    // MARK: - State

    private(set) var currentCategory: StatusCategory = .noSessions
    private var rotationTimer: TimeInterval = 0
    private var rotationInterval: TimeInterval = 0

    // MARK: - Category Detection

    /// Determine the status category from the current sessions.
    static func category(for sessions: [Session]) -> StatusCategory {
        let visible = sessions.filter(\.isVisible)
        guard !visible.isEmpty else { return .noSessions }

        let hasRunning = visible.contains { $0.status == .running }
        let hasError = visible.contains { $0.status == .error }
        let hasWaiting = visible.contains { $0.status == .needsInput }

        // Priority: error > working > waiting > idle
        if hasError && !hasRunning { return .error }
        if hasRunning { return .working }
        if hasWaiting { return .waiting }
        return .idle
    }

    // MARK: - Update

    /// Called every frame from OfficeScene.update. Handles rotation timing.
    func update(deltaTime dt: TimeInterval, sessions: [Session], screenNodes: [ScreenNode]) {
        let newCategory = Self.category(for: sessions)

        if newCategory != currentCategory {
            currentCategory = newCategory
            pickNewContent(for: screenNodes)
            rotationTimer = 0
            rotationInterval = Self.randomInterval()
        } else {
            rotationTimer += dt
            if rotationTimer >= rotationInterval {
                rotationTimer = 0
                rotationInterval = Self.randomInterval()
                pickNewContent(for: screenNodes)
            }
        }
    }

    // MARK: - Content Selection

    /// Pick procedurally generated textures for all 3 screens.
    /// Each screen gets a different content type to avoid repetition.
    private func pickNewContent(for screenNodes: [ScreenNode]) {
        guard screenNodes.count == 3 else { return }
        let gen = ScreenTextureGenerator.shared

        // Center screen (index 1)
        let centerTex = gen.centerTexture(for: currentCategory)
        screenNodes[1].showTexture(centerTex)

        // Side screens (index 0, 2): same content types, different picks
        let leftTex = gen.sideTexture(for: currentCategory)
        screenNodes[0].showTexture(leftTex)
        screenNodes[2].showTexture(gen.sideTexture(for: currentCategory))
    }

    /// Random interval between 45-60 seconds for within-category rotation.
    private static func randomInterval() -> TimeInterval {
        TimeInterval.random(in: 45...60)
    }
}
