import SwiftUI

// MARK: - Juju Flow Field
//
/// Ambient "juju" animation for the top of the dashboard, behind the
/// JujuPhrase: two slow ink ribbons (dual-stroke sine waves) with glowing
/// orbs that loop around them DNA-helix style.
///
/// ARCHITECTURE — one clock, pure maths:
/// Everything is driven by a single `TimelineView(.animation)` clock. Each
/// frame, every position/size/brightness is computed as a closed-form sine
/// of `clock / period + phase`. No `withAnimation` state loops, no
/// interpolation surprises — the maths IS the animation. This guarantees:
/// - orbs genuinely move vertically (helix wrap),
/// - brightness and size breathe continuously with depth,
/// - speeds are exact and easy to tune.
///
/// Each instance is seeded, so the two halves of the dashboard run on
/// independent, deterministic timelines. With Reduce Motion the clock is
/// frozen at zero — a still, elegant composition.
///
/// Pure presentation: no hit testing, no data, no business logic.
struct JujuFlowField: View {
    // MARK: - Configuration

    /// Seeds all random parameters. Use different values per instance so
    /// the fields on either side of the phrase never move in lockstep.
    let seed: UInt64

    private let params: FlowParameters

    init(seed: UInt64) {
        self.seed = seed
        self.params = FlowParameters(seed: seed)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Geometry constants
    private let fieldHeight: CGFloat = 90

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let clock = reduceMotion ? 0.0 : context.date.timeIntervalSinceReferenceDate

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack {
                    ribbon(params.highRibbon, clock: clock, width: width)
                    ribbon(params.lowRibbon, clock: clock, width: width)

                    ForEach(params.orbs.indices, id: \.self) { index in
                        orb(params.orbs[index], clock: clock, width: width)
                    }
                }
            }
        }
        .frame(height: fieldHeight)
        .clipShape(Rectangle())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Ribbon

    /// One undulating ink ribbon: a wide soft body stroke with a brighter
    /// thin spine on top, both ends dissolving via gradient.
    @ViewBuilder
    private func ribbon(_ spec: FlowParameters.RibbonSpec,
                        clock: Double, width: CGFloat) -> some View {
        let phase = 2 * .pi * clock / spec.period + spec.phaseOffset
        let shape = InkRibbonShape(
            amplitude: spec.amplitude,
            frequency: spec.frequency * Double(width),
            phase: phase
        )

        ZStack {
            // Wide soft body…
            shape.stroke(
                edgeGradient(opacity: spec.opacity),
                style: StrokeStyle(lineWidth: 10, lineCap: .round)
            )
            // …with a brighter thin spine on top.
            shape.stroke(
                edgeGradient(opacity: spec.opacity * 1.5),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
        }
        .blur(radius: 1.5)
        .frame(height: fieldHeight)
        .position(x: width / 2, y: fieldHeight * spec.verticalAnchor)
    }

    /// Horizontal gradient: transparent at both ends, peak in the middle.
    private func edgeGradient(opacity: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                Theme.Colors.warmAccent.opacity(0),
                Theme.Colors.warmAccent.opacity(opacity),
                Theme.Colors.warmAccent.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Orb

    /// One glowing orb looping around its ribbon DNA-helix style.
    /// Vertical sine = the wrap; horizontal cosine = the around-ness;
    /// the sine also drives faux-3D depth (front = bigger/brighter).
    @ViewBuilder
    private func orb(_ spec: FlowParameters.OrbSpec,
                     clock: Double, width: CGFloat) -> some View {
        let ribbon = params.ribbon(for: spec.stream)
        let ribbonPhase = 2 * .pi * clock / ribbon.period + ribbon.phaseOffset

        // Ribbon sample at the orb's nominal centre (t = 0.5) — the shared
        // base both the orb and the curve the eye sees agree on.
        let baseY = fieldHeight * ribbon.verticalAnchor
            + ribbon.amplitude
            * CGFloat(sin(2 * .pi * ribbon.frequency * Double(width) * 0.5 + ribbonPhase))

        // Helix loop around the ribbon.
        let angle = 2 * .pi * clock / spec.helixPeriod + spec.helixPhase
        let depth = sin(angle)                       // 1 = front, -1 = back
        let helixOffsetY = spec.helixRadiusY * CGFloat(depth)
        let helixOffsetX = spec.helixRadiusX * CGFloat(cos(angle))

        // Faux-3D: front of the loop is slightly larger and brighter.
        let depthScale = 1.0 + 0.08 * depth
        let depthOpacity = 0.86 + 0.14 * depth

        // Slow horizontal wander, sinusoidal like everything else.
        let drift = sin(2 * .pi * clock / spec.driftPeriod + spec.driftPhase)
        let x = width * (0.5 + spec.driftRange * CGFloat(drift))

        Circle()
            .fill(spec.color)
            .frame(width: spec.size, height: spec.size)
            .scaleEffect(depthScale)
            .opacity(depthOpacity)
            .shadow(color: spec.color.opacity(0.4 * depthOpacity), radius: spec.size)
            .offset(x: helixOffsetX + x - width / 2, y: helixOffsetY)
            .position(x: width / 2, y: baseY)
    }
}


// MARK: - Flow Parameters
//
/// All seeded-random parameters for one field instance, computed once at
/// init. Speeds are deliberately clustered around a medium tempo (tight
/// ranges) so the field never lurches between very slow and very fast.
struct FlowParameters {
    struct RibbonSpec {
        let verticalAnchor: CGFloat   // 0…1 of field height
        let opacity: Double
        let amplitude: CGFloat
        /// Full wavelengths per 300pt of width — scale stays constant
        /// no matter how wide the field stretches.
        let frequency: Double
        /// Seconds per full undulation.
        let period: Double
        let phaseOffset: Double
    }

    struct OrbSpec {
        enum Stream { case high, low }
        let stream: Stream
        let size: CGFloat
        let color: Color
        let helixRadiusY: CGFloat
        let helixRadiusX: CGFloat
        /// Seconds per full loop around the ribbon.
        let helixPeriod: Double
        let helixPhase: Double
        /// Horizontal wander, as a fraction of half the field width.
        let driftRange: CGFloat
        let driftPeriod: Double
        let driftPhase: Double
    }

    let highRibbon: RibbonSpec
    let lowRibbon: RibbonSpec
    let orbs: [OrbSpec]

    init(seed: UInt64) {
        var rng = SeededGenerator(seed: seed)

        // Ribbons — deep slow swell up top, quicker tighter ripple below.
        highRibbon = RibbonSpec(
            verticalAnchor: 0.32, opacity: 0.14,
            amplitude: 11, frequency: 0.9 / 300,
            period: Double.random(in: 17...21, using: &rng),
            phaseOffset: Double.random(in: 0..<(2 * .pi), using: &rng)
        )
        lowRibbon = RibbonSpec(
            verticalAnchor: 0.70, opacity: 0.09,
            amplitude: 7, frequency: 1.6 / 300,
            period: Double.random(in: 22...26, using: &rng),
            phaseOffset: Double.random(in: 0..<(2 * .pi), using: &rng)
        )

        // Orbs — sizes slightly varied, colours strictly the two sanctioned
        // neutrals (lightest white-ish + warm muted secondary), speeds
        // clustered around medium so nothing races or stalls.
        let colors: [Color] = [Theme.Colors.glow, Theme.Colors.textSecondary]
        orbs = (0..<4).map { index in
            let stream: OrbSpec.Stream = index.isMultiple(of: 2) ? .high : .low
            return OrbSpec(
                stream: stream,
                size: [8, 6, 7, 9][index],
                color: colors[index % 2],
                helixRadiusY: 16,
                helixRadiusX: 9,
                helixPeriod: Double.random(in: 14...18, using: &rng),
                helixPhase: Double.random(in: 0..<(2 * .pi), using: &rng),
                driftRange: 0.38,
                driftPeriod: Double.random(in: 32...40, using: &rng),
                driftPhase: Double.random(in: 0..<(2 * .pi), using: &rng)
            )
        }
    }

    func ribbon(for stream: OrbSpec.Stream) -> RibbonSpec {
        stream == .high ? highRibbon : lowRibbon
    }
}

// MARK: - Ink Ribbon Shape
//
/// A smooth horizontal sine wave with a faint harmonic — a hint of life
/// without crumpling the line. Drawn every frame from the clock-driven
/// `phase`, so no AnimatableData gymnastics are needed.
struct InkRibbonShape: Shape {
    let amplitude: CGFloat
    /// Full wavelengths across the shape's width.
    let frequency: Double
    let phase: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 96
        let midY = rect.midY
        // Gentle harmonic: slow (1.8×), shallow (12%), drifting at a
        // slightly different relative speed so the line breathes.
        let harmonicFrequency = frequency * 1.8
        let harmonicAmplitude = amplitude * 0.12
        let harmonicPhase = phase * 1.4

        path.move(to: CGPoint(x: rect.minX, y: midY))
        for step in 1...steps {
            let t = Double(step) / Double(steps)
            let x = rect.minX + CGFloat(t) * rect.width
            let base = sin(2 * .pi * frequency * t + phase)
            let harmonic = sin(2 * .pi * harmonicFrequency * t + harmonicPhase)
            let y = midY
                + amplitude * CGFloat(base)
                + harmonicAmplitude * CGFloat(harmonic)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

// MARK: - Seeded Generator
//
/// Tiny deterministic RNG (SplitMix64) so each field instance's parameters
/// are stable across launches yet differ between seeds.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
