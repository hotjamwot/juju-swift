/// JujuAmbienceTests.swift
/// Purpose: Deterministic unit tests for the ambience random-walk score engine
/// (topology validity, walk legality, journey brightness shape).
/// AI Notes: Pure-logic coverage only — no timers, no SwiftUI, no animation.

import XCTest
@testable import Juju

/// Seeded RNG so randomised score tests are fully deterministic.
private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

final class JujuAmbienceTests: XCTestCase {
    private var rng: SeededRNG!

    override func setUp() {
        super.setUp()
        rng = SeededRNG(state: 0x5EED)
    }

    // MARK: - Topology

    func testHemispheres_haveMatchingNodeAndNeighbourCounts() {
        for hemisphere in [JujuAmbienceHemisphere.left, JujuAmbienceHemisphere.right] {
            XCTAssertEqual(hemisphere.neighbours.count, hemisphere.nodes.count)
        }
    }

    func testHemispheres_areSymmetricAndInBounds() {
        for hemisphere in [JujuAmbienceHemisphere.left, JujuAmbienceHemisphere.right] {
            for (a, ends) in hemisphere.neighbours.enumerated() {
                for b in ends {
                    XCTAssertTrue(hemisphere.neighbours.indices.contains(b), "edge \(a)->\(b) out of range")
                    XCTAssertTrue(hemisphere.neighbours[b].contains(a), "edge \(a)->\(b) not symmetric")
                }
            }
            for point in hemisphere.nodes {
                XCTAssertGreaterThanOrEqual(point.x, 0)
                XCTAssertGreaterThanOrEqual(point.y, 0)
                XCTAssertLessThanOrEqual(point.x, 200)
                XCTAssertLessThanOrEqual(point.y, 96)
            }
        }
    }

    func testHemispheres_areRelatedButNotMirrored() {
        XCTAssertNotEqual(JujuAmbienceHemisphere.left.edges.count, 0)
        XCTAssertNotEqual(JujuAmbienceHemisphere.right.edges.count, 0)
        let leftSet = Set(JujuAmbienceHemisphere.left.nodes.map { "\($0.x),\($0.y)" })
        let rightSet = Set(JujuAmbienceHemisphere.right.nodes.map { "\($0.x),\($0.y)" })
        XCTAssertTrue(leftSet.isDisjoint(with: rightSet), "hemispheres must not share node positions")
    }

    // MARK: - Random walk

    func testRandomWalk_onlyTraversesRealThreads() {
        for hemisphere in [JujuAmbienceHemisphere.left, JujuAmbienceHemisphere.right] {
            for start in hemisphere.nodes.indices {
                let path = JujuAmbienceController.randomWalk(
                    from: start, length: 5,
                    neighbours: hemisphere.neighbours, using: &rng
                )
                XCTAssertEqual(path.first, start)
                XCTAssertLessThanOrEqual(path.count, 5)
                for pair in zip(path, path.dropFirst()) {
                    XCTAssertTrue(hemisphere.neighbours[pair.0].contains(pair.1))
                }
            }
        }
    }

    func testRandomWalk_handlesDegenerateInput() {
        let neighbours = JujuAmbienceHemisphere.left.neighbours
        XCTAssertEqual(JujuAmbienceController.randomWalk(from: 0, length: 0, neighbours: neighbours, using: &rng), [])
        XCTAssertEqual(JujuAmbienceController.randomWalk(from: 99, length: 4, neighbours: neighbours, using: &rng), [])
    }

    // MARK: - Score shape

    func testBuildScore_lightsAndRestsOnly() {
        let neighbours = JujuAmbienceHemisphere.left.neighbours
        let score = JujuAmbienceController.buildScore(nodeCount: neighbours.count, neighbours: neighbours, using: &rng)
        XCTAssertFalse(score.isEmpty)
        let validValues: Set<CGFloat> = [JujuAmbienceController.hot, 0.60, 0.36, JujuAmbienceController.rest]
        for (index, value) in score {
            XCTAssertTrue(index == -1 || neighbours.indices.contains(index))
            XCTAssertTrue(validValues.contains(value), "unexpected brightness \(value)")
        }
        XCTAssertTrue(score.contains { $0.0 == -1 }, "score must include rest notes")
        XCTAssertTrue(score.contains { $0.1 == JujuAmbienceController.hot }, "score must include hot notes")
    }

    func testEmitJourney_headsHotThenDecays() {
        let notes = JujuAmbienceController.emitJourney([0, 1])
        let values = notes.map { $0.1 }
        XCTAssertTrue(values.contains(JujuAmbienceController.hot))
        XCTAssertTrue(values.contains(0.60))
        XCTAssertTrue(values.contains(0.36))
        XCTAssertEqual(values.last, JujuAmbienceController.rest)
    }

    func testDecayValue_stages() {
        XCTAssertEqual(JujuAmbienceController.decayValue(1), 0.60)
        XCTAssertEqual(JujuAmbienceController.decayValue(2), 0.36)
        XCTAssertEqual(JujuAmbienceController.decayValue(3), JujuAmbienceController.rest)
    }
}
