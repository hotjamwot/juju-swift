/// JujuAmbience.swift
/// Purpose: The dashboard greeting's "thought mesh" — two asymmetric neural
/// filigrees flanking the Te reo phrase, fired by the greeting's own shimmer.
/// AI Notes: All rendering is a pure function of elapsed time
/// (`JujuAmbienceStrike.frame(at:)`). The controller owns cadence only: one
/// 60Hz timer runs *during* a burst and is invalidated between strikes, so the
/// idle gaps stay genuinely idle (see SWIFT_PATTERNS.md → Ambience Pattern).

import Foundation
import SwiftUI

// MARK: - Juju Ambience
//
// "The Thought Mesh" — the frame behind the dashboard greeting.
//
// The Te reo phrase sits calm and still at the centre. Reaching across the full
// width on either side of it are two straight-line filigree meshes (related but
// deliberately not mirrored), their innermost nodes almost touching the words.
// Every few seconds the greeting flashes once — warm and brief — and that spark
// enters the nearest node of one mesh and tears through it: a bright pulse runs
// down each thread, arriving at the next neuron and fanning out again, branching
// like lightning through the webbing. Each hop takes a little longer than the
// last, carries a little less light, and the head decelerates as it arrives — so
// the cascade visibly spends itself instead of metronoming outward. Then, as the
// webbing settles, one or two spent neurons glimmer a few times (aftershocks),
// and everything falls back to a near-invisible lattice.
//
// The meshes deliberately run past their own containers and dissolve into a
// fade, so each reads as a fragment of a much larger mind rather than a closed
// diagram.
//
// Why this design (Theme.swift is the source of truth):
// - The greeting is the *origin*, not a bystander. Instead of two meshes
//   competing with the voice, the voice ignites them — so the calm centre stays
//   the loudest, most legible thing on the page.
// - "Hue belongs to the data." The spark is warm white (`glow`) with a
//   `warmAccent` bloom — the warmth of an idea, never electric blue.
// - Straight threads, irregular weave. The lattice is hand-tuned so no two
//   neurons share an axis, node degrees vary, and the two sides never share an
//   edge list — so it reads as an organic web, not a chain-link fence.
// - Fewer, sharper events: long quiet gaps, then a fast cascade that slows and
//   dims as it spreads, so it feels like a synapse firing and spending itself
//   rather than stars glimmering in the sky.
// - Nothing is a closed shape: each mesh overflows its container and fades, so
//   the pair reads as two windows onto one larger, continuing weave.
//
// Lightweight by construction: between strikes NO timer is running and no state
// is published. A strike schedules a single 60Hz burst timer, then invalidates
// it and schedules the next quiet gap. Leaving the section (`.onDisappear`)
// stops everything; closing the window destroys the `@StateObject` controller.

// MARK: - Hemisphere Topology

/// One side of the ambience header: a woven mesh of nodes joined by threads.
/// Positions are normalised (0...1) inside the band so the mesh stretches to
/// whatever width the layout grants it; the two hemispheres share visual weight
/// but are deliberately not mirrored, so the pair reads as two halves of one
/// strange mind.
struct JujuAmbienceHemisphere {
    /// Normalised node positions inside the band (0...1 on both axes).
    let nodes: [CGPoint]
    /// Adjacency list: neighbours[i] holds every node connected to i.
    /// Guaranteed symmetric — every edge appears in both directions.
    let neighbours: [[Int]]
    /// Undirected connected pairs, in a stable order (index = edge identity).
    let edges: [(Int, Int)]
    /// The node closest to the greeting — where a spark enters this mesh.
    let entry: Int

    /// node → neighbour → edge index, so a wave can find the thread it travels.
    private let edgeLookup: [[Int: Int]]

    /// Build a hemisphere from an explicit edge list, deriving the symmetric
    /// adjacency list and the edge-index lookup so they can never disagree.
    /// - Parameters:
    ///   - nodes: normalised node positions.
    ///   - edges: undirected connected pairs, each listed once.
    ///   - entry: index of the greeting-adjacent node.
    init(nodes: [CGPoint], edges: [(Int, Int)], entry: Int) {
        self.nodes = nodes
        self.edges = edges
        self.entry = entry

        var adjacency = Array(repeating: [Int](), count: nodes.count)
        var lookup = Array(repeating: [Int: Int](), count: nodes.count)
        for (index, edge) in edges.enumerated() {
            let a = edge.0
            let b = edge.1
            guard adjacency.indices.contains(a), adjacency.indices.contains(b), a != b else { continue }
            if !adjacency[a].contains(b) { adjacency[a].append(b) }
            if !adjacency[b].contains(a) { adjacency[b].append(a) }
            lookup[a][b] = index
            lookup[b][a] = index
        }
        self.neighbours = adjacency
        self.edgeLookup = lookup
    }

    /// The index of the thread joining two nodes, if they are connected.
    func edgeIndex(_ a: Int, _ b: Int) -> Int? {
        guard edgeLookup.indices.contains(a) else { return nil }
        return edgeLookup[a][b]
    }

