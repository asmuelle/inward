@testable import CaptureKit
import Testing

@Suite("TranscriptAccumulator — pure live-transcript merge")
struct TranscriptAccumulatorTests {
    @Test("volatile segments replace each other, not accumulate")
    func volatileReplaces() {
        // Arrange
        let start = TranscriptAccumulator()

        // Act
        let after = start
            .merging(TranscriptSegment(text: "tod", isFinal: false))
            .merging(TranscriptSegment(text: "today was", isFinal: false))

        // Assert
        #expect(after.displayText == "today was")
        #expect(after.committed.isEmpty)
    }

    @Test("final segments commit and clear the volatile hypothesis")
    func finalCommits() {
        // Arrange
        let start = TranscriptAccumulator()

        // Act
        let after = start
            .merging(TranscriptSegment(text: "today was long", isFinal: false))
            .merging(TranscriptSegment(text: "Today was long.", isFinal: true, confidence: 0.9))
            .merging(TranscriptSegment(text: "but it", isFinal: false))

        // Assert
        #expect(after.committed == "Today was long.")
        #expect(after.displayText == "Today was long. but it")
        #expect(after.lastFinalConfidence == 0.9)
    }

    @Test("successive finals join with single spaces")
    func finalsJoin() {
        // Act
        let after = TranscriptAccumulator()
            .merging(TranscriptSegment(text: "First thought.", isFinal: true))
            .merging(TranscriptSegment(text: "Second thought.", isFinal: true))

        // Assert
        #expect(after.displayText == "First thought. Second thought.")
    }

    @Test("merging is immutable: the original accumulator is untouched")
    func mergingIsImmutable() {
        // Arrange
        let original = TranscriptAccumulator()

        // Act
        _ = original.merging(TranscriptSegment(text: "something", isFinal: true))

        // Assert
        #expect(original.displayText.isEmpty)
    }
}
