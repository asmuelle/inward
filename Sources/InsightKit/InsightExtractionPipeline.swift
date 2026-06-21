import Foundation
import SafetyKit

/// Gates entity extraction behind the deterministic crisis gate, exactly as
/// ReflectKit gates reflections (product invariant #5): the gate runs BEFORE any
/// model call. On a crisis match no extractor is consulted at all — the entry
/// yields no entities and the safety surfaces take over. Otherwise extraction
/// flows to the wrapped extractor unchanged.
///
/// This is a decorator: it conforms to `EntityExtracting`, so any extractor
/// (Apple-Intelligence or the deterministic floor) can be wrapped transparently.
public struct InsightExtractionPipeline: EntityExtracting {
    private let gate: CrisisGate
    private let extractor: any EntityExtracting

    public init(gate: CrisisGate = CrisisGate(), extractor: any EntityExtracting) {
        self.gate = gate
        self.extractor = extractor
    }

    public func availability() async -> InsightAvailability {
        await extractor.availability()
    }

    public func extract(from entry: ExtractableEntry) async throws -> EntryInsights {
        // Deterministic gate first. A match means the model never runs and no
        // entities are derived — leaving the entry untouched is the safe default.
        guard !gate.evaluate(entry.text).isMatched else { return .empty }
        return try await extractor.extract(from: entry)
    }
}
