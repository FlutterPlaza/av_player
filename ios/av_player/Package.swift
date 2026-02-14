// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "av_player",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "av-player", targets: ["av_player"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "av_player",
            dependencies: [],
            resources: []
        )
    ]
)
