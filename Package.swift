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
            targets: ["MessageUI100k"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "MessageUI100k",
            url: "https://github.com/NguyenPhongVN/swift-100k/releases/download/1.0.0/MessageUI100k.xcframework.zip",
            checksum: "358a34a33ecfe3517a237219c2573fa107fda4fdbafce6d5e6cb953e8cd35c81"
        )
    ]
)
