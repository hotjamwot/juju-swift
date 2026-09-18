/// JujuAmbienceTests.swift
/// Purpose: Guards the thought-mesh ambience at the level a human eye cannot
/// check — the hand-typed topology tables, the shape of a cascade, and the
/// [rest, hot] bounds the Canvas renderer depends on.
/// AI Notes: Deliberately a handful of broad tests rather than one per
/// behaviour. This is a *visual* feature: how it feels is verified by looking at
/// it, and a test asserting an exact envelope constant only fails when the feel
/// is tuned, which is pure friction. So nothing here asserts a tunable number —
/// only structure, monotonic properties, and renderer bounds.
/// Pure logic only: no timers, no SwiftUI, no animation.

import XCTest
@testable import Juju

final class JujuAmbienceTests: XCTestCase {

    private let hemispheres = [JujuAmbienceHemisphere.left, JujuAmbienceHemisphere.right]

    // MARK: - Topology

    /// The meshes are hand-typed coordinate and edge tables, where a typo reads
    /// as a missing thread rather than an error. Validate them structurally.
    func testHemispheres_areWellFormedAndNotMirrored() {
        for hemisphere in hemispheres {
            let count = hemisphere.nodes.count
            XCTAssertEqual(hemisphere.neighbours.count, count)
            XCTAssertTrue(hemisphere.nodes.indices.contains(hemisphere.entry))
            XCTAssertFalse(
                hemisphere.neighbours.contains { $0.isEmpty },
                "every neuron must be joined to the mesh"
            )

            for point in hemisphere.nodes {
                XCTAssertTrue(point.x >= 0 && point.x <= 1, "node outside the band")
                XCTAssertTrue(point.y >= 0 && point.y <= 1, "node outside the band")
            }

            // The explicit edge list and the derived adjacency must agree exactly.
            for (a, b) in hemisphere.edges {
                XCTAssertTrue(hemisphere.neighbours[a].contains(b), "edge \(a)-\(b) missing from adjacency")
                XCTAssertTrue(hemisphere.neighbours[b].contains(a), "edge \(a)-\(b) not symmetric")
                XCTAssertEqual(hemisphere.edgeIndex(a, b), hemisphere.edges.firstIndex { $0 == (a, b) })
                XCTAssertEqual(hemisphere.edgeIndex(b, a), hemisphere.edgeIndex(a, b))
            }
            let derived = hemisphere.neighbours.enumerated().reduce(0) { total, pair in
                total + pair.element.filter { $0 > pair.offset }.count
            }
            XCTAssertEqual(derived, hemisphere.edges.count, "adjacency and the edge list disagree")
            XCTAssertNil(hemisphere.edgeIndex(0, count - 1), "the two far tips are never threaded")
            XCTAssertNil(hemisphere.edgeIndex(99, 0), "an out-of-range node has no threads")

            // Reachable from the greeting-adjacent entry — otherwise a spark can
            // die mid-cascade and the mesh looks broken for no visible reason.
            var seen: Set<Int> = [hemisphere.entry]
            var frontier = [hemisphere.entry]
            while let next = frontier.popLast() {
                for neighbour in hemisphere.neighbours[next] where !seen.contains(neighbour) {
                    seen.insert(neighbour)
                    frontier.append(neighbour)
                }
            }
            XCTAssertEqual(seen.count, count, "the mesh must be reachable from its entry")

            // Tapering tips and hubs, not a uniform lattice.
            let degrees = hemisphere.neighbours.map { $0.count }
            XCTAssertGreaterThanOrEqual(Set(degrees).count, 3, "expected a mix of hubs and tips")
            XCTAssertGreaterThanOrEqual(degrees.min() ?? 0, 2, "no neuron should dangle off one thread")

            // No two neurons share an axis, or the weave reads as a chain-link
            // fence rather than an organic web.
            XCTAssertEqual(Set(hemisphere.nodes.map { $0.x }).count, count, "two neurons share an x")
            XCTAssertEqual(Set(hemisphere.nodes.map { $0.y }).count, count, "two neurons share a y")
        }

        // The entry faces the greeting: left reaches right, right reaches left.
        let left = JujuAmbienceHemisphere.left
        let right = JujuAmbienceHemisphere.right
        XCTAssertEqual(left.nodes[left.entry].x, left.nodes.map { $0.x }.max())
        XCTAssertEqual(right.nodes[right.entry].x, right.nodes.map { $0.x }.min())

        // Related but deliberately not mirrored: same vocabulary, different weave.
        XCTAssertEqual(left.nodes.count, right.nodes.count)
        XCTAssertEqual(left.edges.count, right.edges.count)
        XCTAssertEqual(left.entry, right.entry)
        XCTAssertNotEqual(
            Set(left.edges.map { "\($0.0)-\($0.1)" }),
            Set(right.edges.map { "\($0.0)-\($0.1)" }),
            "the two sides must not share one weave"
        )
        let rightPositions = Set(right.nodes.map { "\($0.x),\($0.y)" })
        for point in left.nodes {
            XCTAssertFalse(rightPositions.contains("\(point.x),\(point.y)"), "hemispheres must not share positions")
        }
    }

