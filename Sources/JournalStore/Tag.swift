import Foundation

/// A free-form label on entries. Names are normalized (trimmed, lowercased) so
/// "Mornings" and "mornings" resolve to the same tag — calm, lowercase tags fit
/// the app's voice and keep the vocabulary tidy.
public struct Tag: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    public let name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = Tag.normalize(name)
    }

    /// Trimmed and lowercased; empty when the input has no usable characters.
    public static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Normalizes a list of raw names, dropping empties and duplicates while
    /// preserving first-seen order. The canonical input to `setTags`.
    public static func normalizedNames(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for candidate in raw {
            let name = normalize(candidate)
            guard !name.isEmpty, seen.insert(name).inserted else { continue }
            result.append(name)
        }
        return result
    }
}
