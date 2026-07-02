// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UsageBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "UsageBar", targets: ["UsageBar"])
    ],
    targets: [
        .executableTarget(name: "UsageBar"),
        .testTarget(name: "UsageBarTests", dependencies: ["UsageBar"])
    ]
)
