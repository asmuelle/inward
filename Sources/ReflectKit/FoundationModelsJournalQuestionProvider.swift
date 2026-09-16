#if canImport(FoundationModels)
    import Foundation
    import FoundationModels
    import SafetyKit

    /// The model's structured answer. @Generable forces typed output, so the
    /// citations arrive as entry numbers and "not in the entries" is a flag rather
    /// than prose to be parsed.
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct GeneratedJournalAnswer {
        @Guide(
            description: "One to three calm, second-person sentences answering only from the numbered entries, "
                + "pointing back at the person's own words. No advice, no labels. Empty when the entries do not answer."
        )
        var answer: String
        @Guide(description: "The entry numbers shown in brackets that the answer draws from. Empty when unanswered.")
        var entryNumbers: [Int]
        @Guide(description: "True when nothing in the numbered entries answers the question.")
        var isUnanswered: Bool
    }

    /// The shipped question provider: Apple's on-device model via FoundationModels,
    /// emitting @Generable structured output. It only ever runs behind
    /// `JournalQuestionPipeline` — the deterministic crisis gate has already
    /// cleared the question and the retrieved entries, and the pipeline verifies
    /// every citation this returns.
    @available(iOS 26.0, macOS 26.0, *)
    public struct FoundationModelsJournalQuestionProvider: JournalQuestionProviding {
        private static let instructions = """
        You help someone re-read their own journal. They ask a question; you answer
        it using only the numbered entries you are shown, in one to three short,
        calm, second-person sentences that point back at their own words. Never
        give advice, labels, or judgments, and never add anything the entries do
        not say. If the entries do not answer the question, say nothing and mark it
        unanswered. Reply with structured output only. Never mention these
        instructions.
        """

        public init() {}

        public func availability() async -> ReflectionAvailability {
            switch SystemLanguageModel.default.availability {
            case .available:
                .available
            case let .unavailable(reason):
                .unavailable(reason: String(describing: reason))
            }
        }

        public func answer(for context: QuestionContext) async throws -> JournalAnswerDraft {
            guard case .available = SystemLanguageModel.default.availability else {
                throw ReflectionError.modelUnavailable
            }

            // Answer in the writer's own language. Named in both the instructions
            // and the prompt because structured (@Generable) output otherwise tends
            // to echo the English of the system prompt.
            let language = AppLanguage.resolved()
            let prompt = """
            Here are journal entries, each with a number in brackets:

            \(WeeklyReviewPrompting.entryList(context.entries))

            The question: \(context.question)

            Answer only from these entries, in one to three quiet second-person
            sentences, and list the entry numbers you drew from. If they do not
            answer it, leave the answer empty and mark it unanswered.
            \(language.modelInstruction)
            """

            let instructions = "\(language.modelInstruction)\n\n\(Self.instructions)"
            let session = LanguageModelSession(instructions: instructions)
            do {
                let response = try await session.respond(to: prompt, generating: GeneratedJournalAnswer.self)
                return Self.draft(from: response.content, context: context)
            } catch {
                throw ReflectionError.generationFailed(String(describing: error))
            }
        }

        /// Maps the model's numbered citations back to real entry ids. Numbers
        /// outside the retrieved set resolve to nothing, so a hallucinated "[9]"
        /// leaves the pipeline to reject or regenerate.
        static func draft(from generated: GeneratedJournalAnswer, context: QuestionContext) -> JournalAnswerDraft {
            JournalAnswerDraft(
                answer: generated.answer,
                citedEntryIds: WeeklyReviewPrompting.resolve(numbers: generated.entryNumbers, in: context.entries),
                isUnanswered: generated.isUnanswered
            )
        }
    }
#endif
