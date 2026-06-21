import Foundation

/// The minimal shape of an entry InsightKit is allowed to read. The app maps its
/// `Entry` down to this — like ReflectKit's `ReviewableEntry` — so the extraction
/// layer never touches raw storage.
public struct ExtractableEntry: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let text: String

    public init(id: UUID, createdAt: Date, text: String) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
    }
}

/// What one entry yields: concrete entities (people / places / objects) that must
/// occur in the user's own words, plus the model's interpretation (topics,
/// sentiment, action items). Entities feed the future tag suggestions and mind map.
public struct EntryInsights: Sendable, Equatable, Codable {
    public var people: [String]
    public var places: [String]
    public var objects: [String]
    public var topics: [String]
    public var sentiment: String?
    public var actionItems: [String]

    public init(
        people: [String] = [],
        places: [String] = [],
        objects: [String] = [],
        topics: [String] = [],
        sentiment: String? = nil,
        actionItems: [String] = []
    ) {
        self.people = people
        self.places = places
        self.objects = objects
        self.topics = topics
        self.sentiment = sentiment
        self.actionItems = actionItems
    }

    public static let empty = EntryInsights()

    /// The verifiable, concrete entities — the ones required to occur in the text.
    public var entities: [String] {
        people + places + objects
    }
}
