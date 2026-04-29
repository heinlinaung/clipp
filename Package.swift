// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Clipp",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Clipp",
            path: "Sources/Clipp"
        )
    ]
)
