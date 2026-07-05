import Foundation
import JournalStore
@testable import RecallKit
import Testing

private let idA = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
private let idB = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
private let idC = UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!

@Suite("EmbeddingRecallIndex — cosine ranking over stored vectors")
struct EmbeddingRecallIndexTests {
    @Test("closest vector ranks first; orthogonal ones drop out")
    func ranksByCosine() async {
        // Arrange — the query points along [1, 0]; A is aligned, B is close,
        // C is orthogonal and must not appear at all.
        let embedder = MockTextEmbedding(vectors: ["the move": [1, 0]])
        let index = EmbeddingRecallIndex(embedder: embedder)
        await index.load([
            EntryEmbedding(entryId: idA, vector: [2, 0]),
            EntryEmbedding(entryId: idB, vector: [1, 1]),
            EntryEmbedding(entryId: idC, vector: [0, 1]),
        ])

        // Act
        let related = await index.related(to: "the move", limit: 5)

        // Assert
        #expect(related == [idA, idB])
    }

    @Test("excluded ids never come back — the entry itself stays out")
    func honorsExclusions() async {
        let embedder = MockTextEmbedding(vectors: ["q": [1, 0]])
        let index = EmbeddingRecallIndex(embedder: embedder)
        await index.load([
            EntryEmbedding(entryId: idA, vector: [1, 0]),
            EntryEmbedding(entryId: idB, vector: [1, 0.2]),
        ])

        let related = await index.related(to: "q", limit: 5, excluding: [idA])

        #expect(related == [idB])
    }

    @Test("an unembeddable query yields nothing, never an error")
    func unavailableEmbedderIsQuiet() async {
        let index = EmbeddingRecallIndex(embedder: MockTextEmbedding(vectors: [:]))
        await index.load([EntryEmbedding(entryId: idA, vector: [1, 0])])

        #expect(await index.related(to: "anything", limit: 5).isEmpty)
    }

    @Test("loading replaces the corpus")
    func loadReplaces() async {
        let index = EmbeddingRecallIndex(embedder: MockTextEmbedding(vectors: [:]))
        await index.load([EntryEmbedding(entryId: idA, vector: [1, 0])])

        await index.load([EntryEmbedding(entryId: idB, vector: [1, 0])])

        #expect(await index.indexedCount() == 1)
    }

    @Test("cosine handles identity, orthogonality, and mismatch")
    func cosineMath() {
        #expect(EmbeddingRecallIndex.cosine([1, 0], [1, 0]) == 1)
        #expect(EmbeddingRecallIndex.cosine([1, 0], [0, 1]) == 0)
        #expect(EmbeddingRecallIndex.cosine([1, 0], [1, 0, 0]) == nil)
        #expect(EmbeddingRecallIndex.cosine([0, 0], [1, 0]) == nil)
    }
}
