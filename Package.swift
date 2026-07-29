// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SystemOrganizer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SystemOrganizer", targets: ["SystemOrganizer"])
    ],
    dependencies: [
        // Sibling checkout: Documents/GitHub/PersonalOSKit (private AUTOGIO/PersonalOSKit)
        .package(path: "../PersonalOSKit")
    ],
    targets: [
        .executableTarget(
            name: "SystemOrganizer",
            dependencies: [
                .product(name: "OllamaClient", package: "PersonalOSKit"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "SystemOrganizerTests",
            dependencies: ["SystemOrganizer"],
            path: "Tests/SystemOrganizerTests"
        )
    ]
)
