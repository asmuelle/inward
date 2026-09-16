import Foundation
import JournalStore
import ReflectKit
import SafetyKit

/// Asking the journal a question: takes the timeline's search results as the
/// retrieved candidates, runs them through the verified-citation pipeline, and
/// keeps an id→entry lookup so citations open the original entries. Stateless
/// between questions by design — each ask stands alone, so this never becomes
/// a conversation. Read-only; never writes.
@MainActor
@Observable
final class AskJournalModel {
    enum State: Equatable {
        case idle
        case asking
        case answered(JournalQuestionOutcome)
    }

    /// Retrieved entries handed to the model, best match first. The pipeline's
    /// token budget trims further; the ranking decides what survives.
    static let maxRetrieved = 8

    private(set) var state: State = .idle
    private(set) var entriesByID: [UUID: Entry] = [:]

    private let provider: any JournalQuestionProviding
    private let gate: CrisisGate

    init(provider: any JournalQuestionProviding, gate: CrisisGate = CrisisGate(localizedFor: .current)) {
        self.provider = provider
        self.gate = gate
    }

    /// Asks `question` over `candidates` (already ranked by RecallModel). The
    /// crisis gate, the model, and the grounding check all run inside the pipeline.
    func ask(_ question: String, candidates: [Entry]) async {
        let retrieved = Array(candidates.prefix(Self.maxRetrieved))
        entriesByID = Dictionary(retrieved.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        state = .asking

        let context = QuestionContext(question: question, entries: retrieved.map(WeeklyReviewModel.reviewable))
        let outcome = await JournalQuestionPipeline(gate: gate, provider: provider).answer(for: context)
        state = .answered(outcome)
    }

    func reset() {
        state = .idle
        entriesByID = [:]
    }

    func entry(for id: UUID) -> Entry? {
        entriesByID[id]
    }
}
