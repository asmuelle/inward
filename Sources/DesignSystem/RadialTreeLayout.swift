import CoreGraphics
import Foundation

/// Where the nodes of a drawn mind map sit: the center in the middle, branches
/// on one ring around it, each branch's leaves fanned outward beyond it. Pure
/// geometry over counts — it knows nothing about labels or entries — so the
/// layout is deterministic, motion-free (Reduce-Motion safe), and testable
/// without a view. Positions come back indexed the way the counts went in.
public enum RadialTreeLayout {
    public struct Positions: Equatable, Sendable {
        public let center: CGPoint
        public let branches: [CGPoint]
        /// `leaves[b][l]` is the l-th leaf of branch b.
        public let leaves: [[CGPoint]]
    }

    /// Nodes never come closer than this to the canvas edge, so a label drawn
    /// around a point is not clipped.
    public static let margin: CGFloat = 56
    /// Half the angular span a branch's leaves fan across, in radians.
    static let leafFanHalfAngle = 0.42
    /// How far out the branch ring sits, as a share of the usable radius.
    static let branchRingShare = 0.5

    public static func positions(leafCounts: [Int], in size: CGSize) -> Positions {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        guard !leafCounts.isEmpty else { return Positions(center: center, branches: [], leaves: []) }

        let usable = max(0, min(size.width, size.height) / 2 - margin)
        let branchRadius = usable * branchRingShare
        let leafRadius = usable
        let count = Double(leafCounts.count)

        var branches: [CGPoint] = []
        var leaves: [[CGPoint]] = []
        for (index, leafCount) in leafCounts.enumerated() {
            let angle = 2 * Double.pi * Double(index) / count - .pi / 2
            branches.append(point(from: center, radius: branchRadius, angle: angle))
            leaves.append(fan(count: leafCount, around: angle, from: center, radius: leafRadius))
        }
        return Positions(center: center, branches: branches, leaves: leaves)
    }

    /// `count` points on the outer ring, centred on `angle` and spread across
    /// the fan so neighbouring branches' leaves stay apart.
    private static func fan(count: Int, around angle: Double, from center: CGPoint, radius: CGFloat) -> [CGPoint] {
        guard count > 0 else { return [] }
        guard count > 1 else { return [point(from: center, radius: radius, angle: angle)] }
        let step = 2 * leafFanHalfAngle / Double(count - 1)
        return (0 ..< count).map { index in
            point(from: center, radius: radius, angle: angle - leafFanHalfAngle + step * Double(index))
        }
    }

    private static func point(from center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
}
