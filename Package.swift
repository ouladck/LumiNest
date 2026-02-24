// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "LumiNest",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LumiNest", targets: ["LumiNest"])
    ],
    targets: [
        .executableTarget(
            name: "LumiNest",
            path: "Sources/LumiNest"
        )
    ]
)
