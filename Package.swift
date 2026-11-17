// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Brow",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6"),
    ],
    targets: [
        .executableTarget(
            name: "Brow",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Brow",
            linkerSettings: [
                // Brow.app embeds Sparkle.framework in Contents/Frameworks.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        )
    ]
)