    // MARK: - Cascade shape

    /// A cascade must follow real threads, reach what it claims to reach, and
    /// stop where it is told to.
    func testStrike_cascadesAlongRealThreadsAndRespectsItsLimit() {
        for hemisphere in hemispheres {
            // A generous limit washes the whole mesh: one thread per reached node.
            let full = JujuAmbienceStrike(
                hemisphere: hemisphere, origin: hemisphere.entry, maxHops: 6, hopDuration: 0.1
            )
            XCTAssertEqual(full.origin, hemisphere.entry)
            XCTAssertEqual(full.arrivals[hemisphere.entry] ?? -1, JujuAmbienceStrike.leadIn, accuracy: 0.0001)
            XCTAssertEqual(full.arrivals.compactMap { $0 }.count, hemisphere.nodes.count)
            XCTAssertEqual(full.waves.count, hemisphere.nodes.count - 1)
            for wave in full.waves {
                XCTAssertTrue(
                    hemisphere.neighbours[wave.from].contains(wave.to),
                    "wave \(wave.from)->\(wave.to) is not a real thread"
                )
                XCTAssertEqual(hemisphere.edgeIndex(wave.from, wave.to), wave.edge)
            }

            // One hop reaches only the entry and its immediate neighbours.
            let single = JujuAmbienceStrike(
                hemisphere: hemisphere, origin: hemisphere.entry, maxHops: 1, hopDuration: 0.1
            )
            let reachable = Set([hemisphere.entry] + hemisphere.neighbours[hemisphere.entry])
            let reached = Set(single.arrivals.enumerated().compactMap { $0.element == nil ? nil : $0.offset })
            XCTAssertEqual(reached, reachable)
            XCTAssertEqual(single.waves.count, hemisphere.neighbours[hemisphere.entry].count)

            // A nonsense origin is inert rather than a crash.
            let degenerate = JujuAmbienceStrike(
                hemisphere: hemisphere, origin: 99, maxHops: 3, hopDuration: 0.1
            )
            XCTAssertTrue(degenerate.waves.isEmpty)
            XCTAssertTrue(degenerate.aftershocks.isEmpty)
            XCTAssertEqual(
                degenerate.frame(at: 0).nodeLevels,
                Array(repeating: JujuAmbienceStrike.rest, count: hemisphere.nodes.count)
            )
        }
    }