    /// A faint, stable weight for one resting thread, so the dormant lattice
    /// looks hand-drawn rather than stamped — some strands barely there, others
    /// a touch warmer. A pure function of the edge index (no RNG, no state), so
    /// the resting mesh can never flicker between frames.
    func restOpacity(forEdgeAt index: Int) -> CGFloat {
        var hash = UInt64(truncatingIfNeeded: index &* 2_654_435_761)
        hash = (hash ^ (hash >> 33)) &* 0xff51afd7ed558ccd
        hash ^= hash >> 29
        return 0.09 + 0.15 * CGFloat(hash % 1000) / 1000
    }

    /// Left mesh: an irregular web reaching right, its innermost node almost
    /// touching the greeting. Hand-tuned so no two neurons share an x or a y —
    /// the eye reads a web, not a grid — with a couple of long filigree chords
    /// and degrees ranging from 2 (a tapering tip) to 5 (a hub).
    static let left = JujuAmbienceHemisphere(
        nodes: [
            CGPoint(x: 0.97, y: 0.47),  // 0 — entry, touches the greeting
            CGPoint(x: 0.81, y: 0.16),  // 1
            CGPoint(x: 0.71, y: 0.49),  // 2
            CGPoint(x: 0.86, y: 0.81),  // 3
            CGPoint(x: 0.55, y: 0.30),  // 4
            CGPoint(x: 0.45, y: 0.66),  // 5
            CGPoint(x: 0.29, y: 0.13),  // 6
            CGPoint(x: 0.33, y: 0.45),  // 7
            CGPoint(x: 0.18, y: 0.80),  // 8
            CGPoint(x: 0.06, y: 0.50),  // 9
        ],
        edges: [
            (0, 1), (0, 2), (0, 3),
            (1, 2), (2, 3),
            (1, 4), (2, 4), (2, 5), (3, 5),
            (4, 5),
            (1, 6),                     // long chord across the crown
            (4, 6), (4, 7), (5, 7),
            (6, 7),
            (6, 9),                     // long chord down the far edge
            (7, 8), (7, 9), (8, 9),
        ],
        entry: 0
    )

    /// Right mesh: the same vocabulary, a different weave. Different column
    /// spacing, different vertical offsets, and a genuinely different edge list
    /// (this side carries a long chord along its base instead of its far edge),
    /// so the pair reads as two halves of one strange mind rather than a mirror.
    static let right = JujuAmbienceHemisphere(
        nodes: [
            CGPoint(x: 0.03, y: 0.53),  // 0 — entry, touches the greeting
            CGPoint(x: 0.20, y: 0.20),  // 1
            CGPoint(x: 0.29, y: 0.54),  // 2
            CGPoint(x: 0.15, y: 0.83),  // 3
            CGPoint(x: 0.45, y: 0.34),  // 4
            CGPoint(x: 0.52, y: 0.69),  // 5
            CGPoint(x: 0.69, y: 0.15),  // 6
            CGPoint(x: 0.63, y: 0.47),  // 7
            CGPoint(x: 0.80, y: 0.78),  // 8
            CGPoint(x: 0.95, y: 0.50),  // 9
        ],
        edges: [
            (0, 1), (0, 2), (0, 3),
            (1, 2), (2, 3),
            (1, 4), (2, 4), (2, 5), (3, 5),
            (4, 5),
            (1, 6),                     // long chord across the crown
            (4, 7), (5, 7),
            (3, 8), (5, 8),             // long chord along the base
            (6, 7), (6, 9),
            (7, 8), (7, 9),
        ],
        entry: 0
    )
}

// MARK: - Strike Model

/// One cascade: a spark entering `origin` and fanning out across the mesh.
/// Purely descriptive — `frame(at:)` turns it into pixels for a given moment,
/// which keeps the whole animation testable without timers or SwiftUI.
struct JujuAmbienceStrike {
    /// A single travelling pulse on one thread.
    struct Wave: Equatable {
        let from: Int
        let to: Int
        let edge: Int
        let start: CGFloat
        let end: CGFloat
        /// Brightness this hop carries (0...1). Each hop out from the origin is
        /// dimmer than the last, so a cascade visibly spends itself travelling.
        let energy: CGFloat

        /// How far the head has travelled (0...1), or nil if it is not on the wire.
        func progress(at elapsed: CGFloat) -> CGFloat? {
            guard end > start, elapsed >= start, elapsed < end else { return nil }
            return JujuAmbienceStrike.easeTravel((elapsed - start) / (end - start))
        }
    }

    /// A neuron that keeps glimmering, briefly and repeatedly, after the main
    /// cascade has already spent it — the mesh settling rather than going dark.
    struct Aftershock: Equatable {
        let node: Int
        /// Seconds from strike start to the first glimmer.
        let start: CGFloat
        /// How many times it glimmers.
        let pulses: Int
        /// Seconds between glimmers.
        let period: CGFloat
        /// Peak brightness of each glimmer (well below a fired neuron).
        let peak: CGFloat
    }

