// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-100k",
    platforms: [
        .iOS(.v17),        // iOS 17.0+ for latest SwiftUI features
        .macOS(.v14),      // macOS 14.0+ for latest system APIs
        .tvOS(.v17),       // tvOS 17.0+ for latest tvOS features
        .watchOS(.v10),    // watchOS 10.0+ for latest watchOS capabilities
        .visionOS(.v1)     // visionOS 1.0+ for visionOS support
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Swift100k",
            targets: ["Swift100k"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Swift100k"
        ),

    ],
    swiftLanguageModes: [.v6]
)
