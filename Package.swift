// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "richcopy",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .target(name: "RichcopyCore"),
        .executableTarget(
            name: "richcopy",
            dependencies: [
                "RichcopyCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "RichcopyTests", dependencies: ["RichcopyCore"]),
    ]
)
