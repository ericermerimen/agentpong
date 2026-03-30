// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentPong",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1"),
    ],
    targets: [
        // Main app
        .executableTarget(
            name: "AgentPong",
            dependencies: [
                "SpriteEngine",
                "Shared",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
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
