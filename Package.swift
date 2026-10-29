// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-100k",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "Swift100k",
            targets: ["Swift100k"]
        ),
    ],
    targets: [
        // Re-export target so consumers can `import Swift100k`.
        .target(
            name: "Swift100k",
            dependencies: ["MessageUI100k"]
        ),
        .binaryTarget(
            name: "MessageUI100k",
            url: "https://github.com/NguyenPhongVN/swift-100k/releases/download/1.1.0/MessageUI100k.xcframework.zip",
            checksum: "403d476384df9004924a1378545af69cea2cbbf265b9ccb153c089c94b3afe93"
        )
    ]
)
