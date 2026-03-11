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
        // 外部ライブラリが必要になったらここに追加
    ],
    targets: [
        .executableTarget(
            name: "AwesomeVideoPlayer",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)

