// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AwesomeVideoPlayer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AwesomeVideoPlayer",
            targets: ["AwesomeVideoPlayer"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/tylerjonesio/vlckit-spm.git", from: "3.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "AwesomeVideoPlayer",
            dependencies: [.product(name: "VLCKitSPM", package: "vlckit-spm")],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)

