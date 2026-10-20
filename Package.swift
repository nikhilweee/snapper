// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Snapper",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Snapper", targets: ["Snapper"])],
    targets: [
        .target(name: "SnapperCore"),
        .executableTarget(name: "Snapper", dependencies: ["SnapperCore"]),
        .testTarget(name: "SnapperCoreTests", dependencies: ["SnapperCore"]),
        .testTarget(name: "SnapperTests", dependencies: ["Snapper"])
    ],
    swiftLanguageModes: [.v5]
)
