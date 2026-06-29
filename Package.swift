// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "zai-bar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "zai-bar",
            path: "Sources/zai-bar"
        )
    ]
)
