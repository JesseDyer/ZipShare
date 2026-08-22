// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ZipShare",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ZipShare",
            path: "Sources/ZipShare"
        )
    ]
)
