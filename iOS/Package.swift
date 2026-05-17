// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BDUIClient",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "BDUIClient", targets: ["BDUIClient"]),
    ],
    targets: [
        .target(name: "BDUIClient"),
        .testTarget(name: "BDUIClientTests", dependencies: ["BDUIClient"]),
    ]
)
