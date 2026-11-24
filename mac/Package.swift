// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AZZikr",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "AZZikr", path: "Sources/AZZikr")
    ]
)
