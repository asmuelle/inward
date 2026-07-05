import Foundation

/// Boundary for on-device sentence embedding. The shipped implementation wraps
/// Apple's NaturalLanguage sentence embeddings; tests use the deterministic
/// mock. No cloud implementation may ever exist (invariant #3) — an embedding
/// call must be as airplane-mode-true as the rest of the journaling path.
public protocol TextEmbedding: Sendable {
    /// Whether an embedding model for the user's language is present on device.
    /// Never triggers a download — absence degrades recall to the word-overlap
    /// floor, it never reaches for the network.
    func isAvailable() async -> Bool

    /// The text's sentence vector, or nil when the model can't embed it.
    func embed(_ text: String) async -> [Float]?
}

/// Deterministic stand-in for tests and previews: returns scripted vectors by
/// exact text match.
public struct MockTextEmbedding: TextEmbedding {
    private let vectors: [String: [Float]]
    private let available: Bool

    public init(vectors: [String: [Float]], available: Bool = true) {
        self.vectors = vectors
        self.available = available
    }

    public func isAvailable() async -> Bool {
        available
    }

    public func embed(_ text: String) async -> [Float]? {
        vectors[text]
    }
}

#if canImport(NaturalLanguage)
    import NaturalLanguage

    /// Apple's bundled sentence embeddings (`NLEmbedding.sentenceEmbedding`) —
    /// chosen over `NLContextualEmbedding` because the static models ship with
    /// the OS for the supported languages: no model download, so semantic recall
    /// is airplane-mode functional from first launch, with no consent surface.
    /// The `TextEmbedding` seam leaves room to swap the contextual model in
    /// later behind the same consented-download flow the speech model uses.
    public struct SentenceTextEmbedder: TextEmbedding {
        private let language: NLLanguage

        /// Uses the user's primary language by default; falls back to English
        /// when the locale doesn't name one.
        public init(languageCode: String? = Locale.current.language.languageCode?.identifier) {
            language = languageCode.map(NLLanguage.init(rawValue:)) ?? .english
        }

        public func isAvailable() async -> Bool {
            Self.model(for: language) != nil
        }

        public func embed(_ text: String) async -> [Float]? {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let model = Self.model(for: language) else { return nil }
            guard let vector = model.vector(for: trimmed) else { return nil }
            return vector.map(Float.init)
        }

        private static func model(for language: NLLanguage) -> NLEmbedding? {
            NLEmbedding.sentenceEmbedding(for: language)
                ?? NLEmbedding.sentenceEmbedding(for: .english)
        }
    }
#endif
