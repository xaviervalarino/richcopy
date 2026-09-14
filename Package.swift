// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "richcopy",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .target(name: "RichcopyCore"),
        .executableTarget(name: "richcopy", dependencies: ["RichcopyCore"]),
        .testTarget(name: "RichcopyTests", dependencies: ["RichcopyCore"]),
    ]
)
