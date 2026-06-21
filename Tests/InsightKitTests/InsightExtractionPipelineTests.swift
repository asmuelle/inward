import Foundation
@testable import InsightKit
import Testing

/// Records whether `extract` was ever invoked, so the gate's "model stays silent
/// on a crisis match" guarantee can be asserted directly.
private actor SpyExtractor: EntityExtracting {
    private(set) var extractCallCount = 0
    private let result: EntryInsights

    init(result: EntryInsights = EntryInsights(people: ["Sam"])) {
        self.result = result
    }

    func availability() async -> InsightAvailability {
        .available
    }

    func extract(from _: ExtractableEntry) async throws -> EntryInsights {
        extractCallCount += 1
        return result
    }
}

@Suite("InsightExtractionPipeline — deterministic crisis gate runs before any extractor")
struct InsightExtractionPipelineTests {
    private func entry(_ text: String) -> ExtractableEntry {
        ExtractableEntry(id: UUID(), createdAt: Date(timeIntervalSince1970: 0), text: text)
    }

    @Test("a crisis match suppresses extraction entirely — the extractor is never called")
    func crisisMatchNeverCallsExtractor() async throws {
        let spy = SpyExtractor()
        let pipeline = InsightExtractionPipeline(extractor: spy)

        let insights = try await pipeline.extract(from: entry("Some days I just want to die."))

        #expect(insights == .empty)
        #expect(await spy.extractCallCount == 0)
    }

    @Test("clear text flows through to the wrapped extractor unchanged")
    func clearTextCallsExtractor() async throws {
        let spy = SpyExtractor(result: EntryInsights(people: ["Sam"], places: ["Berlin"]))
        let pipeline = InsightExtractionPipeline(extractor: spy)

        let insights = try await pipeline.extract(from: entry("I walked through Berlin with Sam."))

        #expect(insights == EntryInsights(people: ["Sam"], places: ["Berlin"]))
        #expect(await spy.extractCallCount == 1)
    }

    @Test("availability delegates to the wrapped extractor")
    func availabilityDelegates() async {
        let pipeline = InsightExtractionPipeline(extractor: SpyExtractor())
        #expect(await pipeline.availability().isAvailable)
    }
}
