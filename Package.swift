// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StatusCake",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "StatusCakeCore", targets: ["StatusCakeCore"]),
        .executable(name: "statuscake-cli", targets: ["statuscake-cli"])
    ],
    targets: [
        .target(name: "StatusCakeCore"),
        .executableTarget(name: "statuscake-cli", dependencies: ["StatusCakeCore"]),
        .testTarget(name: "StatusCakeCoreTests", dependencies: ["StatusCakeCore"])
    ]
)
