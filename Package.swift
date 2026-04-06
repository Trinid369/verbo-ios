// swift-tools-version: 5.10
// Package.swift â VERBO Multiagente iOS
// Trinid Â© 2026

import PackageDescription

let package = Package(
    name: "VERBOApp",
    defaultLocalization: "pt",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .executable(name: "VERBOApp", targets: ["VERBOApp"])
    ],
    dependencies: [
        // No external dependencies â all local / Apple frameworks
    ],
    targets: [
        .executableTarget(
            name: "VERBOApp",
            path: "Sources/VERBOApp",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .unsafeFlags(["-warn-concurrency"])
            ]
        )
    ]
)
