// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "n42-swift-checker",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "n42-swift-checker", targets: ["n42-swift-checker"]),
        .library(name: "SwiftChecker", targets: ["SwiftChecker"]),
    ],
    dependencies: [
        // Apache-2.0. Apple's Swift parser; the same version the app repos use for their macros.
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0"),
        // Apache-2.0
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "SwiftChecker",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .executableTarget(
            name: "n42-swift-checker",
            dependencies: [
                "SwiftChecker",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "SwiftCheckerTests",
            dependencies: ["SwiftChecker"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
