import CaptureKit
import DesignSystem
@testable import Inward
import JournalStore
import PaywallKit
import PrivacyKit
import RecallKit
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
    /// Hosting windows, retained until the test case ends — a released window
    /// tears its hierarchy down before it can be drawn.
    private var windows: [UIWindow] = []

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
        let model = PaywallModel(gateway: MockPurchaseGateway())
        await model.refresh()
        // PaywallView re-runs `refresh()` in its own `.task` on appear, so the
        // snapshot has to wait for that second load — this is the IAP screenshot
        // App Review requires, and a spinner would not pass.
        await attach("08-paywall", settling: { model.loadState == .loaded }) { PaywallView(model: model) }
    }

    func testLock() {
        attach("09-lock") { LockView(onUnlock: {}) }
    }

    // MARK: - Share cards (the artefacts users post, at their real proportions)

    func testShareCardProof() {
        attachCard("10-share-proof") { ProofShareCard(isOffline: true) }
    }

    func testShareCardThemes() {
        attachCard("11-share-themes") {
            ThemesShareCard(
                themes: ["sleep", "the move", "my father", "patience", "sunday mornings"],
                dateRange: "18–25 Jul"
            )
        }
    }

    func testShareCardMindMap() {
        attachCard("12-share-mindmap") { MindMapShareCard(graph: Self.shareGraph) }
    }

    // MARK: - Rendering

    /// Hosts the view in a real key window and snapshots the layer hierarchy, so
    /// ScrollView and NavigationStack content render (ImageRenderer leaves them
    /// blank). A short run-loop spin lets SwiftUI lay out before capture.
    private func attach(_ name: String, @ViewBuilder _ content: () -> some View) {
        let host = present(content)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        capture(name, from: host)
    }

    /// For surfaces that load asynchronously *after* appearing: a view's own
    /// `.task` restarts work the test already awaited, so a fixed spin can
    /// snapshot a placeholder. `RunLoop.run` cannot be used to wait it out — it
    /// blocks the main actor without running its jobs, so the load never
    /// progresses. Awaiting a sleep yields the actor and lets it finish.
    private func attach(
        _ name: String,
        settling settled: @escaping @MainActor () -> Bool,
        @ViewBuilder _ content: () -> some View
    ) async {
        let host = present(content)
        for _ in 0 ..< 60 where !settled() {
            try? await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(settled(), "\(name) never finished loading — the snapshot would show a placeholder")
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        try? await Task.sleep(for: .milliseconds(150))
        capture(name, from: host)
    }

    /// Hosts the view in a real key window, so ScrollView and NavigationStack
    /// content renders (ImageRenderer leaves it blank). The window is retained
    /// for the lifetime of the test case.
    private func present(@ViewBuilder _ content: () -> some View) -> UIHostingController<some View> {
        let host = UIHostingController(rootView: content().environment(\.colorScheme, .light))
        host.view.frame = CGRect(origin: .zero, size: canvas)
        host.view.backgroundColor = UIColor(Color.inwardPaper)

        let window = UIWindow(frame: CGRect(origin: .zero, size: canvas))
        window.rootViewController = host
        window.makeKeyAndVisible()
        windows.append(window)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        return host
    }

    /// Snapshots the layer hierarchy and attaches it to the test result.
    private func capture(_ name: String, from host: UIViewController) {
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

    /// Share cards are already laid out at pixel size and have no scroll or
    /// navigation content, so ImageRenderer is enough — and it renders exactly
    /// the bytes the share sheet would hand over. Halved for the docs folder.
    private func attachCard(_ name: String, @ViewBuilder _ content: () -> some View) {
        let renderer = ImageRenderer(content: content().environment(\.colorScheme, .light))
        renderer.scale = 0.5
        guard let data = renderer.uiImage?.pngData() else {
            XCTFail("failed to render \(name)")
            return
        }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Fixtures

    /// A plausible month of entities for the constellation card.
    private static let shareGraph: EntityGraph = {
        let entryIDs = (0 ..< 9).map { _ in UUID() }
        let associations = [
            ("person", 7), ("place", 6), ("topic", 6), ("object", 4),
            ("person", 4), ("topic", 3), ("place", 3), ("object", 2),
            ("topic", 2), ("person", 2), ("place", 1), ("topic", 1),
        ].enumerated().map { index, spec -> EntityAssociation in
            let kind: EntityKind = switch spec.0 {
            case "person": .person
            case "place": .place
            case "object": .object
            default: .topic
            }
            return EntityAssociation(
                entity: JournalEntity(kind: kind, name: "Fixture \(index)"),
                entryIDs: Array(entryIDs.prefix(spec.1))
            )
        }
        return EntityGraphBuilder.build(from: associations)
    }()

    private static let now = Date(timeIntervalSince1970: 1_750_000_000)

    private static func entry(_ daysAgo: Double, _ text: String) -> Entry {
        Entry(
            createdAt: now.addingTimeInterval(-daysAgo * 86400),
            source: daysAgo.truncatingRemainder(dividingBy: 2) == 0 ? .voice : .text,
            transcriptRaw: text,
            textEdited: text,
            durationSec: 38,
            locale: "en_US"
        )
    }

    /// The recurring theme ("garden") sits in each entry's first sentence, because
    /// the weekly review summarizes entries to their opening sentence.
    static let sampleEntries: [Entry] = [
        entry(0, "Garden mornings again — coffee outside before the house stirred, and for once I didn't reach for my phone."),
        entry(1, "Another slow garden morning. The light came in sideways and I just sat with it for a while."),
        entry(2, "Work pulled hard today, but my mind kept drifting back to the garden and how quiet it is out there."),
        entry(3, "Quiet evening walk past the blooming garden two doors down. Everything felt a little softer afterward."),
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
