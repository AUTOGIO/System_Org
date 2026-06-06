// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SystemOrganizer",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SystemOrganizer",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "SystemOrganizerTests",
            dependencies: ["SystemOrganizer"],
            path: "Tests/SystemOrganizerTests"
        )
    ]
)
