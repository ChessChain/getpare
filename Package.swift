// swift-tools-version: 5.10
// Pare — macOS storage cleanup, sandboxed UI + privileged XPC helper.
// See docs/Technical-Design.docx §9 for the canonical layout rationale.

import PackageDescription

let package = Package(
    name: "Pare",
    platforms: [
        .macOS(.v13) // Ventura+, per BRD NFR-03
    ],
    products: [
        .library(name: "PareKit", targets: ["PareKit"]),
        .executable(name: "Pare", targets: ["App"]),
        .executable(name: "ParePrivilegedHelper", targets: ["Helper"])
    ],
    dependencies: [
        // Pinned where mature; ranges for things we expect to track.
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
        // Sparkle is integrated via the .app bundle, not SPM. Listed here as
        // a placeholder; real wiring happens in the xcodeproj.
        // .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0")
    ],
    targets: [
        // ── Shared models, XPC contract, utilities ──────────────────────
        .target(
            name: "PareKit",
            path: "PareKit/Sources",
            swiftSettings: strictWarnings
        ),
        .testTarget(
            name: "PareKitTests",
            dependencies: ["PareKit"],
            path: "PareKit/Tests"
        ),

        // ── Privileged helper library (all logic, testable) ─────────────
        .target(
            name: "HelperLib",
            dependencies: [
                "PareKit",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Helper/Sources",
            swiftSettings: strictWarnings
        ),
        // ── Privileged helper executable (thin @main entry point) ──────
        .executableTarget(
            name: "Helper",
            dependencies: ["HelperLib", "PareKit"],
            path: "Helper/EntryPoint",
            swiftSettings: strictWarnings
        ),
        .testTarget(
            name: "HelperTests",
            dependencies: ["HelperLib", "PareKit"],
            path: "Helper/Tests"
        ),

        // ── SwiftUI app library (all views/coordinators, testable) ─────
        .target(
            name: "AppLib",
            dependencies: ["PareKit"],
            path: "App/Sources",
            resources: [
                .process("Resources/Assets.xcassets"),
                .process("Resources/Localizable.strings"),
            ],
            swiftSettings: strictWarnings
        ),
        // ── SwiftUI app executable (thin @main entry point) ───────────
        .executableTarget(
            name: "App",
            dependencies: ["AppLib", "PareKit"],
            path: "App/EntryPoint",
            swiftSettings: strictWarnings
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["AppLib", "PareKit"],
            path: "App/Tests"
        )
    ]
)

/// Treat warnings as errors in our own targets so CI catches regressions.
/// Excluded from test targets, where transient warnings are acceptable.
private let strictWarnings: [SwiftSetting] = [
    .unsafeFlags(["-warnings-as-errors"])
]
