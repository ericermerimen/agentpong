import SpriteKit
import Shared

/// Manages decorative screen textures on the 3 monitors based on session state.
///
/// Selects textures from content pools matching the current status category,
/// rotates within the same category every 45-60s, and ensures no duplicates
/// across the 3 screens. Falls back to status color fill when textures are missing.
final class ScreenContentManager {

    // MARK: - Status Category

    enum StatusCategory: Equatable {
        case working
        case waiting
        case idle
        case noSessions
        case error
    }

    // MARK: - Content Pools

    /// Center monitor texture names (without prefix -- loaded via SpriteAssetLoader).
    private static let centerPool: [StatusCategory: [String]] = [
        .working:    ["center-code-editor", "center-terminal", "center-claude-chat", "center-browser-docs"],
        .waiting:    ["center-claude-chat", "center-browser-docs"],
        .idle:       ["center-twitter-feed", "center-youtube-player", "center-trading-chart"],
        .noSessions: ["center-twitter-feed", "center-youtube-player", "center-trading-chart"],
        .error:      ["center-terminal", "center-browser-docs"],
    ]

    /// Side monitor texture names.
    private static let sidePool: [StatusCategory: [String]] = [
        .working:    ["side-code", "side-ai-chat", "side-browser"],
        .waiting:    ["side-ai-chat", "side-browser"],
        .idle:       ["side-social", "side-chart", "side-browser"],
        .noSessions: ["side-social", "side-chart", "side-browser"],
        .error:      ["side-code", "side-browser"],
    ]

    // MARK: - State

    private(set) var currentCategory: StatusCategory = .noSessions
    private var currentAssignments: [String?] = [nil, nil, nil]  // [left, center, right]
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
            // Category changed -- instant swap
            currentCategory = newCategory
            pickNewContent(for: screenNodes)
            rotationTimer = 0
            rotationInterval = Self.randomInterval()
        } else {
            // Same category -- rotate on timer
            rotationTimer += dt
            if rotationTimer >= rotationInterval {
                rotationTimer = 0
                rotationInterval = Self.randomInterval()
                pickNewContent(for: screenNodes)
            }
        }
    }

    // MARK: - Content Selection

    /// Pick random non-duplicate textures for all 3 screens and apply them.
    private func pickNewContent(for screenNodes: [ScreenNode]) {
        guard screenNodes.count == 3 else { return }

        let centerNames = Self.centerPool[currentCategory] ?? []
        let sideNames = Self.sidePool[currentCategory] ?? []
        let loader = SpriteAssetLoader.shared

        // Pick center texture (index 1)
        let centerPick = centerNames.randomElement()
        var usedNames: Set<String> = []
        if let name = centerPick { usedNames.insert(name) }

        // Pick left side texture (index 0) -- avoid duplicates
        let leftPick = pickRandom(from: sideNames, excluding: usedNames)
        if let name = leftPick { usedNames.insert(name) }

        // Pick right side texture (index 2) -- avoid duplicates
        let rightPick = pickRandom(from: sideNames, excluding: usedNames)

        let picks = [leftPick, centerPick, rightPick]
        currentAssignments = picks

        for (i, name) in picks.enumerated() {
            guard i < screenNodes.count else { continue }
            if let name = name, let tex = loader.screenTexture(named: name) {
                NSLog("[ScreenContent] screen[\(i)] showing texture: \(name)")
                screenNodes[i].showTexture(tex)
            } else {
                NSLog("[ScreenContent] screen[\(i)] FALLBACK to color (name=\(name ?? "nil"), tex=nil)")
                screenNodes[i].showStatusColor()
            }
        }
    }

    /// Pick a random name from the pool, excluding already-used names.
    private func pickRandom(from pool: [String], excluding used: Set<String>) -> String? {
        let available = pool.filter { !used.contains($0) }
        return available.randomElement() ?? pool.randomElement()
    }

    /// Random interval between 45-60 seconds for within-category rotation.
    private static func randomInterval() -> TimeInterval {
        TimeInterval.random(in: 45...60)
    }
}
