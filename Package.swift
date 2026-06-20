// swift-tools-version: 6.0
// InwardCore — the on-device core of Inward, split into the modules from DESIGN.md.
// Builds and tests on macOS via `swift test`; the iOS app shell (XcodeGen) composes the same targets.
import PackageDescription

let package = Package(
    name: "InwardCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "SafetyKit", targets: ["SafetyKit"]),
        .library(name: "JournalStore", targets: ["JournalStore"]),
        .library(name: "CaptureKit", targets: ["CaptureKit"]),
        .library(name: "PrivacyKit", targets: ["PrivacyKit"]),
        .library(name: "ReflectKit", targets: ["ReflectKit"]),
        .library(name: "RecallKit", targets: ["RecallKit"]),
        .library(name: "PaywallKit", targets: ["PaywallKit"]),
    ],
    targets: [
        // MARK: Modules

        .target(name: "DesignSystem"),
        .target(name: "SafetyKit"),
        .target(name: "JournalStore"),
        .target(name: "CaptureKit", dependencies: ["JournalStore", "DesignSystem"]),
        .target(name: "PrivacyKit", dependencies: ["JournalStore"]),
        .target(name: "ReflectKit", dependencies: ["SafetyKit"]),
        .target(name: "RecallKit", dependencies: ["JournalStore"]),
        .target(name: "PaywallKit"),

        // MARK: Tests

        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem", "SafetyKit"]),
        .testTarget(
            name: "SafetyKitTests",
            dependencies: ["SafetyKit"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "JournalStoreTests", dependencies: ["JournalStore"]),
        .testTarget(name: "CaptureKitTests", dependencies: ["CaptureKit", "JournalStore"]),
        .testTarget(name: "PrivacyKitTests", dependencies: ["PrivacyKit", "CaptureKit", "JournalStore"]),
        .testTarget(name: "ReflectKitTests", dependencies: ["ReflectKit", "SafetyKit"]),
        .testTarget(name: "RecallKitTests", dependencies: ["RecallKit"]),
        .testTarget(name: "PaywallKitTests", dependencies: ["PaywallKit"]),
        .testTarget(name: "ComplianceTests", dependencies: ["SafetyKit", "DesignSystem"]),
    ]
)
