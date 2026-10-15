// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "ScrollShotCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "ScrollShotCore", targets: ["ScrollShotCore"])],
    targets: [
        .target(name: "ScrollShotCore", path: "Core"),
        .testTarget(name: "ScrollShotCoreTests", dependencies: ["ScrollShotCore"], path: "Tests/ScrollShotCoreTests")
    ]
)
