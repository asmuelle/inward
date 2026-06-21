import Foundation

/// What kind of thing an extracted entity is. Drives the mind map's clusters.
public enum EntityKind: String, Sendable, Codable, CaseIterable {
    case person
    case place
    case object
    case topic
}

/// A person, place, object, or topic extracted from an entry and persisted for
/// the (future) tag suggestions and mind map. Unlike `Tag`, entities are *derived*
/// — they can be re-extracted at any time — so they live only in the SQLCipher
/// store; the file-store fallback skips them rather than carry derived data.
public struct JournalEntity: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    public let kind: EntityKind
    /// Display name, in the casing it was found ("Berlin").
    public let name: String

    public init(id: UUID = UUID(), kind: EntityKind, name: String) {
        self.id = id
        self.kind = kind
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Normalized key for de-duplication (trimmed, lowercased). Two mentions that
    /// differ only in casing collapse to one entity of a given kind.
    public var normalizedName: String {
        name.lowercased()
    }
}

/// An entity together with the entries that mention it — the raw material the
/// mind-map graph is built from. `entryIDs.count` is the entity's weight; shared
/// ids between two associations give the co-occurrence edge between them.
public struct EntityAssociation: Sendable, Hashable {
    public let entity: JournalEntity
    public let entryIDs: [UUID]

    public init(entity: JournalEntity, entryIDs: [UUID]) {
        self.entity = entity
        self.entryIDs = entryIDs
    }
}
