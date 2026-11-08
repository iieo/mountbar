// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MountBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MountBar",
            path: "Sources/MountBar",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
