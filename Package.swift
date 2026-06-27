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
        .library(name: "JournalStoreSQLCipher", targets: ["JournalStoreSQLCipher"]),
        .library(name: "QuickCaptureKit", targets: ["QuickCaptureKit"]),
        .library(name: "InsightKit", targets: ["InsightKit"]),
    ],
    dependencies: [
        // GRDB packaged with SQLCipher Community Edition as an XCFramework, the
        // only clean way to get encrypted SQLite over SwiftPM (GRDB 7.4.1 +
        // SQLCipher 4.7.0). Pinned exactly because it is the at-rest crypto layer.
        .package(url: "https://github.com/thebrowsercompany/GRDB.swift", exact: "3.0.1"),
    ],
    targets: [
        // MARK: Modules

        .target(name: "DesignSystem"),
        .target(name: "SafetyKit"),
        .target(name: "JournalStore"),
        .target(
            name: "JournalStoreSQLCipher",
            dependencies: ["JournalStore", .product(name: "GRDB", package: "GRDB.swift")]
        ),
        // SafetyKit: the spoken-summary confirm loop routes every generated
        // recap and clarification through the same crisis gate + banned-terms
        // validation as reflection, so the model is never reached during a crisis
        // and its output is bounded before it is ever spoken.
        .target(name: "CaptureKit", dependencies: ["JournalStore", "DesignSystem", "SafetyKit"]),
        .target(name: "PrivacyKit", dependencies: ["JournalStore"]),
        .target(name: "ReflectKit", dependencies: ["SafetyKit"]),
        .target(name: "RecallKit", dependencies: ["JournalStore"]),
        .target(name: "PaywallKit"),
        // Shared by the app and the widget/control extension so the App Intent
        // type is identical across processes.
        .target(name: "QuickCaptureKit"),
        // On-device entity/topic extraction. Depends on SafetyKit (TextNormalizer)
        // for verification; never on JournalStore — the app maps Entry down.
        .target(name: "InsightKit", dependencies: ["SafetyKit"]),

        // MARK: Tests

        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem", "SafetyKit"]),
        .testTarget(
            name: "SafetyKitTests",
            dependencies: ["SafetyKit"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "JournalStoreTests", dependencies: ["JournalStore"]),
        .testTarget(
            name: "JournalStoreSQLCipherTests",
            dependencies: ["JournalStoreSQLCipher", "JournalStore"]
        ),
        .testTarget(name: "CaptureKitTests", dependencies: ["CaptureKit", "JournalStore", "SafetyKit"]),
        .testTarget(name: "PrivacyKitTests", dependencies: ["PrivacyKit", "CaptureKit", "JournalStore"]),
        .testTarget(name: "ReflectKitTests", dependencies: ["ReflectKit", "SafetyKit"]),
        .testTarget(name: "RecallKitTests", dependencies: ["RecallKit"]),
        .testTarget(name: "PaywallKitTests", dependencies: ["PaywallKit"]),
        .testTarget(name: "QuickCaptureKitTests", dependencies: ["QuickCaptureKit"]),
        .testTarget(name: "InsightKitTests", dependencies: ["InsightKit"]),
        .testTarget(name: "ComplianceTests", dependencies: ["SafetyKit", "DesignSystem"]),
    ]
)
