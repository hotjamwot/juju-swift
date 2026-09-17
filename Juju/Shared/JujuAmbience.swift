import Foundation
import SwiftUI

// MARK: - Juju Ambience
//
// The quiet, editorial frame behind the dashboard greeting — "The Thought
// Constellation". A sparse network of warm nodes spanning the width of the
// band. Every few seconds a thought fires: one node ignites and the impulse
// travels light-to-light along its dotted threads (with a fading trail),
// reading as one idea triggering the next — the creative juju. Between
// firings it settles back to a near-invisible set of pins.
//
// Why this design (Theme.swift is the source of truth):
// - "The chrome should nearly disappear." The network is invisible at rest;
//   only the moment of a signal exposes it, then it recedes.
// - "Hue belongs to the data." No added colour — only theme warm tones.
// - No ellipsis-like symmetric dots; the nodes are asymmetric and the signal
//   *travels* rather than a single point blinking in the centre.
// - The greeting itself is plain static typography — the calm voice.
//
// Lightweight: the cadence is ONE repeating 0.5s Timer (owned by a @StateObject
// controller) that only mutates the node brightness changing in that instant.
// Between ticks the dashboard is fully idle; closing the window (or leaving
// the section) invalidates the timer, so it costs nothing while dormant.

// MARK: - Spark Controller

/// Builds a looping "score" (node, brightness) timeline at start, applies one
/// note per tick so only the active node's brightness changes at a time, and
/// uses decay tails to give the travelling signal a fading trail.
final class JujuAmbienceController: ObservableObject {
    @Published var node0: CGFloat = 0.10
    @Published var node1: CGFloat = 0.10
    @Published var node2: CGFloat = 0.10
    @Published var node3: CGFloat = 0.10
    @Published var node4: CGFloat = 0.10
    @Published var node5: CGFloat = 0.10
    @Published var node6: CGFloat = 0.10

    static let rest: CGFloat = 0.10
    static let hot: CGFloat = 1.0

    private var timer: Timer?
    private var step = 0
    private var score: [(Int, CGFloat)] = []

    func start() {
        stop()
        for i in 0..<7 { setNode(i, JujuAmbienceController.rest) }
        step = 0
        score = JujuAmbienceController.buildScore()
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
        if nIdx >= 0 { setNode(nIdx, value) }
        step += 1
    }

    private func setNode(_ index: Int, _ value: CGFloat) {
        withAnimation(.easeInOut(duration: 0.4)) {
            if index == 0 {
                node0 = value
            } else if index == 1 {
                node1 = value
            } else if index == 2 {
                node2 = value
            } else if index == 3 {
                node3 = value
            } else if index == 4 {
                node4 = value
            } else if index == 5 {
                node5 = value
            } else {
                node6 = value
            }
        }
    }