    /// The cascade spends itself: each hop takes longer and carries less light
    /// than the one before, and the head decelerates as it arrives. Asserted as
    /// monotonic properties, never as exact timings — those are tuned by eye.
    func testStrike_spendsItselfAsItSpreads() {
        let hemisphere = JujuAmbienceHemisphere.left
        let strike = JujuAmbienceStrike(
            hemisphere: hemisphere, origin: hemisphere.entry, maxHops: 4, hopDuration: 0.12
        )

        // Group the wires by the instant they set off — one group per hop.
        let groups = Dictionary(grouping: strike.waves, by: { $0.start })
        let starts = groups.keys.sorted()
        XCTAssertGreaterThanOrEqual(starts.count, 2, "expected a multi-hop cascade")

        var previousDuration: CGFloat = 0
        var previousEnergy: CGFloat = .greatestFiniteMagnitude
        for (depth, start) in starts.enumerated() {
            let wires = groups[start] ?? []
            // Every wire of one hop shares its window and its energy.
            for wire in wires {
                XCTAssertEqual(wire.end - wire.start, wires[0].end - wires[0].start, accuracy: 0.0001)
                XCTAssertEqual(wire.energy, wires[0].energy, accuracy: 0.0001)
            }
            let duration = wires[0].end - start
            if depth > 0 {
                XCTAssertGreaterThan(duration, previousDuration, "each hop must take longer than the last")
                XCTAssertLessThan(wires[0].energy, previousEnergy, "each hop must be dimmer than the last")
            }
            previousDuration = duration
            previousEnergy = wires[0].energy
        }

        // A pulse window starts on its source and lands exactly on its target,
        // so a head is always drawn on the thread it is actually travelling.
        for wave in strike.waves {
            XCTAssertEqual(strike.arrivals[wave.to] ?? -1, wave.end, accuracy: 0.0001)
            XCTAssertEqual(strike.arrivals[wave.from] ?? -1, wave.start, accuracy: 0.0001)
        }

        // Nearer neurons outshine further ones; the origin fires at full strength.
        XCTAssertEqual(strike.nodePeak[hemisphere.entry], JujuAmbienceStrike.hot)
        var previousPeak: CGFloat = .greatestFiniteMagnitude
        for time in Set(strike.arrivals.compactMap { $0 }).sorted() {
            let ring = strike.arrivals.enumerated()
                .compactMap { $0.element == time ? strike.nodePeak[$0.offset] : nil }
            guard let peak = ring.first else { continue }
            XCTAssertLessThanOrEqual(peak, previousPeak, "a further ring must not outshine a nearer one")
            previousPeak = peak
        }

        // Energy never leaves 0...1, and never dies out entirely however far it goes.
        for depth in 0...12 {
            let energy = JujuAmbienceStrike.energy(atHop: depth)
            XCTAssertGreaterThan(energy, 0)
            XCTAssertLessThanOrEqual(energy, 1)
            XCTAssertGreaterThanOrEqual(energy, JujuAmbienceStrike.minHopEnergy)
        }

        // The head covers more ground early than late — it arrives decelerating.
        XCTAssertEqual(JujuAmbienceStrike.easeTravel(0), 0, accuracy: 0.0001)
        XCTAssertEqual(JujuAmbienceStrike.easeTravel(1), 1, accuracy: 0.0001)
        XCTAssertGreaterThan(JujuAmbienceStrike.easeTravel(0.5), 0.5)
        var previous: CGFloat = -1
        for step in 0...20 {
            let value = JujuAmbienceStrike.easeTravel(CGFloat(step) / 20)
            XCTAssertGreaterThanOrEqual(value, previous, "travel must never move backwards")
            previous = value
        }
    }

    // MARK: - Renderer contract

