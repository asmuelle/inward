import CaptureKit
import DesignSystem
@testable import Inward
import JournalStore
import PaywallKit
import PrivacyKit
import ReflectKit
import SwiftUI
import UIKit
import XCTest

/// Renders the real production surfaces to PNGs via ImageRenderer and attaches
/// them to the test result. They are extracted to docs/screenshots/ afterwards.
/// This is a visual pass (deterministic snapshots of the actual SwiftUI views with
/// seeded data), not a UI-automation run.
@MainActor
final class ScreenshotTests: XCTestCase {
    private let canvas = CGSize(width: 393, height: 852)

    // MARK: - Surfaces

    func testOnboarding() {
        attach("01-onboarding") { OnboardingView(onDone: {}) }
    }

    func testTimeline() {
        attach("02-timeline") {
            ZStack(alignment: .top) {
                Color.inwardPaper
                ScrollView {
                    LazyVStack(spacing: Lamplight.Spacing.block) {
                        ForEach(Self.sampleEntries) { TimelineRow(entry: $0) }
                    }
                    .padding(Lamplight.Spacing.block)
                }
            }
        }
    }

    func testEntryDetail() {
        attach("03-entry-detail") { EntryDetailView(entry: Self.sampleEntries[0]) }
    }

    func testCapture() {
        let store = Self.makeStore()
        attach("04-capture") {
            CaptureView(coordinator: CaptureCoordinator(engine: nil, store: store)) {}
        }
    }

    func testWeeklyReview() async throws {
        let store = try await Self.seededStore()
        let model = WeeklyReviewModel(
            store: store,
            provider: MockWeeklyReviewProvider(),
            referenceDate: Self.now
        )
        await model.load()
        attach("05-weekly-review") { WeeklyReviewView(model: model) }
    }

    func testSettings() {
        let store = Self.makeStore()
        attach("06-settings") { SettingsView(store: store) }
    }

    func testExport() {
        let store = Self.makeStore()
        attach("07-export") { ExportView(store: store) }
    }

    func testPaywall() async {
        let model = PaywallModel(gateway: MockPurchaseGateway(), trialStartedAt: .distantPast)
        await model.refresh()
        attach("08-paywall") { PaywallView(model: model) }
    }

    func testLock() {
        attach("09-lock") { LockView(onUnlock: {}) }
    }

    // MARK: - Rendering

    /// Hosts the view in a real key window and snapshots the layer hierarchy, so
    /// ScrollView and NavigationStack content render (ImageRenderer leaves them
    /// blank). A short run-loop spin lets SwiftUI lay out before capture.
    private func attach(_ name: String, @ViewBuilder _ content: () -> some View) {
        let host = UIHostingController(rootView: content().environment(\.colorScheme, .light))
        host.view.frame = CGRect(origin: .zero, size: canvas)
        host.view.backgroundColor = UIColor(Color.inwardPaper)

        let window = UIWindow(frame: CGRect(origin: .zero, size: canvas))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        guard let data = image.pngData() else {
            XCTFail("failed to render \(name)")
            return
        }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Fixtures

    private static let now = Date(timeIntervalSince1970: 1_750_000_000)

    private static func entry(_ daysAgo: Double, _ text: String) -> Entry {
        Entry(
            createdAt: now.addingTimeInterval(-daysAgo * 86_400),
            source: daysAgo.truncatingRemainder(dividingBy: 2) == 0 ? .voice : .text,
            transcriptRaw: text,
            textEdited: text,
            durationSec: 38,
            locale: "en_US"
        )
    }

    static let sampleEntries: [Entry] = [
        entry(0, "Slow morning. Coffee on the balcony before the house woke up, and for once I didn't reach for my phone."),
        entry(1, "The garden is finally coming back. Mornings out there feel like the calmest part of the day."),
        entry(2, "Long stretch of work, but I noticed I kept coming back to the same worry about the move."),
        entry(3, "Walked the long way home. Quiet streets, and that garden two doors down is somehow always blooming."),
    ]

    private static func makeStore() -> EncryptedFileJournalStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shots-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("journal.inward")
        return EncryptedFileJournalStore(fileURL: url, keyProvider: StaticKeyProvider.random())
    }

    private static func seededStore() async throws -> EncryptedFileJournalStore {
        let store = makeStore()
        for entry in sampleEntries {
            try await store.save(entry: entry, transcription: nil)
        }
        return store
    }
}