    /// Flat list of (node, brightness) notes, played one per tick. Each
    /// journey (a path through the network) lights sequentially with a decay
    /// trail behind the head; journeys are separated by rests.
    static func buildScore() -> [(Int, CGFloat)] {
        let journeys: [[Int]] = [
            [0, 1, 3, 4],
            [2, 3, 4, 6],
            [5, 4, 3, 1, 0],
            [6, 4, 2],
            [3, 4, 5],
            [1, 3, 4, 6],
            [2, 4, 5],
        ]
        var s: [(Int, CGFloat)] = []
        for event in addRest(2) { s.append(event) }     // brief beat on open
        for j in 0..<journeys.count {
            if j > 0 { for event in addRest(6) { s.append(event) } }  // ~3s pause
            for event in emitJourney(journeys[j]) { s.append(event) }
        }
        for event in addRest(6) { s.append(event) }
        return s
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

/// Warm, editorial backdrop for the greeting: the phrase sits calm and plain,
/// and beneath it a sparse network of nodes fires a thought every few seconds.
/// Pure presentation: no hit testing, no data, no business logic.
struct JujuAmbience: View {
    let text: String
    let gloss: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var sparks = JujuAmbienceController()
    @State private var entrance: CGFloat = 0

    var body: some View {
        VStack(alignment: .center, spacing: Theme.Spacing.md) {
            // The voice — the greeting, calm and static.
            heading()

            // The thought constellation — a sparse warm network.
            constellation()
        }
        .opacity(entrance)
        .scaleEffect(reduceMotion ? 1 : (0.96 + 0.04 * entrance))
        .allowsHitTesting(false)
        .onAppear {
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.2)) { entrance = 1 }
            } else {
                withAnimation(Theme.Design.spring) { entrance = 1 }
                sparks.start()
            }
        }
        .onDisappear {
            sparks.stop()
        }
        .onChange(of: reduceMotion) { reduced in
            if reduced {
                sparks.stop()
            } else {
                sparks.start()
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

    // MARK: - Constellation

    /// Seven nodes at irregular, asymmetric positions spanning a fixed-width
    /// band (a small hub-and-spoke "mind"), connected by dotted threads that
    /// expose themselves only when an endpoint fires.
    @ViewBuilder
    private func constellation() -> some View {
        ZStack {
            thread(a: 0, b: 1)
            thread(a: 1, b: 3)
            thread(a: 3, b: 4)
            thread(a: 4, b: 5)
            thread(a: 4, b: 6)
            thread(a: 2, b: 3)
            thread(a: 2, b: 4)

            node(x: 34, y: 30, b: nodeBrightness(0))
            node(x: 86, y: 14, b: nodeBrightness(1))
            node(x: 132, y: 40, b: nodeBrightness(2))
            node(x: 176, y: 26, b: nodeBrightness(3))
            node(x: 228, y: 44, b: nodeBrightness(4))
            node(x: 282, y: 16, b: nodeBrightness(5))
            node(x: 346, y: 30, b: nodeBrightness(6))
        }
        .frame(width: 380, height: 56, alignment: .center)
    }

    /// The dotted thread between two nodes: beads interpolated along the line.
    /// Their opacity rises with the hotter endpoint, so a thread exposes only
    /// in the moment of firing.
    @ViewBuilder
    private func thread(a: Int, b: Int) -> some View {
        let level = max(nodeBrightness(a), nodeBrightness(b))
        let x0 = nodeX(a)
        let y0 = nodeY(a)
        let x1 = nodeX(b)
        let y1 = nodeY(b)
        let f16 = CGFloat(1) / CGFloat(6)
        let f26 = CGFloat(2) / CGFloat(6)
        let f36 = CGFloat(3) / CGFloat(6)
        let f46 = CGFloat(4) / CGFloat(6)
        ZStack {
            bead(x: x0 + (x1 - x0) * f16, y: y0 + (y1 - y0) * f16)
            bead(x: x0 + (x1 - x0) * f26, y: y0 + (y1 - y0) * f26)
            bead(x: x0 + (x1 - x0) * f36, y: y0 + (y1 - y0) * f36)
            bead(x: x0 + (x1 - x0) * f46, y: y0 + (y1 - y0) * f46)
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
    private func node(x: CGFloat, y: CGFloat, b: CGFloat) -> some View {
        Circle()
            .fill(Theme.Colors.glow.opacity(0.06 + 0.50 * b))
            .shadow(color: Theme.Colors.warmAccent.opacity(0.35 * b), radius: 2 + 6 * b)
            .frame(width: 3 + 3 * b, height: 3 + 3 * b)
            .position(x: x, y: y)
    }
private func nodeBrightness(_ index: Int) -> CGFloat {
        if index == 0 { return sparks.node0 }
        if index == 1 { return sparks.node1 }
        if index == 2 { return sparks.node2 }
        if index == 3 { return sparks.node3 }
        if index == 4 { return sparks.node4 }
        if index == 5 { return sparks.node5 }
        return sparks.node6
    }

    private func nodeX(_ index: Int) -> CGFloat {
        if index == 0 { return 34 }
        if index == 1 { return 86 }
        if index == 2 { return 132 }
        if index == 3 { return 176 }
        if index == 4 { return 228 }
        if index == 5 { return 282 }
        return 346
    }

    private func nodeY(_ index: Int) -> CGFloat {
        if index == 0 { return 30 }
        if index == 1 { return 14 }
        if index == 2 { return 40 }
        if index == 3 { return 26 }
        if index == 4 { return 44 }
        if index == 5 { return 16 }
        return 30
    }
}
