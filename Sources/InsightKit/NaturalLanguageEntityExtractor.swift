#if canImport(NaturalLanguage)
    import Foundation
    import NaturalLanguage

    /// The deterministic, always-on-device floor (invariant #9): Apple's
    /// `NaturalLanguage` named-entity recognition for people / places /
    /// organizations, plus a coarse sentiment word. No topics or action items —
    /// those are the language model's contribution when it's available. Everything
    /// it returns is a substring of the entry, so it passes verification by
    /// construction.
    public struct NaturalLanguageEntityExtractor: EntityExtracting {
        public init() {}

        public func availability() async -> InsightAvailability {
            .available
        }

        public func extract(from entry: ExtractableEntry) async throws -> EntryInsights {
            let text = entry.text
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .empty
            }

            var people: [String] = []
            var places: [String] = []
            var objects: [String] = []

            let tagger = NLTagger(tagSchemes: [.nameType])
            tagger.string = text
            let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
            tagger.enumerateTags(
                in: text.startIndex ..< text.endIndex,
                unit: .word,
                scheme: .nameType,
                options: options
            ) { tag, range in
                let token = String(text[range])
                switch tag {
                case .personalName: people.append(token)
                case .placeName: places.append(token)
                case .organizationName: objects.append(token)
                default: break
                }
                return true
            }

            return EntryInsights(
                people: people,
                places: places,
                objects: objects,
                topics: [],
                sentiment: Self.sentimentWord(for: text),
                actionItems: []
            )
        }

        /// A single calm word for the entry's overall tone, from NaturalLanguage's
        /// sentiment score (-1…1). Deliberately gentle and plain.
        static func sentimentWord(for text: String) -> String? {
            let tagger = NLTagger(tagSchemes: [.sentimentScore])
            tagger.string = text
            let (tag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
            guard let raw = tag?.rawValue, let score = Double(raw) else { return nil }
            switch score {
            case ..<(-0.3): return "heavy"
            case 0.3...: return "light"
            default: return "steady"
            }
        }
    }
#endif
