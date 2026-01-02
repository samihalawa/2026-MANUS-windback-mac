// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AutoRecall",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AutoRecall", targets: ["AutoRecall"])
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "AutoRecall",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin"),
            ],
            resources: [
                .process("Resources"),
                .process("Assets.xcassets"),
                .process("AutoRecall.entitlements"),
                .process("app_icon.svg"),
                .process("icon.svg")
            ]
        ),
        .testTarget(
            name: "AutoRecallTests",
            dependencies: ["AutoRecall"]
        )
    ]
) 