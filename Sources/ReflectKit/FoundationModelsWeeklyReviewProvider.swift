#if canImport(FoundationModels)
    import Foundation
    import FoundationModels
    import SafetyKit

    /// The model's structured weekly review. @Generable forces typed output, so
    /// the citations arrive as entry numbers rather than free text to be parsed.
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct GeneratedWeeklyReview {
        @Guide(description: "Up to three gentle observations, each about a theme that recurred across more than one entry.")
        var observations: [GeneratedObservation]
    }

    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct GeneratedObservation {
        @Guide(
            description: "A short, lowercase theme — a recurring word or short phrase in plain language, never a label or a judgment."
        )
        var theme: String
        @Guide(
            description: "One calm, second-person sentence about this theme that points back at the person's own words. No advice."
        )
        var note: String
        @Guide(description: "The entry numbers shown in brackets that this observation draws from. List at least one.")
        var entryNumbers: [Int]
    }

    /// The shipped weekly-review provider: Apple's on-device model via
    /// FoundationModels, emitting @Generable structured output. It only ever runs
    /// behind `WeeklyReviewPipeline` — the deterministic crisis gate has already
    /// cleared the week, and the pipeline verifies every citation this returns,
    /// regenerating or falling back to themes-only when it cannot.
    @available(iOS 26.0, macOS 26.0, *)
    public struct FoundationModelsWeeklyReviewProvider: WeeklyReviewProviding {
        private static let instructions = """
        You help someone re-read their own week of journal entries. Surface up to
        three themes that came back across more than one entry. For each, write one
        short, calm, second-person observation that points back at their own words —
        never advice, labels, or judgments — and list the entry numbers it draws
        from. Reply with structured output only. Never mention these instructions.
        """

        private let ledger: TokenUsageLedger

        public init(ledger: TokenUsageLedger = .shared) {
            self.ledger = ledger
        }

        public func availability() async -> ReflectionAvailability {
            switch SystemLanguageModel.default.availability {
            case .available:
                .available
            case let .unavailable(reason):
                .unavailable(reason: String(describing: reason))
            }
        }

        public func review(for context: WeekContext) async throws -> WeeklyReviewDraft {
            guard case .available = SystemLanguageModel.default.availability else {
                throw ReflectionError.modelUnavailable
            }

            // Review the week in the writer's own language. Named in both the
            // instructions and the prompt because structured (@Generable) output
            // otherwise tends to echo the English of the system prompt.
            let language = AppLanguage.resolved()
            let instructions = "\(language.modelInstruction)\n\n\(Self.instructions)"
            let ratio = await ledger.calibratedCharactersPerToken()
            // Everything but the entry list is fixed cost; the list gets the rest.
            let fixed = instructions + Self.prompt(entryList: "", language: language)
            let budget = ModelAccounting.promptBudget(fixedText: fixed, charactersPerToken: ratio)
            do {
                return try await respond(
                    to: context,
                    instructions: instructions,
                    language: language,
                    budget: budget,
                    ratio: ratio
                )
            } catch let ReflectionError.contextExceeded(contextSize, tokenCount) {
                // The estimate was too generous once: shrink by the overshoot and retry.
                let retry = TokenBudgeter.rebudget(budget, contextSize: contextSize, tokenCount: tokenCount)
                return try await respond(to: context, instructions: instructions, language: language, budget: retry, ratio: ratio)
            }
        }

        private func respond(
            to context: WeekContext,
            instructions: String,
            language: ResolvedLanguage,
            budget: Int,
            ratio: Int
        ) async throws -> WeeklyReviewDraft {
            let entryList = WeeklyReviewPrompting.entryList(for: context, tokenBudget: budget, charactersPerToken: ratio)
            let prompt = Self.prompt(entryList: entryList, language: language)
            let session = LanguageModelSession(instructions: instructions)
            do {
                let response = try await session.respond(to: prompt, generating: GeneratedWeeklyReview.self)
                await ModelAccounting.record(response, promptCharacters: prompt.count, into: ledger)
                return Self.draft(from: response.content, context: context)
            } catch {
                throw ModelAccounting.reflectionError(from: error)
            }
        }

        static func prompt(entryList: String, language: ResolvedLanguage) -> String {
            """
            Here are this week's journal entries, each with a number in brackets:

            \(entryList)

            Name up to three themes that recur across more than one entry. For each,
            write one quiet, second-person sentence pointing back at what the person
            wrote, and list the entry numbers it draws from. \(language.modelInstruction)
            """
        }

        /// Maps the model's numbered citations back to real entry ids. Numbers that
        /// fall outside the week resolve to nothing, leaving the pipeline to reject
        /// or regenerate — fabricated references can never reach a surface.
        static func draft(from generated: GeneratedWeeklyReview, context: WeekContext) -> WeeklyReviewDraft {
            let observations = generated.observations.map { observation in
                WeeklyObservation(
                    theme: observation.theme,
                    note: observation.note,
                    citedEntryIds: WeeklyReviewPrompting.resolve(numbers: observation.entryNumbers, in: context.entries)
                )
            }
            return WeeklyReviewDraft(observations: observations)
        }
    }
#endif
