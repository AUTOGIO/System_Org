// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SystemOrganizer",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // CloudKit is part of Foundation on macOS
    ],
    targets: [
        .executableTarget(
            name: "SystemOrganizer",
            dependencies: [],
            path: "Sources"
        )
    ]
)