    // MARK: Envelope (the "feel" of a synapse)

    /// Near-invisible resting brightness of a node.
    static let rest: CGFloat = 0.08
    /// Peak brightness of a freshly fired node.
    static let hot: CGFloat = 1.0
    /// Sharp attack — a synapse snaps, it does not fade up.
    static let attack: CGFloat = 0.06
    /// Brief hold at peak.
    static let hold: CGFloat = 0.05
    /// Slow, lingering decay. After the snap the light takes its time to go, so
    /// a fired neuron keeps a soft ember rather than blinking straight out.
    static let decay: CGFloat = 0.50
    /// How long a thread keeps glowing after a pulse has passed.
    static let afterglow: CGFloat = 0.26
    /// Pause between the greeting's flash and the first node igniting.
    static let leadIn: CGFloat = 0.10

    /// Each successive hop takes this much longer than the one before, so the
    /// cascade rushes out of the origin and then visibly slows as it spreads —
    /// a wave losing momentum, not a metronome.
    static let hopGrowth: CGFloat = 1.22

    /// Brightness carried by each successive hop.
    static let hopFalloff: CGFloat = 0.80
    /// Floor on hop brightness, so the furthest twigs still glimmer faintly.
    static let minHopEnergy: CGFloat = 0.40

    /// Aftershocks: the shallow, repeated glimmers that outlast the cascade.
    static let glimmerPeak: CGFloat = 0.5
    static let glimmerDecay: CGFloat = 0.16
    /// Quiet beat between the cascade's last arrival and the first aftershock.
    static let glimmerGap: CGFloat = 0.18

    /// The greeting's own flash — the spark that starts everything.
    static let greetingAttack: CGFloat = 0.08
    static let greetingHold: CGFloat = 0.14
    static let greetingDecay: CGFloat = 0.40

    /// A pulse leaves fast and settles as it arrives, so the head visibly
    /// decelerates over the second half of every thread.
    static func easeTravel(_ t: CGFloat) -> CGFloat {
        let clamped = min(max(t, 0), 1)
        return 1 - pow(1 - clamped, 1.8)
    }

    /// The brightness a hop carries once it is `depth` threads out from the
    /// origin (depth 0 = the origin itself, at full strength).
    static func energy(atHop depth: Int) -> CGFloat {
        max(minHopEnergy, pow(hopFalloff, CGFloat(depth)))
    }

    let hemisphere: JujuAmbienceHemisphere
    let origin: Int
    /// When each node fires (seconds from strike start); nil = never reached.
    let arrivals: [CGFloat?]
    /// Peak brightness each node reaches — dimmer the further it sits from the
    /// greeting, so the mesh reads as a wave rather than a uniform flash.
    let nodePeak: [CGFloat]
    /// The threads each pulse travels, in the order the cascade reached them.
    let waves: [Wave]
    /// Late glimmers from neurons the cascade already spent.
    let aftershocks: [Aftershock]
    /// Total lifetime of the cascade, including every aftershock.
    let duration: CGFloat

    /// Fan a spark out from `origin` as a breadth-first wave, stopping after
    /// `maxHops` so some strikes wash over the whole mesh while others only
    /// ripple through a corner of it. Each hop is longer and dimmer than the
    /// last, and a seeded handful of neurons glimmer on afterwards.
    /// - Parameters:
    ///   - hemisphere: the mesh to fire through.
    ///   - origin: the node the spark enters (the greeting-adjacent entry).
    ///   - maxHops: how many threads the cascade may travel from the origin.
    ///   - hopDuration: seconds a pulse takes to cross the first thread.
    ///   - aftershockSeed: chooses which spent neurons glimmer (pure, not random,
    ///     so the same seed always yields the same cascade).
    init(
        hemisphere: JujuAmbienceHemisphere,
        origin: Int,
        maxHops: Int,
        hopDuration: CGFloat,
        aftershockSeed: UInt64 = 0
    ) {
        self.hemisphere = hemisphere
        self.origin = origin

        var arrivals = [CGFloat?](repeating: nil, count: hemisphere.nodes.count)
        var nodePeak = [CGFloat](repeating: JujuAmbienceStrike.rest, count: hemisphere.nodes.count)
        var waves: [Wave] = []
        if hemisphere.nodes.indices.contains(origin) {
            arrivals[origin] = JujuAmbienceStrike.leadIn
            nodePeak[origin] = JujuAmbienceStrike.hot

            var frontier = [origin]
            var depth = 0
            var depthStart = JujuAmbienceStrike.leadIn
            while depth < maxHops, !frontier.isEmpty {
                // This hop runs to the next depth: a little slower, a little dimmer.
                let hop = hopDuration * pow(JujuAmbienceStrike.hopGrowth, CGFloat(depth))
                let depthEnd = depthStart + hop
                let energy = JujuAmbienceStrike.energy(atHop: depth + 1)

                var next: [Int] = []
                for a in frontier {
                    for b in hemisphere.neighbours[a] where arrivals[b] == nil {
                        arrivals[b] = depthEnd
                        nodePeak[b] = JujuAmbienceStrike.hot * energy
                        if let edge = hemisphere.edgeIndex(a, b) {
                            waves.append(Wave(
                                from: a,
                                to: b,
                                edge: edge,
                                start: depthStart,
                                end: depthEnd,
                                energy: energy
                            ))
                        }
                        next.append(b)
                    }
                }
                frontier = next
                depthStart = depthEnd
                depth += 1
            }
        }
        self.arrivals = arrivals
        self.nodePeak = nodePeak
        self.waves = waves

        let lastArrival = arrivals.compactMap { $0 }.max() ?? 0
        let cascadeEnd = lastArrival
            + JujuAmbienceStrike.attack
            + JujuAmbienceStrike.hold
            + JujuAmbienceStrike.decay
            + JujuAmbienceStrike.afterglow

        let aftershocks = JujuAmbienceStrike.makeAftershocks(
            arrivals: arrivals,
            nodePeak: nodePeak,
            seed: aftershockSeed,
            lastArrival: lastArrival
        )
        self.aftershocks = aftershocks

        // The strike lasts until the last glimmer has fully faded.
        let aftershockEnd = aftershocks.map { shock in
            shock.start
                + CGFloat(shock.pulses - 1) * shock.period
                + JujuAmbienceStrike.attack
                + JujuAmbienceStrike.hold
                + JujuAmbienceStrike.glimmerDecay
        }.max() ?? 0
        self.duration = max(cascadeEnd, aftershockEnd)
    }

