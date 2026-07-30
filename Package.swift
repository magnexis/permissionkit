// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PermissionKit",
    platforms: [.iOS(.v15), .macOS(.v12), .watchOS(.v8), .tvOS(.v15), .visionOS(.v1)],
    products: [
        .library(name: "PermissionKit", targets: ["PermissionKit"]),
        .library(name: "PermissionKitUI", targets: ["PermissionKitUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0")
    ],
    targets: [
        .target(name: "PermissionKit"),
        .target(name: "PermissionKitUI", dependencies: ["PermissionKit"]),
        .testTarget(name: "PermissionKitTests", dependencies: ["PermissionKit"])
    ]
)
