// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TweetNacl",
    platforms: [
        .iOS(.v14),
        .macOS(.v12),
        .tvOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "TweetNacl",
            targets: ["TweetNacl"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.54.3"),
    ],
    targets: [
        .target(name: "CTweetNacl"),
        .target(
            name: "TweetNacl",
            dependencies: ["CTweetNacl"]),
        .testTarget(
            name: "TweetNaclTests",
            dependencies: ["TweetNacl"],
            resources: [
                .process("SecretboxTestData.json"),
                .process("BoxTestData.json"),
                .process("ScalarMultiTestData.json"),
                .process("SignTestData.json")
            ]
        ),
    ]
)