    /// Pick one or two neurons the cascade already spent and let them glimmer a
    /// few times as it settles. Derived from `seed` alone, so a cascade stays a
    /// pure function of its inputs and can never flicker between frames.
    private static func makeAftershocks(
        arrivals: [CGFloat?],
        nodePeak: [CGFloat],
        seed: UInt64,
        lastArrival: CGFloat
    ) -> [Aftershock] {
        let candidates = arrivals.indices.filter { index in
            arrivals[index] != nil && nodePeak[index] > rest
        }
        guard !candidates.isEmpty else { return [] }

        var cursor = mix(seed)
        let wanted = 1 + Int(cursor % 2)
        var chosen: [Int] = []
        for _ in 0..<wanted where chosen.count < candidates.count {
            cursor = mix(cursor)
            let pick = candidates[Int(cursor % UInt64(candidates.count))]
            if !chosen.contains(pick) { chosen.append(pick) }
        }

        return chosen.enumerated().map { order, node in
            let hash = mix(seed &+ UInt64(node))
            return Aftershock(
                node: node,
                start: lastArrival + decay + glimmerGap + CGFloat(order) * 0.12,
                pulses: 2 + Int(hash % 2),
                period: 0.20 + 0.06 * CGFloat(mix(hash) % 100) / 100,
                peak: glimmerPeak * nodePeak[node]
            )
        }
    }

