// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WelcomeToJPG",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "WelcomeToJPGCore",
            targets: ["WelcomeToJPGCore"]
        ),
        .executable(
            name: "WelcomeToJPGApp",
            targets: ["WelcomeToJPGApp"]
        ),
    ],
    targets: [
        .target(
            name: "WelcomeToJPGCore",
            path: "Sources/HolyConverterCore"
        ),
        .executableTarget(
            name: "WelcomeToJPGApp",
            dependencies: ["WelcomeToJPGCore"],
            path: "Sources/HolyConverterApp"
        ),
        .testTarget(
            name: "WelcomeToJPGCoreTests",
            dependencies: ["WelcomeToJPGCore"],
            path: "Tests/HolyConverterCoreTests"
        ),
    ]
)
