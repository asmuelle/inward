import CoreGraphics
@testable import DesignSystem
import Testing

@Suite("Radial tree layout — center, ring of branches, fanned leaves")
struct RadialTreeLayoutTests {
    private let size = CGSize(width: 600, height: 600)

    private func distance(_ from: CGPoint, _ to: CGPoint) -> CGFloat {
        ((from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y)).squareRoot()
    }

    @Test("the center sits in the middle and a map with no branches has nothing else")
    func centerOnly() {
        let layout = RadialTreeLayout.positions(leafCounts: [], in: size)

        #expect(layout.center == CGPoint(x: 300, y: 300))
        #expect(layout.branches.isEmpty)
        #expect(layout.leaves.isEmpty)
    }

    @Test("branches sit on one ring around the center, evenly spaced")
    func branchesShareARing() {
        let layout = RadialTreeLayout.positions(leafCounts: [0, 0, 0, 0], in: size)

        #expect(layout.branches.count == 4)
        let radii = layout.branches.map { distance($0, layout.center) }
        for radius in radii {
            #expect(abs(radius - radii[0]) < 0.5)
            #expect(radius > 0)
        }
        // Evenly spaced: consecutive branches are the same distance apart.
        let gaps = (0 ..< 4).map { distance(layout.branches[$0], layout.branches[($0 + 1) % 4]) }
        for gap in gaps {
            #expect(abs(gap - gaps[0]) < 0.5)
        }
    }

    @Test("each leaf sits closer to its own branch than to any other branch")
    func leavesHugTheirBranch() {
        let layout = RadialTreeLayout.positions(leafCounts: [3, 1, 4], in: size)

        #expect(layout.leaves.map(\.count) == [3, 1, 4])
        for (branchIndex, leaves) in layout.leaves.enumerated() {
            for leaf in leaves {
                let own = distance(leaf, layout.branches[branchIndex])
                for (otherIndex, other) in layout.branches.enumerated() where otherIndex != branchIndex {
                    #expect(own < distance(leaf, other))
                }
            }
        }
    }

    @Test("leaves lie outward from the center, beyond their branch")
    func leavesPointOutward() {
        let layout = RadialTreeLayout.positions(leafCounts: [2, 2], in: size)

        for (branchIndex, leaves) in layout.leaves.enumerated() {
            let branchRadius = distance(layout.branches[branchIndex], layout.center)
            for leaf in leaves {
                #expect(distance(leaf, layout.center) > branchRadius)
            }
        }
    }

    @Test("every node stays inside the canvas with a margin")
    func staysInBounds() {
        let layout = RadialTreeLayout.positions(leafCounts: [4, 4, 4, 4, 4, 4], in: size)

        let all = [layout.center] + layout.branches + layout.leaves.flatMap(\.self)
        for point in all {
            #expect(point.x >= RadialTreeLayout.margin && point.x <= size.width - RadialTreeLayout.margin)
            #expect(point.y >= RadialTreeLayout.margin && point.y <= size.height - RadialTreeLayout.margin)
        }
    }

    @Test("the layout is deterministic")
    func isDeterministic() {
        let first = RadialTreeLayout.positions(leafCounts: [2, 3], in: size)
        let second = RadialTreeLayout.positions(leafCounts: [2, 3], in: size)

        #expect(first == second)
    }
}