    /// A cheap, stable avalanche hash — deterministic variation, no RNG state.
    private static func mix(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Frame Derivation (pure)

/// The travelling head of one pulse, ready to draw.
struct JujuAmbiencePulse: Equatable {
    let from: Int
    let to: Int
    let progress: CGFloat
    /// How bright this head still is — it dims with every hop it travels.
    let energy: CGFloat
}

/// Everything needed to draw one mesh at one instant.
struct JujuAmbienceFrame {
    var nodeLevels: [CGFloat]
    var edgeGlow: [CGFloat]
    var pulses: [JujuAmbiencePulse]

    /// The quiet state: faint pins, dormant threads, no activity.
    static func rest(_ hemisphere: JujuAmbienceHemisphere) -> JujuAmbienceFrame {
        JujuAmbienceFrame(
            nodeLevels: Array(repeating: JujuAmbienceStrike.rest, count: hemisphere.nodes.count),
            edgeGlow: Array(repeating: 0, count: hemisphere.edges.count),
            pulses: []
        )
    }
}

/// Both meshes plus the greeting's flash, for one instant.
struct JujuAmbienceScene {
    var left: JujuAmbienceFrame
    var right: JujuAmbienceFrame
    var greetingGlow: CGFloat

    static let rest = JujuAmbienceScene(
        left: JujuAmbienceFrame.rest(JujuAmbienceHemisphere.left),
        right: JujuAmbienceFrame.rest(JujuAmbienceHemisphere.right),
        greetingGlow: 0
    )
}

extension JujuAmbienceStrike {
    /// The full visual state of this cascade at `elapsed` seconds.
    func frame(at elapsed: CGFloat) -> JujuAmbienceFrame {
        var levels = [CGFloat](repeating: JujuAmbienceStrike.rest, count: hemisphere.nodes.count)
        for (index, arrival) in arrivals.enumerated() {
            guard let arrival = arrival else { continue }
            levels[index] = nodeLevel(firedAt: arrival, peak: nodePeak[index], elapsed: elapsed)
        }

        // Aftershocks: shallow, repeated glimmers from neurons already spent.
        for shock in aftershocks where hemisphere.nodes.indices.contains(shock.node) {
            for pulse in 0..<shock.pulses {
                let local = elapsed - (shock.start + CGFloat(pulse) * shock.period)
                let level = JujuAmbienceStrike.rest
                    + glimmer(at: local, peak: shock.peak)
                levels[shock.node] = max(levels[shock.node], level)
            }
        }

        var glow = [CGFloat](repeating: 0, count: hemisphere.edges.count)
        var pulses: [JujuAmbiencePulse] = []
        for wave in waves {
            if glow.indices.contains(wave.edge) {
                glow[wave.edge] = max(
                    glow[wave.edge],
                    edgeGlow(for: wave, elapsed: elapsed) * wave.energy
                )
            }
            if let progress = wave.progress(at: elapsed) {
                pulses.append(JujuAmbiencePulse(
                    from: wave.from,
                    to: wave.to,
                    progress: progress,
                    energy: wave.energy
                ))
            }
        }
        return JujuAmbienceFrame(nodeLevels: levels, edgeGlow: glow, pulses: pulses)
    }

    /// The greeting's own flash: a fast warm bloom, then a soft fade.
    func greetingGlow(at elapsed: CGFloat) -> CGFloat {
        guard elapsed >= 0 else { return 0 }
        if elapsed < JujuAmbienceStrike.greetingAttack {
            return elapsed / JujuAmbienceStrike.greetingAttack
        }
        let afterAttack = elapsed - JujuAmbienceStrike.greetingAttack
        if afterAttack < JujuAmbienceStrike.greetingHold { return 1 }
        let afterHold = afterAttack - JujuAmbienceStrike.greetingHold
        if afterHold < JujuAmbienceStrike.greetingDecay {
            return 1 - afterHold / JujuAmbienceStrike.greetingDecay
        }
        return 0
    }

    /// A node's brightness: snap to its peak, hold, then decay back to rest.
    private func nodeLevel(firedAt arrival: CGFloat, peak: CGFloat, elapsed: CGFloat) -> CGFloat {
        let sinceFire = elapsed - arrival
        guard sinceFire > 0 else { return JujuAmbienceStrike.rest }
        if sinceFire < JujuAmbienceStrike.attack {
            return JujuAmbienceStrike.rest
                + (peak - JujuAmbienceStrike.rest) * (sinceFire / JujuAmbienceStrike.attack)
        }
        let afterAttack = sinceFire - JujuAmbienceStrike.attack
        if afterAttack < JujuAmbienceStrike.hold { return peak }
        let afterHold = afterAttack - JujuAmbienceStrike.hold
        if afterHold < JujuAmbienceStrike.decay {
            return JujuAmbienceStrike.rest
                + (peak - JujuAmbienceStrike.rest) * (1 - afterHold / JujuAmbienceStrike.decay)
        }
        return JujuAmbienceStrike.rest
    }

    /// One late glimmer: the same sharp attack as a fire, but shallower and far
    /// quicker to leave — an ember, not a strike.
    private func glimmer(at local: CGFloat, peak: CGFloat) -> CGFloat {
        guard local > 0 else { return 0 }
        if local < JujuAmbienceStrike.attack {
            return peak * (local / JujuAmbienceStrike.attack)
        }
        let afterAttack = local - JujuAmbienceStrike.attack
        if afterAttack < JujuAmbienceStrike.hold { return peak }
        let afterHold = afterAttack - JujuAmbienceStrike.hold
        if afterHold < JujuAmbienceStrike.glimmerDecay {
            return peak * (1 - afterHold / JujuAmbienceStrike.glimmerDecay)
        }
        return 0
    }

    /// A thread's glow: full while the pulse is on it, then a short afterglow.
    private func edgeGlow(for wave: Wave, elapsed: CGFloat) -> CGFloat {
        if elapsed < wave.start { return 0 }
        if elapsed < wave.end { return 1 }
        let after = elapsed - wave.end
        if after < JujuAmbienceStrike.afterglow {
            return 1 - after / JujuAmbienceStrike.afterglow
        }
        return 0
    }
}

// MARK: - Spark Controller

/// Owns the cadence of the thought mesh: long quiet gaps, then one fast burst.
/// Between strikes it holds no timers at all, so the dashboard is genuinely
/// idle; during a burst it drives a single 60Hz tick that publishes the pure
/// `frame(at:)` output. Each side fires in turn, so both halves stay alive.
final class JujuAmbienceController: ObservableObject {
    /// The current visual state of both meshes and the greeting flash.
    @Published private(set) var scene: JujuAmbienceScene

    /// Quiet gap between cascades (seconds) — deliberately sparse.
    private static let idleRange: ClosedRange<Double> = 3.5...7.0
    /// Burst tick — only runs while a cascade is in flight.
    private static let tick: TimeInterval = 1.0 / 60.0

    private var strike: JujuAmbienceStrike?
    private var strikeIsLeft = true
    private var nextIsLeft = true
    private var strikeStarted: Date?
    private var burstTimer: Timer?
    private var idleTimer: Timer?

    init() {
        scene = .rest
    }

    /// Begin the sparse cadence. Safe to call repeatedly.
    func start() {
        stop()
        scheduleIdle()
    }

    /// Cancel everything and settle back to rest. Called on disappear / deinit.
    func stop() {
        idleTimer?.invalidate()
        idleTimer = nil
        burstTimer?.invalidate()
        burstTimer = nil
        strike = nil
        strikeStarted = nil
        scene = .rest
    }

    // MARK: Cadence

    /// Wait a quiet, random gap, then fire.
    private func scheduleIdle() {
        idleTimer?.invalidate()
        let delay = Double.random(in: Self.idleRange)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.launchStrike()
        }
        RunLoop.main.add(timer, forMode: .common)
        idleTimer = timer
    }

    /// Build one cascade and start its burst clock.
    private func launchStrike() {
        idleTimer = nil
        let hemisphere = nextIsLeft ? JujuAmbienceHemisphere.left : JujuAmbienceHemisphere.right
        strikeIsLeft = nextIsLeft
        nextIsLeft.toggle()

        // Mostly partial cascades; occasionally the whole mesh lights up.
        let fullSurge = Int.random(in: 0..<5) == 0
        let maxHops = fullSurge ? 6 : Int.random(in: 2...4)
        let hopDuration = CGFloat.random(in: 0.12...0.16)

        let strike = JujuAmbienceStrike(
            hemisphere: hemisphere,
            origin: hemisphere.entry,
            maxHops: maxHops,
            hopDuration: hopDuration,
            // A fresh seed each time, so no two cascades glimmer alike.
            aftershockSeed: UInt64.random(in: 0..<UInt64.max)
        )
        self.strike = strike
        strikeStarted = Date()
        publish(elapsed: 0)
        startBurst()
    }

    private func startBurst() {
        burstTimer?.invalidate()
        let timer = Timer(timeInterval: Self.tick, repeats: true) { [weak self] _ in
            self?.burstTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        burstTimer = timer
    }

    private func burstTick() {
        guard let strike = strike, let started = strikeStarted else { return }
        let elapsed = CGFloat(Date().timeIntervalSince(started))
        if elapsed >= strike.duration {
            finishStrike()
        } else {
            publish(elapsed: elapsed)
        }
    }

    private func finishStrike() {
        burstTimer?.invalidate()
        burstTimer = nil
        strike = nil
        strikeStarted = nil
        scene = .rest
        scheduleIdle()
    }

    /// Publish the pure frame for this instant, leaving the dormant side at rest.
    private func publish(elapsed: CGFloat) {
        guard let strike = strike else { return }
        let frame = strike.frame(at: elapsed)
        scene = JujuAmbienceScene(
            left: strikeIsLeft ? frame : JujuAmbienceFrame.rest(JujuAmbienceHemisphere.left),
            right: strikeIsLeft ? JujuAmbienceFrame.rest(JujuAmbienceHemisphere.right) : frame,
            greetingGlow: strike.greetingGlow(at: elapsed)
        )
    }

    deinit {
        stop()
    }
}

// MARK: - Juju Ambience View

/// The dashboard greeting frame: two meshes reaching across the full width of
/// the panel, the Te reo phrase calm between them. When the phrase flashes,
/// one mesh fires — a fast cascade down its threads — then everything settles
/// back to a faint lattice.
/// Pure presentation: no hit testing, no data, no business logic.
struct JujuAmbience: View {
    let text: String
    let gloss: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var controller = JujuAmbienceController()
    @State private var entrance: CGFloat = 0

    /// Tall enough for a woven mesh without bloating the header.
    private static let bandHeight: CGFloat = 128
    private static let clusterMinWidth: CGFloat = 120
    private static let clusterIdealWidth: CGFloat = 340
    private static let clusterMaxWidth: CGFloat = 480
    private static let headingMinWidth: CGFloat = 180
    private static let headingIdealWidth: CGFloat = 300
    private static let headingMaxWidth: CGFloat = 360
    /// The greeting's flash: a compact ellipse hugging the words, not a wash
    /// across the whole band. It fades to nothing at its own edge.
    private static let greetingGlowWidth: CGFloat = 260
    private static let greetingGlowHeight: CGFloat = 84

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            // Left mind — its own mesh, its own turn in the rotation.
            HemisphereCluster(hemisphere: .left, frame: controller.scene.left)
                .frame(
                    minWidth: Self.clusterMinWidth,
                    idealWidth: Self.clusterIdealWidth,
                    maxWidth: Self.clusterMaxWidth,
                    minHeight: Self.bandHeight,
                    idealHeight: Self.bandHeight,
                    maxHeight: Self.bandHeight
                )

            // The voice — calm, static, and the origin of every cascade.
            heading()
                .frame(
                    minWidth: Self.headingMinWidth,
                    idealWidth: Self.headingIdealWidth,
                    maxWidth: Self.headingMaxWidth
                )
                .layoutPriority(1)

            // Right mind — independent geometry, independent timing.
            HemisphereCluster(hemisphere: .right, frame: controller.scene.right)
                .frame(
                    minWidth: Self.clusterMinWidth,
                    idealWidth: Self.clusterIdealWidth,
                    maxWidth: Self.clusterMaxWidth,
                    minHeight: Self.bandHeight,
                    idealHeight: Self.bandHeight,
                    maxHeight: Self.bandHeight
                )
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .opacity(entrance)
        .scaleEffect(reduceMotion ? 1 : (0.96 + 0.04 * entrance))
        .allowsHitTesting(false)
        .onAppear {
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.2)) { entrance = 1 }
            } else {
                withAnimation(Theme.Design.spring) { entrance = 1 }
                controller.start()
            }
        }
        .onDisappear {
            controller.stop()
        }
        .onChange(of: reduceMotion) { reduced in
            if reduced {
                controller.stop()
            } else {
                controller.start()
            }
        }
    }

    // MARK: - Greeting

    /// Plain editorial typography — the calm voice — wrapped in a small warm
    /// bloom that flares in the instant this phrase sparks a cascade. The bloom
    /// is deliberately compact (well inside the band, fading to nothing at its
    /// own edge) and restrained, so the words stay the brightest thing here.
    @ViewBuilder
    private func heading() -> some View {
        VStack(alignment: .center, spacing: Theme.Spacing.xs) {
            Text(text)
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textPrimary)
                .shadow(
                    color: Theme.Colors.glow.opacity(0.30 * controller.scene.greetingGlow),
                    radius: 7
                )
            Text(gloss)
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
        }
        .background(
            EllipticalGradient(
                colors: [
                    Theme.Colors.glow.opacity(0.10 * controller.scene.greetingGlow),
                    Theme.Colors.glow.opacity(0),
                ],
                center: .center,
                startRadiusFraction: 0,
                endRadiusFraction: 0.5
            )
            .frame(width: Self.greetingGlowWidth, height: Self.greetingGlowHeight)
        )
    }
}

