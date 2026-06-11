import Foundation

/// The English crisis lexicon. Phrases are matched whole-word on normalized text,
/// so "self-harm" and "self harm" both match while "killing it at work" does not.
/// Localized lexicons are additive — never replace English silently.
public enum CrisisLexicon {
    public static let english: [CrisisCategory: [String]] = [
        .selfHarm: [
            "kill myself",
            "end my life",
            "suicide",
            "suicidal",
            "hurt myself",
            "harm myself",
            "self harm",
            "want to die",
            "wish i was dead",
            "wish i were dead",
            "better off dead",
            "end it all",
            "no reason to live",
        ],
        .harmFromOthers: [
            "he hits me",
            "she hits me",
            "they hit me",
            "hits me",
            "afraid of him hurting me",
            "being abused",
            "abusing me",
            "domestic violence",
            "afraid to go home",
        ],
        .overdose: [
            "overdose",
            "overdosed",
            "took too many pills",
        ],
    ]
}