    /// The Canvas assumes nodes stay in [rest, hot], thread glow in [0, 1], and
    /// a dormant mesh is genuinely dormant. A stray value silently draws a
    /// blown-out or invisible frame, and a flickering rest state is visible.
    func testFrame_staysInBoundsAndEndsQuiet() {
        for hemisphere in hemispheres {
            let strike = JujuAmbienceStrike(
                hemisphere: hemisphere, origin: hemisphere.entry, maxHops: 5, hopDuration: 0.12
            )

            // Quiet before anything is scheduled to happen.
            let early = strike.frame(at: JujuAmbienceStrike.leadIn / 2)
            XCTAssertEqual(early.nodeLevels, Array(repeating: JujuAmbienceStrike.rest, count: hemisphere.nodes.count))
            XCTAssertEqual(early.edgeGlow, Array(repeating: 0, count: hemisphere.edges.count))
            XCTAssertTrue(early.pulses.isEmpty)

            // Sweep the whole life of the cascade.
            var elapsed: CGFloat = 0
            while elapsed <= strike.duration + 0.5 {
                let frame = strike.frame(at: elapsed)
                XCTAssertEqual(frame.nodeLevels.count, hemisphere.nodes.count)
                XCTAssertEqual(frame.edgeGlow.count, hemisphere.edges.count)
                for level in frame.nodeLevels {
                    XCTAssertGreaterThanOrEqual(level, JujuAmbienceStrike.rest)
                    XCTAssertLessThanOrEqual(level, JujuAmbienceStrike.hot)
                }
                for glow in frame.edgeGlow {
                    XCTAssertGreaterThanOrEqual(glow, 0)
                    XCTAssertLessThanOrEqual(glow, 1)
                }
                for pulse in frame.pulses {
                    XCTAssertTrue(hemisphere.neighbours[pulse.from].contains(pulse.to))
                    XCTAssertGreaterThanOrEqual(pulse.progress, 0)
                    XCTAssertLessThanOrEqual(pulse.progress, 1)
                    XCTAssertGreaterThanOrEqual(pulse.energy, 0)
                    XCTAssertLessThanOrEqual(pulse.energy, 1)
                }
                elapsed += 0.02
            }

            // It is genuinely over when it says it is, and `duration` covers the
            // cascade plus every aftershock tail.
            let end = strike.frame(at: strike.duration)
            XCTAssertEqual(end.nodeLevels, Array(repeating: JujuAmbienceStrike.rest, count: hemisphere.nodes.count))
            XCTAssertEqual(end.edgeGlow, Array(repeating: 0, count: hemisphere.edges.count))
            XCTAssertTrue(end.pulses.isEmpty)

            let lastArrival = strike.arrivals.compactMap { $0 }.max() ?? 0
            let cascadeEnd = lastArrival
                + JujuAmbienceStrike.attack + JujuAmbienceStrike.hold
                + JujuAmbienceStrike.decay + JujuAmbienceStrike.afterglow
            XCTAssertGreaterThanOrEqual(strike.duration, cascadeEnd - 0.0001)
        }

        // A dormant frame matches its topology, and the resting threads are
        // stable — a quiet mesh must never shimmer.
        for hemisphere in hemispheres {
            let rest = JujuAmbienceFrame.rest(hemisphere)
            XCTAssertEqual(rest.nodeLevels, Array(repeating: JujuAmbienceStrike.rest, count: hemisphere.nodes.count))
            XCTAssertEqual(rest.edgeGlow, Array(repeating: 0, count: hemisphere.edges.count))
            XCTAssertTrue(rest.pulses.isEmpty)

            let weights = hemisphere.edges.indices.map { hemisphere.restOpacity(forEdgeAt: $0) }
            XCTAssertEqual(weights, hemisphere.edges.indices.map { hemisphere.restOpacity(forEdgeAt: $0) })
            for weight in weights {
                XCTAssertGreaterThan(weight, 0)
                XCTAssertLessThan(weight, 0.5, "a resting thread must stay subtle")
            }
        }
    }