/// One mesh of the ambience header, drawn from its topology and the current
/// frame. A single `Canvas` keeps this to one view per side (no per-node view
/// churn) and lets threads be true hairline strokes with travelling pulses.
///
/// The canvas is deliberately larger than the layout frame and anchored to the
/// greeting-facing edge, so the weave spills outward past its container and
/// dissolves into a fade. That reads as a fragment of a much larger plane
/// rather than a closed diagram — while the nodes beside the phrase stay put.
private struct HemisphereCluster: View {
    let hemisphere: JujuAmbienceHemisphere
    let frame: JujuAmbienceFrame

    /// Keeps glowing nodes and their halos inside the band.
    private static let inset: CGFloat = 5
    /// How far the weave spills past its container edge, in points. Kept inside
    /// `Theme.DashboardLayout.dashboardPadding` (48) so the mesh fades to
    /// nothing *before* the panel clips it — a hard clip would defeat the fade.
    private static let outerBleed: CGFloat = 44
    /// Vertical spill, kept inside the neighbouring cards' spacing.
    private static let verticalBleed: CGFloat = 16

    /// The entry node faces the greeting, so that side is the "inner" edge.
    private var innerIsLeading: Bool {
        hemisphere.nodes.indices.contains(hemisphere.entry)
            && hemisphere.nodes[hemisphere.entry].x < 0.5
    }
    private var outerIsLeading: Bool { !innerIsLeading }
    private var innerAlignment: Alignment { innerIsLeading ? .leading : .trailing }

