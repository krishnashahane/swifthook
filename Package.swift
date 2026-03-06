// swift-tools-version:5.0
// SwiftHook - A Swift method hooking library
// Created by Krishna

import PackageDescription

let package = Package(
    name: "SwiftHook",
    platforms: [
        .iOS(.v11),
        .macOS(.v10_13),
        .tvOS(.v11),
        .watchOS(.v5)
    ],
    products: [
        .library(name: "SwiftHook", targets: ["SwiftHook"]),
    ],
    targets: [
        .target(name: "SuperForwarder"),
        .target(name: "SwiftHook", dependencies: ["SuperForwarder"]),
        .testTarget(name: "SwiftHookTests", dependencies: ["SwiftHook"]),
    ]
)
