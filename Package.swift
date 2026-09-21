// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ToolbarKit",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "ToolbarKit", targets: ["ToolbarKit"]),
    ],
    targets: [
        .target(name: "ToolbarKit"),
        .testTarget(name: "ToolbarKitTests", dependencies: ["ToolbarKit"]),
    ]
)