    var body: some View {
        GeometryReader { geometry in
            let layout = geometry.size
            let canvas = CGSize(
                width: layout.width + Self.outerBleed,
                height: layout.height + Self.verticalBleed * 2
            )
            Canvas { context, size in
                let points = hemisphere.nodes.map { map($0, in: size) }
                drawThreads(in: &context, points: points)
                drawNodes(in: &context, points: points)
                drawPulses(in: &context, points: points)
            }
            .frame(width: canvas.width, height: canvas.height)
            .mask(outerFade(canvasWidth: canvas.width))
            .mask(verticalFade(canvasHeight: canvas.height))
            // Anchor the oversized canvas to the greeting-facing edge so the
            // overflow all goes outward, never over the phrase.
            .frame(width: layout.width, height: layout.height, alignment: innerAlignment)
        }
    }

    // MARK: - Overflow fade

    /// Fully drawn across the container, then dissolving to nothing across the
    /// outward spill. The greeting-facing edge is never dimmed.
    private func outerFade(canvasWidth: CGFloat) -> LinearGradient {
        let visibleEdge = Self.outerBleed / max(canvasWidth, 1)
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.5), location: visibleEdge * 0.5),
                .init(color: .white, location: visibleEdge),
                .init(color: .white, location: 1),
            ],
            startPoint: outerIsLeading ? .leading : .trailing,
            endPoint: outerIsLeading ? .trailing : .leading
        )
    }

    /// A gentle top-and-bottom dissolve, so the band's ceiling and floor read as
    /// mist rather than a cut.
    private func verticalFade(canvasHeight: CGFloat) -> LinearGradient {
        let visibleEdge = Self.verticalBleed / max(canvasHeight, 1)
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white, location: visibleEdge),
                .init(color: .white, location: 1 - visibleEdge),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Drawing

    /// Filigree threads: a faint structural lattice, warmed to a bright line
    /// with a soft bloom while a pulse is on the wire.
    private func drawThreads(in context: inout GraphicsContext, points: [CGPoint]) {
        for (index, edge) in hemisphere.edges.enumerated() {
            guard points.indices.contains(edge.0), points.indices.contains(edge.1) else { continue }
            let path = line(from: points[edge.0], to: points[edge.1])

            context.stroke(
                path,
                with: .color(Theme.Colors.textSecondary.opacity(hemisphere.restOpacity(forEdgeAt: index))),
                lineWidth: 1
            )

            let heat = frame.edgeGlow.indices.contains(index) ? frame.edgeGlow[index] : 0
            guard heat > 0.01 else { continue }
            context.stroke(
                path,
                with: .color(Theme.Colors.warmAccent.opacity(0.22 * heat)),
                lineWidth: 2.6
            )
            context.stroke(
                path,
                with: .color(Theme.Colors.glow.opacity(0.16 + 0.60 * heat)),
                lineWidth: 1
            )
        }
    }

    /// Warm nodes: a near-invisible pin at rest that snaps bright with a halo
    /// the instant its thread delivers a pulse.
    private func drawNodes(in context: inout GraphicsContext, points: [CGPoint]) {
        for (index, point) in points.enumerated() {
            let level = frame.nodeLevels.indices.contains(index)
                ? frame.nodeLevels[index]
                : JujuAmbienceStrike.rest

            let halo = 4 + 8 * level
            context.fill(
                circle(at: point, radius: halo),
                with: .radialGradient(
                    Gradient(colors: [
                        Theme.Colors.glow.opacity(0.30 * level),
                        Theme.Colors.glow.opacity(0),
                    ]),
                    center: point,
                    startRadius: 0,
                    endRadius: halo
                )
            )

            let core = 1.6 + 1.7 * level
            context.fill(
                circle(at: point, radius: core),
                with: .color(Theme.Colors.glow.opacity(0.12 + 0.55 * level))
            )
        }
    }

    /// The travelling heads: a small white-hot dot with a halo, riding the wire
    /// from one neuron to the next. Each hop out is dimmer than the last, so a
    /// cascade visibly fades as it spreads.
    private func drawPulses(in context: inout GraphicsContext, points: [CGPoint]) {
        for pulse in frame.pulses {
            guard points.indices.contains(pulse.from), points.indices.contains(pulse.to) else { continue }
            let from = points[pulse.from]
            let to = points[pulse.to]
            let progress = min(max(pulse.progress, 0), 1)
            let energy = min(max(pulse.energy, 0), 1)
            let head = CGPoint(
                x: from.x + (to.x - from.x) * progress,
                y: from.y + (to.y - from.y) * progress
            )

            let halo = 7 + 3 * energy
            context.fill(
                circle(at: head, radius: halo),
                with: .radialGradient(
                    Gradient(colors: [
                        Theme.Colors.glow.opacity(0.55 * energy),
                        Theme.Colors.glow.opacity(0),
                    ]),
                    center: head,
                    startRadius: 0,
                    endRadius: halo
                )
            )
            context.fill(
                circle(at: head, radius: 1.8 + 0.8 * energy),
                with: .color(Theme.Colors.glow.opacity(0.35 + 0.65 * energy))
            )
        }
    }

    // MARK: - Geometry

    /// Scale a normalised topology point into the (oversized) canvas.
    ///
    /// The visible container occupies `outerBleed`..`outerBleed + width` of the
    /// canvas on the outward side and is flush with the inner edge. A point is
    /// mapped into the visible region exactly as before, then pushed outward in
    /// proportion to how far it already sits from the greeting — so the nodes
    /// beside the phrase hold their position while the far side of the weave
    /// reaches past the container and into the fade.
    private func map(_ point: CGPoint, in canvasSize: CGSize) -> CGPoint {
        let inset = Self.inset
        let bleedsOutward = outerIsLeading
        let visibleWidth = max(canvasSize.width - Self.outerBleed, 1)
        let visibleHeight = max(canvasSize.height - Self.verticalBleed * 2, 1)

        let inVisible = CGPoint(
            x: inset + point.x * max(visibleWidth - inset * 2, 1),
            y: inset + point.y * max(visibleHeight - inset * 2, 1)
        )
        let outwardness = innerIsLeading ? point.x : (1 - point.x)
        let push = Self.outerBleed * outwardness

        return CGPoint(
            x: bleedsOutward ? Self.outerBleed + inVisible.x - push : inVisible.x + push,
            y: Self.verticalBleed + inVisible.y
        )
    }

    private func line(from: CGPoint, to: CGPoint) -> Path {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        return path
    }

    private func circle(at center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }
}
