import Foundation

/// A static support resource shown when the gate matches. Bundled with the app,
/// shown verbatim — never AI-generated, never fetched from a network.
public struct SupportResource: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let name: String
    public let detail: String
    public let region: String

    public init(id: String, name: String, detail: String, region: String) {
        self.id = id
        self.name = name
        self.detail = detail
        self.region = region
    }

    /// The M1 bundled directory (English). Localization expands this list; it must
    /// never be empty — the gate test enforces that.
    public static let bundled: [SupportResource] = [
        SupportResource(
            id: "us-988",
            name: "988 Suicide & Crisis Lifeline",
            detail: "Call or text 988, any hour. Someone is there.",
            region: "US"
        ),
        SupportResource(
            id: "us-crisis-text",
            name: "Crisis Text Line",
            detail: "Text HOME to 741741 to reach a trained volunteer, any hour.",
            region: "US"
        ),
        SupportResource(
            id: "intl-iasp",
            name: "Find a crisis center near you",
            detail: "The International Association for Suicide Prevention keeps a directory at iasp.info/resources/Crisis_Centres.",
            region: "International"
        ),
    ]
}
