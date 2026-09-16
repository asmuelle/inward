import Foundation

/// What one model call actually cost: characters sent, tokens the model
/// counted. Counts only — no text ever lives here, so the ledger holds nothing
/// that could identify an entry.
public struct TokenUsageObservation: Sendable, Equatable {
    public let promptCharacters: Int
    public let inputTokens: Int
    public let outputTokens: Int

    public init(promptCharacters: Int, inputTokens: Int, outputTokens: Int) {
        self.promptCharacters = promptCharacters
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

/// Real accounting on top of the pessimistic estimator. iOS 27 reports the
/// model's context size and per-response token usage; these helpers turn that
/// into a prompt budget, shrink it after an overflow, and tighten the estimate
/// from what the model actually counted. Nothing here ever loosens the estimate
/// beyond the default — measured usage can only make the budget stricter.
public extension TokenBudgeter {
    /// Tokens kept free for the model's reply.
    static let responseReserve = 512
    /// Fraction of the reported overshoot ratio kept after an overflow, so the
    /// retry lands under the window rather than exactly on it.
    static let rebudgetHeadroom = 0.9

    /// The prompt budget: the model's context minus the instructions and a
    /// reserve for the reply. Never below one token.
    static func promptBudget(contextSize: Int, instructionTokens: Int, responseReserve: Int = responseReserve) -> Int {
        max(1, contextSize - instructionTokens - responseReserve)
    }

    /// Estimation with an explicit characters-per-token ratio (see
    /// `calibratedCharactersPerToken`). A smaller ratio is a stricter estimate.
    static func estimateTokens(_ text: String, charactersPerToken ratio: Int) -> Int {
        guard !text.isEmpty else { return 0 }
        return max(1, Int((Double(text.count) / Double(max(1, ratio))).rounded(.up)))
    }

    /// The budget to retry with after the model reported an overflow. Scales
    /// by the reported overshoot (with headroom) when the model said how far
    /// over the prompt was; halves when it did not. Strictly smaller whenever
    /// the budget is above one token, the floor.
    static func rebudget(_ budget: Int, contextSize: Int, tokenCount: Int) -> Int {
        guard contextSize > 0, tokenCount > contextSize else { return max(1, budget / 2) }
        let scaled = Double(budget) * Double(contextSize) / Double(tokenCount) * rebudgetHeadroom
        return max(1, min(budget - 1, Int(scaled.rounded(.down))))
    }

    /// The strictest characters-per-token ratio the model has actually shown,
    /// capped at the default (the estimate never gets looser) and floored at
    /// one. Input tokens include the instructions, so the ratio errs strict.
    static func calibratedCharactersPerToken(from observations: [TokenUsageObservation]) -> Int {
        let ratios = observations
            .filter { $0.inputTokens > 0 && $0.promptCharacters > 0 }
            .map { $0.promptCharacters / $0.inputTokens }
        guard let strictest = ratios.min() else { return charactersPerToken }
        return max(1, min(charactersPerToken, strictest))
    }

    /// The opening of `text` that fits `maxTokens` under the given ratio, cut
    /// on a sentence or word boundary. Never empty for non-blank input.
    static func opening(of text: String, maxTokens: Int, charactersPerToken ratio: Int) -> String {
        // `chunk` estimates with the default ratio; express the budget in those
        // units so a stricter ratio shrinks the allowance proportionally.
        let defaultUnits = max(1, maxTokens * max(1, ratio) / charactersPerToken)
        return chunk(text, maxTokens: defaultUnits).first ?? text
    }
}

/// In-memory record of recent model calls, used to calibrate the estimator.
/// Bounded, process-lifetime only, and holds counts, not content.
public actor TokenUsageLedger {
    public static let shared = TokenUsageLedger()
    public static let defaultCapacity = 32

    private let capacity: Int
    private var observations: [TokenUsageObservation] = []

    public init(capacity: Int = TokenUsageLedger.defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    public func record(_ observation: TokenUsageObservation) {
        observations = Array((observations + [observation]).suffix(capacity))
    }

    public func snapshot() -> [TokenUsageObservation] {
        observations
    }

    public func calibratedCharactersPerToken() -> Int {
        TokenBudgeter.calibratedCharactersPerToken(from: observations)
    }
}
