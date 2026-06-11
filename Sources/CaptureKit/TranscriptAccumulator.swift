import Foundation

/// Pure merge logic for live transcription: finalized text accumulates, the
/// volatile hypothesis floats on top and is replaced by every volatile segment.
public struct TranscriptAccumulator: Sendable, Equatable {
    public private(set) var committed: String
    public private(set) var volatile: String
    public private(set) var lastFinalConfidence: Double?

    public init(committed: String = "", volatile: String = "") {
        self.committed = committed
        self.volatile = volatile
        lastFinalConfidence = nil
    }

    /// Returns a new accumulator with the segment applied (immutably).
    public func merging(_ segment: TranscriptSegment) -> TranscriptAccumulator {
        var next = self
        if segment.isFinal {
            next.committed = Self.joined(committed, segment.text)
            next.volatile = ""
            next.lastFinalConfidence = segment.confidence
        } else {
            next.volatile = segment.text
        }
        return next
    }

    /// What the live capture surface shows.
    public var displayText: String {
        Self.joined(committed, volatile)
    }

    private static func joined(_ head: String, _ tail: String) -> String {
        switch (head.isEmpty, tail.isEmpty) {
        case (true, _): tail
        case (false, true): head
        case (false, false): head + " " + tail
        }
    }
}
