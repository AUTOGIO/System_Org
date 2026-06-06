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
        .package(path: "/Users/giovannini_nuovo/Developer/PersonalOSKit")
    ],
    targets: [
        .executableTarget(
            name: "SystemOrganizer",
            dependencies: [
                .product(name: "ShellRunner", package: "PersonalOSKit"),
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
