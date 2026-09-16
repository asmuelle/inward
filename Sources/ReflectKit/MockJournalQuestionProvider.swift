import Foundation

/// Deterministic question provider for tests and previews. It cites exactly the
/// retrieved entries that share a meaningful word with the question, so its
/// answers are grounded by construction; when no entry shares a word it reports
/// the question as unanswered. No model, no randomness.
public struct MockJournalQuestionProvider: JournalQuestionProviding {
    static let minWordLength = 4

    public init() {}

    public func availability() async -> ReflectionAvailability {
        .available
    }

    public func answer(for context: QuestionContext) async throws -> JournalAnswerDraft {
        let questionWords = Self.words(in: context.question)
        let matching = context.entries.filter { entry in
            !Self.words(in: entry.summary).isDisjoint(with: questionWords)
        }
        guard !matching.isEmpty else {
            return JournalAnswerDraft(answer: "", citedEntryIds: [], isUnanswered: true)
        }
        let shared = questionWords
            .intersection(matching.flatMap { Self.words(in: $0.summary) })
            .sorted()
            .joined(separator: ", ")
        let count = matching.count == 1 ? "one of your entries" : "\(matching.count) of your entries"
        return JournalAnswerDraft(
            answer: "You wrote about \(shared) in \(count).",
            citedEntryIds: matching.map(\.id)
        )
    }

    private static func words(in text: String) -> Set<String> {
        Set(
            text.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { $0.count >= minWordLength && !WeeklyReviewPipeline.stopwords.contains($0) }
        )
    }
}
