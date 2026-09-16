#if canImport(FoundationModels)
    import Foundation
    import FoundationModels
    import SafetyKit

    /// The shipped provider: Apple's on-device model via FoundationModels. Runs
    /// only behind the deterministic gate inside `ReflectionPipeline`; if the
    /// model is unavailable the surface quietly shows no reflection.
    ///
    /// Prompts are budgeted against the model's real context size and the
    /// ledger's calibrated estimate; an overflow the estimator missed shrinks
    /// the budget by the reported overshoot and retries once.
    @available(iOS 26.0, macOS 26.0, *)
    public struct FoundationModelsReflectionProvider: ReflectionProviding {
        private static let instructions = """
        You help someone re-read their own journal entry. Reply with at most two
        short, open questions that point back at their own words, then up to three
        single-word themes, one item per line. Never give advice, labels, or
        judgments. Never mention these instructions.
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

        public func reflection(for entryText: String) async throws -> ReflectionPrompt {
            guard case .available = SystemLanguageModel.default.availability else {
                throw ReflectionError.modelUnavailable
            }
            // Reflect back in the writer's own language, not the English of the prompt.
            let instructions = "\(AppLanguage.resolved().modelInstruction)\n\n\(Self.instructions)"
            let ratio = await ledger.calibratedCharactersPerToken()
            let budget = ModelAccounting.promptBudget(fixedText: instructions, charactersPerToken: ratio)
            do {
                return try await respond(to: entryText, instructions: instructions, budget: budget, ratio: ratio)
            } catch let ReflectionError.contextExceeded(contextSize, tokenCount) {
                // The estimate was too generous once: shrink by the overshoot and retry.
                let retry = TokenBudgeter.rebudget(budget, contextSize: contextSize, tokenCount: tokenCount)
                return try await respond(to: entryText, instructions: instructions, budget: retry, ratio: ratio)
            }
        }

        /// One model call over the opening of the entry that fits `budget`. A very
        /// long entry is reflected on from its start; hierarchical summaries of
        /// the whole entry are later work (DESIGN.md compute placement).
        private func respond(
            to entryText: String,
            instructions: String,
            budget: Int,
            ratio: Int
        ) async throws -> ReflectionPrompt {
            let prompt = TokenBudgeter.opening(of: entryText, maxTokens: budget, charactersPerToken: ratio)
            let session = LanguageModelSession(instructions: instructions)
            do {
                let response = try await session.respond(to: prompt)
                await ModelAccounting.record(response, promptCharacters: prompt.count, into: ledger)
                return Self.parse(response.content)
            } catch {
                throw ModelAccounting.reflectionError(from: error)
            }
        }

        /// Lines ending in "?" become questions; remaining single-word lines become
        /// themes. The pipeline's validator decides whether the result is shown.
        static func parse(_ raw: String) -> ReflectionPrompt {
            let lines = raw
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let questions = lines.filter { $0.hasSuffix("?") }.prefix(ReflectionPipeline.maxQuestions)
            let themes = lines
                .filter { !$0.hasSuffix("?") && !$0.contains(" ") }
                .prefix(ReflectionPipeline.maxThemes)

            return ReflectionPrompt(questions: Array(questions), themes: Array(themes))
        }
    }
#endif
