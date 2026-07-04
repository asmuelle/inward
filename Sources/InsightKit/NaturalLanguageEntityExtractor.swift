#if canImport(NaturalLanguage)
    import Foundation
    import NaturalLanguage

    /// The user's own recurring proper nouns, used to seed a gazetteer so the
    /// deterministic floor keeps recognizing names it has seen before. Plain
    /// value type; the caller (the app's indexer) maps store entities down.
    public struct PersonalNounVocabulary: Sendable, Equatable {
        public let people: [String]
        public let places: [String]

        public var isEmpty: Bool {
            people.isEmpty && places.isEmpty
        }

        public init(people: [String], places: [String]) {
            self.people = people
            self.places = places
        }
    }

    /// The deterministic, always-on-device floor (invariant #9): Apple's
    /// `NaturalLanguage` named-entity recognition for people / places /
    /// organizations, plus a coarse sentiment word. No topics or action items —
    /// those are the language model's contribution when it's available. Everything
    /// it returns is a substring of the entry, so it passes verification by
    /// construction.
    public struct NaturalLanguageEntityExtractor: EntityExtracting {
        /// Kept as plain strings (Sendable); the NLGazetteer is built per extract.
        private let vocabulary: PersonalNounVocabulary?

        public init(vocabulary: PersonalNounVocabulary? = nil) {
            self.vocabulary = vocabulary
        }

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
            // The journal's own names override the stock recognizer, closing the
            // flywheel: better entities → better recognition → better entities.
            if let gazetteer = Self.gazetteer(for: vocabulary) {
                tagger.setGazetteers([gazetteer], for: .nameType)
            }
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

        private static func gazetteer(for vocabulary: PersonalNounVocabulary?) -> NLGazetteer? {
            guard let vocabulary, !vocabulary.isEmpty else { return nil }
            var dictionary: [String: [String]] = [:]
            if !vocabulary.people.isEmpty { dictionary[NLTag.personalName.rawValue] = vocabulary.people }
            if !vocabulary.places.isEmpty { dictionary[NLTag.placeName.rawValue] = vocabulary.places }
            return try? NLGazetteer(dictionary: dictionary, language: nil)
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
