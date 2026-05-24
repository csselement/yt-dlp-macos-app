// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BatchDownloader",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "BatchDownloader", targets: ["BatchDownloader"])
    ],
    targets: [
        .executableTarget(
            name: "BatchDownloader",
            path: "Sources/BatchDownloader"
        )
    ]
)
