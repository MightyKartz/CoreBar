// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoreBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CoreBar", targets: ["CoreBar"])
    ],
    targets: [
        .executableTarget(name: "CoreBar"),
        .testTarget(name: "CoreBarTests", dependencies: ["CoreBar"])
    ]
)
