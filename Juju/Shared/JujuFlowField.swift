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

    /// Which horizontal edge of the field sits beside the JujuPhrase. That
    /// edge is faded out so the animation recedes under the text.
    enum PhraseEdge {
        case leading, trailing
    }

    /// Seeds all random parameters. Use different values per instance so
    /// the fields on either side of the phrase never move in lockstep.
    let seed: UInt64

    /// The edge nearest the JujuPhrase (dimmed to keep the text clear).
    let phraseEdge: PhraseEdge

    private let params: FlowParameters

    init(seed: UInt64, phraseEdge: PhraseEdge) {
        self.seed = seed
        self.phraseEdge = phraseEdge
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
                // Per-orb repulsion offsets (computed once per frame from the
                // nominal positions) so nearby orbs gently push apart.
                let placements = repulsionOffsets(clock: clock, width: width)
                ZStack {
                    // Ghost layer drawn first so the two main ribbons weave
                    // over it.
                    ribbon(params.ghostRibbon, clock: clock, width: width)
                    ribbon(params.highRibbon, clock: clock, width: width)
                    ribbon(params.lowRibbon, clock: clock, width: width)

                    ForEach(params.orbs.indices, id: \.self) { index in
                        orb(params.orbs[index], clock: clock, width: width)
                            .offset(x: placements[index].width,
                                    y: placements[index].height)
                    }
                }
            }
        }
        .frame(height: fieldHeight)
        .clipShape(Rectangle())
        .mask(centreFade())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Gentle dimming near the phrase-facing edge (the window centre), ramping
    /// back to full strength across the outer portion. The animation fills the
    /// whole playpen — it only calms slightly under the text, rather than being
    /// pushed to the far window edges (which made each side cluster outward).
    private func centreFade() -> some View {
        // How transparent the field gets right at the phrase edge (0 = fully
        // clear, 1 = unchanged). Kept above zero so a faint hint still weaves
        // under the text instead of leaving a stark dark gap.
        let floor: Double = 0.35
        // Width (fraction of the field) over which the dimming ramps back to full.
        let ramp = 0.24

        let stops: [Gradient.Stop]
        if phraseEdge == .leading {
            // Phrase sits to our left → dim near x = 0, full by `ramp`.
            stops = [
                .init(color: .black.opacity(floor), location: 0),
                .init(color: .black.opacity((1 + floor) / 2), location: ramp / 2),
                .init(color: .black, location: ramp),
                .init(color: .black, location: 1)
            ]
        } else {
            // Phrase sits to our right → dim near x = 1, full before `1 - ramp`.
            stops = [
                .init(color: .black, location: 0),
                .init(color: .black, location: 1 - ramp),
                .init(color: .black.opacity((1 + floor) / 2), location: 1 - ramp / 2),
                .init(color: .black.opacity(floor), location: 1)
            ]
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - Ribbon

    /// One translucent ribbon of sheer fabric, gently twisting as it drifts.
    /// It's drawn as a filled band whose thickness narrows at each twist
    /// (edge-on) and widens where face-on, shaded by travelling light/dark
    /// facets (the folds) on top of a lit-from-above wash — so it reads as
    /// see-through cloth catching light, not a printed line. Pinned at the
    /// ends and slowly swelling, it flexes and turns like silk in a breeze.
    @ViewBuilder
    private func ribbon(_ spec: FlowParameters.RibbonSpec,
                        clock: Double, width: CGFloat) -> some View {
        let phase = 2 * .pi * clock / spec.period + spec.phaseOffset
        // Amplitude gently breathes so the flex never feels mechanical.
        let swell = CGFloat(0.8 + 0.2 * sin(2 * .pi * clock / spec.swellPeriod + spec.swellPhase))
        let amplitude = spec.amplitude * swell
        // The twisting slowly rotates over time — the fabric turns in the air.
        let twistPhase = spec.twistPhaseBase + 2 * .pi * clock / spec.twistSpinPeriod

        let band = InkRibbonBand(
            amplitude: amplitude,
            frequency: spec.frequency * Double(width),
            phase: phase,
            baseThickness: spec.thickness,
            twistCycles: spec.twistCycles,
            twistDepth: spec.twistDepth,
            twistPhase: twistPhase
        )

        ZStack {
            // Internal fabric rendering is shaded at full strength (lit-from-
            // above wash + travelling folds). `spec.opacity` is NOT baked into
            // these fills — it's applied once, as a single multiplier on the
            // whole composited band below, so the final on-screen opacity is
            // EXACTLY `spec.opacity` no matter how the layers stack internally.
            band.fill(LinearGradient(
                colors: [
                    Theme.Colors.warmAccent.opacity(0.75),
                    Theme.Colors.warmAccent.opacity(0.30)
                ],
                startPoint: .top,
                endPoint: .bottom
            ))
            // …overlaid by the travelling fold facets (the twist shading).
            band.fill(fabricFacets(twistCycles: spec.twistCycles, twistPhase: twistPhase))
        }
        .compositingGroup()
        // Dissolve the ends so the fabric trails off like smoke into the
        // background — faint threads at the edges, fullest mid-field.
        .mask(edgeFade(phraseEdge: phraseEdge))
        .blur(radius: spec.blurRadius)
        // THE single authority for how transparent the ribbon is. Everything
        // composited above is multiplied by this one value.
        .opacity(spec.opacity)
        .frame(height: fieldHeight)
        .position(x: width / 2, y: fieldHeight * spec.verticalAnchor)
    }

    /// Horizontal mask for each ribbon: it fades in sharply at the outer window
    /// edge, holds full across the field, then fades OUT to nothing well before
    /// the JujuPhrase side — leaving a clear gap of breathing room around the
    /// phrase so the ribbon never reaches it.
    private func edgeFade(phraseEdge: PhraseEdge) -> some View {
        let stops: [Gradient.Stop]
        if phraseEdge == .leading {
            // Phrase sits to our left → fade out reaching 0% well before x = 0.
            stops = [
                .init(color: .black.opacity(0), location: 0),
                .init(color: .black.opacity(0), location: 0.18),
                .init(color: .black, location: 0.42),
                .init(color: .black, location: 0.86),
                .init(color: .black.opacity(0), location: 1)
            ]
        } else {
            // Phrase sits to our right → fade out reaching 0% well before x = 1.
            stops = [
                .init(color: .black.opacity(0), location: 0),
                .init(color: .black, location: 0.14),
                .init(color: .black, location: 0.58),
                .init(color: .black.opacity(0), location: 0.82),
                .init(color: .black.opacity(0), location: 1)
            ]
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    /// The twist shading: alternating light/dark folds along the ribbon, keyed to
    /// the same phase as the band's narrowing, so a thin edge-on twist reads as
    /// a shadowed fold and a thick face-on section as lit. Uses FIXED internal
    /// opacities — the final transparency is applied once by the ribbon's own
    /// `.opacity(spec.opacity)`.
    private func fabricFacets(twistCycles: Double, twistPhase: Double) -> LinearGradient {
        let count = max(5, Int(twistCycles) * 3)
        var stops: [Gradient.Stop] = []
        for i in 0...count {
            let loc = Double(i) / Double(count)
            let fold = 0.5 * (1 + sin(2 * .pi * twistCycles * loc + twistPhase))
            let factor = 0.35 + 0.65 * fold   // 0.35…1.0, full internal contrast
            stops.append(Gradient.Stop(
                color: Theme.Colors.warmAccent.opacity(factor),
                location: loc
            ))
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - Orb repulsion

    /// The orb's nominal on-screen centre (before repulsion), pure function of
    /// time — shared by the repulsion pass. Kept separate from `orb(_:)`'s
    /// rendering maths, which include the same position but focus on visuals.
    private func nominalOrbCenter(_ spec: FlowParameters.OrbSpec,
                                  clock: Double, width: CGFloat) -> CGPoint {
        let ribbon = params.ribbon(for: spec.stream)
        let ribbonPhase = 2 * .pi * clock / ribbon.period + ribbon.phaseOffset
        let swell = CGFloat(0.8 + 0.2 * sin(2 * .pi * clock / ribbon.swellPeriod + ribbon.swellPhase))
        let amplitude = ribbon.amplitude * swell
        let baseY = fieldHeight * ribbon.verticalAnchor
            + inkWaveOffset(t: 0.5, amplitude: amplitude,
                            frequency: ribbon.frequency * Double(width),
                            phase: ribbonPhase, pinned: true)
        let angle = 2 * .pi * clock / spec.helixPeriod + spec.helixPhase
        let x = width * (0.5 + spec.driftRange * CGFloat(sin(2 * .pi * clock / spec.driftPeriod + spec.driftPhase)))
            + spec.helixRadiusX * CGFloat(cos(angle))
        let y = baseY + spec.helixRadiusY * CGFloat(sin(angle))
        return CGPoint(x: x, y: y)
    }

    /// Gently pushes overlapping orbs apart so they don't visibly cluster.
    /// Deterministic (a function of time only, since all nominal positions
    /// are) and small in magnitude; the reach is limited so it reads as a soft
    /// repulsion, not scattering.
    private func repulsionOffsets(clock: Double, width: CGFloat) -> [CGSize] {
        let specs = params.orbs
        let pts = specs.map { nominalOrbCenter($0, clock: clock, width: width) }
        var offsets = Array(repeating: CGSize.zero, count: pts.count)

        let cutoff: CGFloat = 46    // beyond this, no interaction
        let strength: CGFloat = 7   // peak push at full overlap

        for i in 0..<pts.count {
            for j in (i + 1)..<pts.count {
                let dx = pts[i].x - pts[j].x
                let dy = pts[i].y - pts[j].y
                let dist = sqrt(dx * dx + dy * dy)
                guard dist < cutoff, dist > 0.001 else { continue }
                let f = (1 - dist / cutoff) * strength
                let nx = dx / dist
                let ny = dy / dist
                offsets[i].width += nx * f
                offsets[i].height += ny * f
                offsets[j].width -= nx * f
                offsets[j].height -= ny * f
            }
        }

        // Cap the total push so no orb ever flies far from its ribbon.
        return offsets.map { off in
            let mag = sqrt(off.width * off.width + off.height * off.height)
            let maxMag: CGFloat = 16
            guard mag > maxMag else { return off }
            let scale = maxMag / mag
            return CGSize(width: off.width * scale, height: off.height * scale)
        }
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

        // Same amplitude swell as the ribbon, so the orb stays on the band.
        let swell = CGFloat(0.8 + 0.2 * sin(2 * .pi * clock / ribbon.swellPeriod + ribbon.swellPhase))
        let amplitude = ribbon.amplitude * swell

        // Ribbon sample at the orb's nominal centre (t = 0.5) — the shared
        // base both the orb and the band agree on, via the one waveform.
        let baseY = fieldHeight * ribbon.verticalAnchor
            + inkWaveOffset(
                t: 0.5,
                amplitude: amplitude,
                frequency: ribbon.frequency * Double(width),
                phase: ribbonPhase,
                pinned: true
            )

        // Helix loop around the ribbon — constant angular speed, so this part
        // of the motion is always even and gentle.
        let angle = 2 * .pi * clock / spec.helixPeriod + spec.helixPhase
        let depth = sin(angle)                       // 1 = front, -1 = back
        let helixOffsetY = spec.helixRadiusY * CGFloat(depth)
        let helixOffsetX = spec.helixRadiusX * CGFloat(cos(angle))

        // Faux-3D: front of the loop is slightly larger and brighter.
        let depthScale = 1.0 + 0.08 * depth
        // Orb opacity halved (≈50%) so they sit subtle against the background.
        let depthOpacity = 0.5 * (0.86 + 0.14 * depth)

        // Horizontal drift: a slow sine. With a small range and a long period
        // the orb glides gently through the field's middle band and turns
        // softly at each end — a gentle pendulum, not a fast sprint through
        // the middle (keep the range small so it never clips the field edges).
        let drift = sin(2 * .pi * clock / spec.driftPeriod + spec.driftPhase)
        let x = width * (0.5 + spec.driftRange * CGFloat(drift))

        // The orb with the same soft warm glow the narrative cards use on
        // hover (`.hoverLift()`): warmAccent @ 0.12, radius 16, y 8. Subtle —
        // a gentle warm radiance that matches the app's established language
        // rather than a loud bloom.
        Circle()
            .fill(spec.color)
            .frame(width: spec.size, height: spec.size)
            .scaleEffect(depthScale)
            .opacity(depthOpacity)
            // A soft warm glow in `warmAccent` — the same warm family the
            // narrative cards use on hover. Centered (x/y 0) so it reads as a
            // subtle radiance around the orb rather than a directional shadow,
            // faint but clearly present.
            .shadow(color: Theme.Colors.warmAccent.opacity(0.26),
                    radius: spec.size * 1.1)
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
        /// Vertical thickness of the filled ribbon band, in points.
        let thickness: CGFloat
        /// Full wavelengths per 300pt of width — scale stays constant
        /// no matter how wide the field stretches.
        let frequency: Double
        /// Seconds per full undulation.
        let period: Double
        let phaseOffset: Double
        /// How fast the amplitude swells and relaxes (seconds per breath).
        let swellPeriod: Double
        let swellPhase: Double
        /// Number of full torso/twist folds across the width of the field.
        let twistCycles: Double
        /// 0…1 how much the fabric narrows at each edge-on twist.
        let twistDepth: CGFloat
        /// Starting angle of the twist pattern.
        let twistPhaseBase: Double
        /// Seconds for the twist pattern to rotate a full turn (so the fabric
        /// slowly twists in the breeze).
        let twistSpinPeriod: Double
        /// Soft-focus applied to this ribbon (a larger value = a dreamier,
        /// more receded ghost layer).
        let blurRadius: CGFloat
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
    let ghostRibbon: RibbonSpec
    let orbs: [OrbSpec]

    init(seed: UInt64) {
        var rng = SeededGenerator(seed: seed)

        // Ribbons — deep slow swell up top, quicker tighter ripple below.
        // Anchors pulled toward each other so the two streams sit closer
        // together; opacity lowered so they sit behind the JujuPhrase.
        highRibbon = RibbonSpec(
            verticalAnchor: 0.42, opacity: 0.06,
            amplitude: 11, thickness: 13, frequency: 0.9 / 300,
            period: Double.random(in: 17...21, using: &rng),
            phaseOffset: Double.random(in: 0..<(2 * .pi), using: &rng),
            swellPeriod: Double.random(in: 11...15, using: &rng),
            swellPhase: Double.random(in: 0..<(2 * .pi), using: &rng),
            twistCycles: 3,
            twistDepth: 0.5,
            twistPhaseBase: Double.random(in: 0..<(2 * .pi), using: &rng),
            twistSpinPeriod: Double.random(in: 20...28, using: &rng),
            blurRadius: 0.7
        )
        lowRibbon = RibbonSpec(
            verticalAnchor: 0.58, opacity: 0.045,
            amplitude: 7, thickness: 9, frequency: 1.6 / 300,
            period: Double.random(in: 22...26, using: &rng),
            phaseOffset: Double.random(in: 0..<(2 * .pi), using: &rng),
            swellPeriod: Double.random(in: 13...17, using: &rng),
            swellPhase: Double.random(in: 0..<(2 * .pi), using: &rng),
            twistCycles: 2,
            twistDepth: 0.45,
            twistPhaseBase: Double.random(in: 0..<(2 * .pi), using: &rng),
            twistSpinPeriod: Double.random(in: 26...34, using: &rng),
            blurRadius: 0.7
        )
        // A third, dreamier ribbon to mix into the weave: very low opacity
        // and softly blurred so it reads as a faint ghost current between the
        // two main streams.
        ghostRibbon = RibbonSpec(
            verticalAnchor: 0.50, opacity: 0.05,
            amplitude: 9, thickness: 8, frequency: 1.15 / 300,
            period: Double.random(in: 19...24, using: &rng),
            phaseOffset: Double.random(in: 0..<(2 * .pi), using: &rng),
            swellPeriod: Double.random(in: 12...16, using: &rng),
            swellPhase: Double.random(in: 0..<(2 * .pi), using: &rng),
            twistCycles: 2,
            twistDepth: 0.35,
            twistPhaseBase: Double.random(in: 0..<(2 * .pi), using: &rng),
            twistSpinPeriod: Double.random(in: 24...32, using: &rng),
            blurRadius: 3.0
        )

        // Orbs — sizes slightly varied, colours strictly the two sanctioned
        // neutrals (lightest white-ish + warm muted secondary), speeds
        // clustered around medium so nothing races or stalls.
        let colors: [Color] = [Theme.Colors.glow, Theme.Colors.textSecondary]
        orbs = (0..<6).map { index in
            let stream: OrbSpec.Stream = index.isMultiple(of: 2) ? .high : .low
            return OrbSpec(
                stream: stream,
                size: [9, 7, 8, 10, 7, 9][index],
                color: colors[index % 2],
                // Small, tight orbits so the orbs hover rather than swing wide.
                helixRadiusY: 13,
                helixRadiusX: 7,
                helixPeriod: Double.random(in: 160...220, using: &rng),
                helixPhase: Double.random(in: 0..<(2 * .pi), using: &rng),
                // Shallow, slow horizontal drift that stays clear of the edges.
                driftRange: 0.26,
                driftPeriod: Double.random(in: 280...380, using: &rng),
                driftPhase: Double.random(in: 0..<(2 * .pi), using: &rng)
            )
        }
    }

    func ribbon(for stream: OrbSpec.Stream) -> RibbonSpec {
        stream == .high ? highRibbon : lowRibbon
    }
}

// MARK: - Ink Ribbon Band
//
/// A filled band of sheer fabric: the midline follows the pinned, swelling ink
/// waveform, while the band's thickness narrows at each twist (edge-on) and
/// widens where face-on — the torsion that makes it read as twisted fabric.
/// The fold facets are shaded separately (see `fabricFacets`), keyed to the
/// same phase so thin shadowed twists and thick lit sections coincide.
struct InkRibbonBand: Shape {
    let amplitude: CGFloat
    /// Full wavelengths across the shape's width.
    let frequency: Double
    let phase: Double
    /// Thickness where the fabric is fully face-on.
    let baseThickness: CGFloat
    /// Number of full twist folds across the width.
    let twistCycles: Double
    /// 0…1 how much the fabric narrows at each edge-on twist.
    let twistDepth: CGFloat
    let twistPhase: Double

    func path(in rect: CGRect) -> Path {
        let steps = 120
        let midY = rect.midY

        func thickness(at t: Double) -> CGFloat {
            let twist = 0.5 * (1 + sin(2 * .pi * twistCycles * t + twistPhase))
            return baseThickness * (1 - twistDepth * CGFloat(twist))
        }
        func center(at t: Double) -> CGFloat {
            midY + inkWaveOffset(t: t, amplitude: amplitude,
                                 frequency: frequency, phase: phase, pinned: true)
        }

        var path = Path()
        // Top edge, left → right.
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let x = rect.minX + CGFloat(t) * rect.width
            let y = center(at: t) - thickness(at: t) / 2
            if step == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        // Bottom edge, right → left, closing the shape.
        for step in stride(from: steps, through: 0, by: -1) {
            let t = Double(step) / Double(steps)
            let x = rect.minX + CGFloat(t) * rect.width
            let y = center(at: t) + thickness(at: t) / 2
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Ink Waveform
//
/// The single waveform shared by ribbons and orbs: a gentle sine with a slow,
/// shallow harmonic so the line breathes without crumpling. Both the shapes
/// and the orb base-position calcs call this so everything stays in harmony.
func inkWaveOffset(t: Double, amplitude: CGFloat, frequency: Double, phase: Double,
                   pinned: Bool = false) -> CGFloat {
    let harmonicFrequency = frequency * 1.8
    let harmonicAmplitude = amplitude * 0.12
    let harmonicPhase = phase * 1.4
    let base = sin(2 * .pi * frequency * t + phase)
    let harmonic = sin(2 * .pi * harmonicFrequency * t + harmonicPhase)
    // Pinned ends: multiply by a bell so the ripple dies to nothing at the
    // edges, leaving a ribbon flexing between two held points.
    let envelope = pinned ? sin(.pi * t) : 1.0
    return envelope * (amplitude * CGFloat(base) + harmonicAmplitude * CGFloat(harmonic))
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
