import Foundation

/// Categories the deterministic gate recognizes. Deliberately coarse: the gate's
/// only job is to decide "model stays silent, static resources appear."
public enum CrisisCategory: String, Sendable, Codable, CaseIterable {
    case selfHarm
    case harmFromOthers
    case overdose
}

public struct GateMatch: Sendable, Equatable {
    public let category: CrisisCategory
    public let phrase: String

    public init(category: CrisisCategory, phrase: String) {
        self.category = category
        self.phrase = phrase
    }
}

public enum GateDecision: Sendable, Equatable {
    case clear
    case matched(matches: [GateMatch], resources: [SupportResource])

    public var isMatched: Bool {
        if case .matched = self { return true }
        return false
    }
}

/// The deterministic crisis keyword gate. Runs BEFORE every model call (product
/// invariant #5): on a match the model is suppressed and static resources surface.
/// This is plain string matching by design — never a model, never a heuristic score.
public struct CrisisGate: Sendable {
    private let lexicon: [CrisisCategory: [String]]
    private let resources: [SupportResource]

    public init(
        lexicon: [CrisisCategory: [String]] = CrisisLexicon.english,
        resources: [SupportResource] = SupportResource.bundled
    ) {
        self.lexicon = lexicon
        self.resources = resources
    }

    /// Locale-aware gate: the English lexicon plus any additive localized phrases
    /// for the locale's language, with region-appropriate resources. The English
    /// floor is always present — localization only widens detection, never narrows
    /// it — so this stays as deterministic as the English-only gate.
    public init(localizedFor locale: Locale) {
        lexicon = CrisisLexicon.merged(forLanguage: locale.language.languageCode?.identifier)
        resources = SupportResource.localized(for: locale)
    }

    public func evaluate(_ text: String) -> GateDecision {
        let normalized = TextNormalizer.normalize(text)
        guard !normalized.isEmpty else { return .clear }

        var matches: [GateMatch] = []
        for category in CrisisCategory.allCases {
            for phrase in lexicon[category] ?? [] where TextNormalizer.containsPhrase(phrase, in: normalized) {
                matches.append(GateMatch(category: category, phrase: phrase))
            }
        }
        guard !matches.isEmpty else { return .clear }
        return .matched(matches: matches, resources: resources)
    }
}
