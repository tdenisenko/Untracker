// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Untracker",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "UntrackerCore",
            targets: ["UntrackerCore"]
        ),
        .executable(
            name: "Untracker",
            targets: ["UntrackerApp"]
        )
    ],
    targets: [
        .target(name: "UntrackerCore"),
        .executableTarget(
            name: "UntrackerApp",
            dependencies: ["UntrackerCore"]
        ),
        .testTarget(
            name: "UntrackerCoreTests",
            dependencies: ["UntrackerCore"]
        )
    ]
)
