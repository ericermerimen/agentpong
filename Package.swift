// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentPong",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // Main app
        .executableTarget(
            name: "AgentPong",
            dependencies: ["SpriteEngine", "Shared"],
            path: "Sources/App"
        ),
        // SpriteKit rendering engine
        .target(
            name: "SpriteEngine",
            dependencies: ["Shared"],
            path: "Sources/SpriteEngine"
        ),
        // Shared models and utilities
        .target(
            name: "Shared",
            path: "Sources/Shared"
        ),
        // Tests
        .testTarget(
            name: "SharedTests",
            dependencies: ["Shared", "SpriteEngine"],
            path: "Tests/SharedTests"
        ),
    ]
)