    /// The phrase is the origin of every cascade, so its flash must still be
    /// alight as the spark enters the mesh — otherwise the two read as unrelated
    /// twinkles rather than one causal event.
    func testGreetingFlowsIntoTheMesh() {
        let strike = JujuAmbienceStrike(
            hemisphere: .left, origin: JujuAmbienceHemisphere.left.entry, maxHops: 2, hopDuration: 0.12
        )

        XCTAssertEqual(strike.greetingGlow(at: -0.1), 0)
        XCTAssertEqual(strike.greetingGlow(at: 0), 0)
        XCTAssertLessThan(strike.greetingGlow(at: JujuAmbienceStrike.greetingAttack / 2), 1)
        XCTAssertEqual(
            strike.greetingGlow(at: JujuAmbienceStrike.greetingAttack + JujuAmbienceStrike.greetingHold / 2),
            1
        )
        let spent = JujuAmbienceStrike.greetingAttack
            + JujuAmbienceStrike.greetingHold
            + JujuAmbienceStrike.greetingDecay
        XCTAssertEqual(strike.greetingGlow(at: spent), 0, accuracy: 0.0001)

        // The overlap: the spark lands while the phrase is still lit.
        XCTAssertLessThan(JujuAmbienceStrike.leadIn, spent)
    }

    // MARK: - Aftershocks

    /// Shallow, repeated glimmers from neurons the cascade already spent. Chosen
    /// from a seed, so a strike stays a pure function of its inputs — if this
    /// were random per frame the whole mesh would strobe.
    func testAftershocks_glimmerAfterTheCascadeAndFollowTheirSeed() {
        let hemisphere = JujuAmbienceHemisphere.left
        let strike = JujuAmbienceStrike(
            hemisphere: hemisphere, origin: hemisphere.entry, maxHops: 4, hopDuration: 0.12
        )

        XCTAssertFalse(strike.aftershocks.isEmpty, "a spent mesh should keep glimmering")
        XCTAssertLessThanOrEqual(strike.aftershocks.count, 2)

        let lastArrival = strike.arrivals.compactMap { $0 }.max() ?? 0
        for shock in strike.aftershocks {
            XCTAssertNotNil(strike.arrivals[shock.node], "only neurons the cascade reached may glimmer")
            XCTAssertGreaterThanOrEqual(shock.pulses, 2)
            XCTAssertLessThanOrEqual(shock.pulses, 3)
            XCTAssertGreaterThan(shock.peak, JujuAmbienceStrike.rest)
            XCTAssertLessThan(shock.peak, JujuAmbienceStrike.hot, "a glimmer must not outshine a fire")
            XCTAssertGreaterThan(shock.start, lastArrival, "aftershocks follow the cascade")

            // Each glimmer actually lights the neuron...
            for pulse in 0..<shock.pulses {
                let at = shock.start + CGFloat(pulse) * shock.period + JujuAmbienceStrike.attack
                XCTAssertGreaterThan(strike.frame(at: at).nodeLevels[shock.node], JujuAmbienceStrike.rest)
            }
            // ...and it settles again before the strike is over.
            let settled = shock.start
                + CGFloat(shock.pulses - 1) * shock.period
                + JujuAmbienceStrike.attack + JujuAmbienceStrike.hold + JujuAmbienceStrike.glimmerDecay
            XCTAssertEqual(
                strike.frame(at: settled).nodeLevels[shock.node],
                JujuAmbienceStrike.rest,
                accuracy: 0.0001
            )
        }

        // The same seed tells the same story.
        let seeded = JujuAmbienceStrike(
            hemisphere: hemisphere, origin: hemisphere.entry,
            maxHops: 4, hopDuration: 0.12, aftershockSeed: 42
        )
        let again = JujuAmbienceStrike(
            hemisphere: hemisphere, origin: hemisphere.entry,
            maxHops: 4, hopDuration: 0.12, aftershockSeed: 42
        )
        XCTAssertEqual(seeded.aftershocks, again.aftershocks)
        XCTAssertEqual(seeded.duration, again.duration, accuracy: 0.0001)

        // And different seeds can tell different stories.
        let stories = (0..<16).map { seed in
            JujuAmbienceStrike(
                hemisphere: hemisphere, origin: hemisphere.entry,
                maxHops: 4, hopDuration: 0.12, aftershockSeed: UInt64(seed)
            ).aftershocks.map { "\($0.node)" }.joined(separator: ",")
        }
        XCTAssertGreaterThan(Set(stories).count, 1, "the seed must actually vary the aftershocks")
    }
}