import Foundation
import SwiftUI

// MARK: - Juju Ambience
//
// The quiet, editorial frame behind the dashboard greeting — "The Thought
// Constellation", now in two hemispheres. The Te reo greeting sits calm and
// still at the centre; a compact, angular neural cluster floats on either
// side. Every few seconds a thought fires on one side: a node ignites and the
// impulse travels light-to-light along its dotted threads (with a fading
// trail), reading as one idea triggering the next — the creative juju.
// Between firings each side settles back to a near-invisible set of pins.
//
// Why this design (Theme.swift is the source of truth):
// - "The chrome should nearly disappear." Each network is invisible at rest;
//   only the moment of a signal exposes it, then it recedes.
// - "Hue belongs to the data." No added colour — only theme warm tones.
// - The clusters are asymmetric and related rather than mirrored, and each
//   signal *travels* instead of blinking in place.
// - The greeting itself is plain static typography — the calm voice between
//   two quietly thinking halves.
// - The two sides are independent: separate controllers, separate timers,
//   freshly randomised routes and pauses each loop — never synchronised.
//
// Lightweight: the cadence is ONE repeating 0.5s Timer per side (owned by a
// @StateObject controller) that only mutates the node brightness changing in
// that instant. Between ticks the dashboard is fully idle; closing the window
// (or leaving the section) invalidates the timers, so it costs nothing while
// dormant.

// MARK: - Hemisphere Topology

/// One side of the ambience header: a compact cluster of nodes with the
/// threads between them. Positions are absolute points inside a fixed-size
/// band; the two hemispheres share visual weight but are deliberately not
/// mirrored, so the pair reads as two halves of one strange mind.
struct JujuAmbienceHemisphere {
    /// Absolute node positions inside the band.
    let nodes: [CGPoint]
    /// Adjacency list: neighbours[i] holds every node connected to i.
    /// Must be symmetric — every edge appears in both directions.
    let neighbours: [[Int]]

    /// Connected pairs, derived from the adjacency list for drawing threads.
    var edges: [(Int, Int)] {
        var out: [(Int, Int)] = []
        for (a, ends) in neighbours.enumerated() {
            for b in ends where b > a {
                out.append((a, b))
            }
        }
        return out
    }

    /// Left cluster: a low pocket of three nodes joined by a long sparse
    /// thread to an upper pair, with one far satellite.
    static let left = JujuAmbienceHemisphere(
        nodes: [
            CGPoint(x: 28, y: 62),
            CGPoint(x: 58, y: 74),
            CGPoint(x: 74, y: 52),
            CGPoint(x: 118, y: 30),
            CGPoint(x: 148, y: 44),
            CGPoint(x: 186, y: 22),
        ],
        neighbours: [
            [1, 2],
            [0, 2],
            [0, 1, 3],
            [2, 4],
            [3, 5],
            [4],
        ]
    )

    /// Right cluster: an upper triangle dropping through a junction node to
    /// a lower pair — different pockets, different rhythm, same weight.
    static let right = JujuAmbienceHemisphere(
        nodes: [
            CGPoint(x: 14, y: 26),
            CGPoint(x: 48, y: 16),
            CGPoint(x: 64, y: 42),
            CGPoint(x: 108, y: 52),
            CGPoint(x: 142, y: 70),
            CGPoint(x: 172, y: 50),
        ],
        neighbours: [
            [1, 2],
            [0, 2],
            [0, 1, 3],
            [2, 4, 5],
            [3, 5],
            [3, 4],
        ]
    )
}

// MARK: - Spark Controller

/// Drives one hemisphere: plays a randomised "score" (node, brightness)
/// timeline, applying one note per tick so only the active node's brightness
/// changes at a time, with decay tails giving the signal a fading trail.
/// Each `start()` re-randomises routes, journey count and pauses, so no two
/// loops — and no two sides — ever match.
final class JujuAmbienceController: ObservableObject {
    @Published var levels: [CGFloat]

    static let rest: CGFloat = 0.10
    static let hot: CGFloat = 1.0

    private let nodeCount: Int
    private let neighbours: [[Int]]
    private var timer: Timer?
    private var step = 0
    private var score: [(Int, CGFloat)] = []

    init(nodeCount: Int, neighbours: [[Int]]) {
        self.nodeCount = nodeCount
        self.neighbours = neighbours
        self.levels = Array(repeating: JujuAmbienceController.rest, count: nodeCount)
    }

