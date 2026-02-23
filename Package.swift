// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "MacMediaGallery",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacMediaGalleryApp", targets: ["MacMediaGalleryApp"])
    ],
    targets: [
        .executableTarget(
            name: "MacMediaGalleryApp",
            path: "Sources/MacMediaGalleryApp"
        )
    ]
)
