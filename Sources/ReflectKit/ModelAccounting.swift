#if canImport(FoundationModels)
    import Foundation
    import FoundationModels

    /// The bridge between FoundationModels and `TokenBudgeter`: budgets from the
    /// model's real context size, typed overflow errors, and usage recording.
    /// On iOS 27 all three are exact; on iOS 26 the context size is the
    /// back-deployed 4096, overflow carries no token count, and usage is not
    /// reported — the estimator then simply stays at its pessimistic default.
    @available(iOS 26.0, macOS 26.0, *)
    enum ModelAccounting {
        /// The prompt budget left after `fixedText` (instructions plus any
        /// fixed prompt framing) and the reply reserve.
        static func promptBudget(fixedText: String, charactersPerToken ratio: Int) -> Int {
            TokenBudgeter.promptBudget(
                contextSize: SystemLanguageModel.default.contextSize,
                instructionTokens: TokenBudgeter.estimateTokens(fixedText, charactersPerToken: ratio)
            )
        }

        /// Maps a FoundationModels failure to `ReflectionError`, surfacing
        /// context overflow as its own case so callers can shrink and retry.
        static func reflectionError(from error: any Error) -> ReflectionError {
            if #available(iOS 27.0, macOS 27.0, *),
               case let LanguageModelError.contextSizeExceeded(details) = error
            {
                return .contextExceeded(contextSize: details.contextSize, tokenCount: details.tokenCount)
            }
            if case LanguageModelSession.GenerationError.exceededContextWindowSize = error {
                return .contextExceeded(contextSize: SystemLanguageModel.default.contextSize, tokenCount: 0)
            }
            return .generationFailed(String(describing: error))
        }

        /// Records what a response actually cost. Only iOS 27 reports usage;
        /// earlier systems leave the ledger untouched.
        static func record(
            _ response: LanguageModelSession.Response<some Any>,
            promptCharacters: Int,
            into ledger: TokenUsageLedger
        ) async {
            guard #available(iOS 27.0, macOS 27.0, *) else { return }
            await ledger.record(
                TokenUsageObservation(
                    promptCharacters: promptCharacters,
                    inputTokens: response.usage.input.totalTokenCount,
                    outputTokens: response.usage.output.totalTokenCount
                )
            )
        }
    }
#endif