    func start() {
        stop()
        levels = Array(repeating: JujuAmbienceController.rest, count: nodeCount)
        step = 0
        var rng = SystemRandomNumberGenerator()
        score = JujuAmbienceController.buildScore(
            nodeCount: nodeCount, neighbours: neighbours, using: &rng
        )
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        if score.count == 0 { return }
        let (nIdx, value) = score[step % score.count]
        if nIdx >= 0 { setLevel(nIdx, value) }
        step += 1
    }

    private func setLevel(_ index: Int, _ value: CGFloat) {
        guard levels.indices.contains(index) else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            levels[index] = value
        }
    }

    /// A full randomised loop: an opening beat, then a handful of journeys
    /// along fresh random walks, separated by random-length rests.
    static func buildScore<G: RandomNumberGenerator>(
        nodeCount: Int,
        neighbours: [[Int]],
        using generator: inout G
    ) -> [(Int, CGFloat)] {
        var s: [(Int, CGFloat)] = []
        for event in addRest(Int.random(in: 1...3, using: &generator)) { s.append(event) }
        let journeyCount = Int.random(in: 5...8, using: &generator)
        for j in 0..<journeyCount {
            if j > 0 {
                for event in addRest(Int.random(in: 4...9, using: &generator)) { s.append(event) }
            }
            let start = Int.random(in: 0..<nodeCount, using: &generator)
            let length = Int.random(in: 2...5, using: &generator)
            let path = randomWalk(from: start, length: length, neighbours: neighbours, using: &generator)
            for event in emitJourney(path) { s.append(event) }
        }
        for event in addRest(Int.random(in: 4...9, using: &generator)) { s.append(event) }
        return s
    }

    /// A random walk across the cluster's threads: each step follows a real
    /// connection, preferring not to immediately backtrack, so the signal
    /// always travels somewhere meaningful.
    static func randomWalk<G: RandomNumberGenerator>(
        from start: Int,
        length: Int,
        neighbours: [[Int]],
        using generator: inout G
    ) -> [Int] {
        guard length > 0, neighbours.indices.contains(start) else { return [] }
        var path = [start]
        var current = start
        var previous: Int? = nil
        for _ in 1..<length {
            let options = neighbours[current]
            if options.isEmpty { break }
            let onward = options.filter { $0 != previous }
            let pool = onward.isEmpty ? options : onward
            guard let next = pool.randomElement(using: &generator) else { break }
            path.append(next)
            previous = current
            current = next
        }
        return path
    }

    /// Silence: one no-op per tick, without publishing unchanged brightness.
    static func addRest(_ count: Int) -> [(Int, CGFloat)] {
        Array(repeating: (-1, JujuAmbienceController.rest), count: count)
    }

    /// Play a path: light each node to `hot` (held a tick) then up to three
    /// ticks of decay behind the head, so the signal trails as it travels.
    static func emitJourney(_ path: [Int]) -> [(Int, CGFloat)] {
        var out: [(Int, CGFloat)] = []
        var tails: [(Int, Int)] = []   // (node, decay stage 1..3)
        for n in path {
            var keep: [(Int, Int)] = []
            for (tNode, stage) in tails {
                out.append((tNode, decayValue(stage)))
                if stage < 3 { keep.append((tNode, stage + 1)) }
            }
            tails = keep
            out.append((n, JujuAmbienceController.hot))
            out.append((n, JujuAmbienceController.hot))
            tails.append((n, 1))
        }
        var safety = 0
        while tails.count > 0 && safety < 12 {
            safety += 1
            var nxt: [(Int, Int)] = []
            for (tNode, stage) in tails {
                out.append((tNode, decayValue(stage)))
                if stage < 3 { nxt.append((tNode, stage + 1)) }
            }
            tails = nxt
        }
        return out
    }

    static func decayValue(_ stage: Int) -> CGFloat {
        if stage == 1 { return 0.60 }
        if stage == 2 { return 0.36 }
        return JujuAmbienceController.rest
    }

    deinit {
        stop()
    }
}
// MARK: - Juju Ambience View

/// Warm, editorial backdrop for the greeting: the phrase sits calm and still
/// at the centre, with one independent neural cluster on either side firing
/// thoughts every few seconds.
/// Pure presentation: no hit testing, no data, no business logic.
struct JujuAmbience: View {
    let text: String
    let gloss: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var leftSparks = JujuAmbienceController(
        nodeCount: JujuAmbienceHemisphere.left.nodes.count,
        neighbours: JujuAmbienceHemisphere.left.neighbours
    )
    @StateObject private var rightSparks = JujuAmbienceController(
        nodeCount: JujuAmbienceHemisphere.right.nodes.count,
        neighbours: JujuAmbienceHemisphere.right.neighbours
    )
    @State private var entrance: CGFloat = 0

    /// Fixed band size for each neural cluster.
    private static let hemisphereSize = CGSize(width: 200, height: 96)

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            // Left mind — its own controller, its own timing.
            HemisphereCluster(
                hemisphere: .left,
                levels: leftSparks.levels,
                size: Self.hemisphereSize
            )
            .frame(width: Self.hemisphereSize.width, height: Self.hemisphereSize.height)

            // The voice — the greeting, calm and static at the centre.
            heading()
                .frame(maxWidth: .infinity)

            // Right mind — independent of the left.
            HemisphereCluster(
                hemisphere: .right,
                levels: rightSparks.levels,
                size: Self.hemisphereSize
            )
            .frame(width: Self.hemisphereSize.width, height: Self.hemisphereSize.height)
        }
        .opacity(entrance)
        .scaleEffect(reduceMotion ? 1 : (0.96 + 0.04 * entrance))
        .allowsHitTesting(false)
        .onAppear {
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.2)) { entrance = 1 }
            } else {
                withAnimation(Theme.Design.spring) { entrance = 1 }
                // Stagger the two sides so they never start in step.
                leftSparks.start()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    rightSparks.start()
                }
            }
        }
        .onDisappear {
            leftSparks.stop()
            rightSparks.stop()
        }
        .onChange(of: reduceMotion) { reduced in
            if reduced {
                leftSparks.stop()
                rightSparks.stop()
            } else {
                leftSparks.start()
                rightSparks.start()
            }
        }
    }

    // MARK: - Greeting

    /// Plain editorial typography — the calm voice. No glow, no breathe.
    @ViewBuilder
    private func heading() -> some View {
        VStack(alignment: .center, spacing: Theme.Spacing.xs) {
            Text(text)
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textPrimary)
            Text(gloss)
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
        }
    }
}

/// One hemisphere of the ambience header, drawn from its topology.
/// A plain struct (not the parent view) so both sides share the drawing
/// code while keeping fully independent brightness state.
private struct HemisphereCluster: View {
    let hemisphere: JujuAmbienceHemisphere
    let levels: [CGFloat]
    let size: CGSize

    var body: some View {
        ZStack {
            ForEach(Array(hemisphere.edges.enumerated()), id: \.offset) { _, edge in
                thread(a: edge.0, b: edge.1)
            }
            ForEach(hemisphere.nodes.indices, id: \.self) { i in
                node(at: hemisphere.nodes[i], b: nodeBrightness(i))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .center)
    }

    /// The dotted thread between two nodes: beads interpolated along the line.
    /// Their opacity rises with the hotter endpoint, so a thread exposes only
    /// in the moment of firing.
    @ViewBuilder
    private func thread(a: Int, b: Int) -> some View {
        let level = max(nodeBrightness(a), nodeBrightness(b))
        let p0 = hemisphere.nodes[a]
        let p1 = hemisphere.nodes[b]
        let f16 = CGFloat(1) / CGFloat(6)
        let f26 = CGFloat(2) / CGFloat(6)
        let f36 = CGFloat(3) / CGFloat(6)
        let f46 = CGFloat(4) / CGFloat(6)
        ZStack {
            bead(x: p0.x + (p1.x - p0.x) * f16, y: p0.y + (p1.y - p0.y) * f16)
            bead(x: p0.x + (p1.x - p0.x) * f26, y: p0.y + (p1.y - p0.y) * f26)
            bead(x: p0.x + (p1.x - p0.x) * f36, y: p0.y + (p1.y - p0.y) * f36)
            bead(x: p0.x + (p1.x - p0.x) * f46, y: p0.y + (p1.y - p0.y) * f46)
        }
        .opacity(0.035 + 0.30 * level)
    }

    /// One small pin dot on a thread.
    @ViewBuilder
    private func bead(x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(Theme.Colors.divider)
            .frame(width: 2, height: 2)
            .position(x: x, y: y)
    }

    /// One warm node. Resting it is a near-invisible pin; when it fires it
    /// swells and throws a soft warm glow. Opacity/size only — it never moves
    /// in layout, so it never disturbs the dashboard's ScrollView.
    @ViewBuilder
    private func node(at point: CGPoint, b: CGFloat) -> some View {
        Circle()
            .fill(Theme.Colors.glow.opacity(0.06 + 0.50 * b))
            .shadow(color: Theme.Colors.warmAccent.opacity(0.35 * b), radius: 2 + 6 * b)
            .frame(width: 3 + 3 * b, height: 3 + 3 * b)
            .position(x: point.x, y: point.y)
    }

    private func nodeBrightness(_ index: Int) -> CGFloat {
        guard levels.indices.contains(index) else { return JujuAmbienceController.rest }
        return levels[index]
    }
}
