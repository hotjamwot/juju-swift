import SwiftUI

// MARK: - MicroInteractions

/// Reusable view modifiers for Phase 2 micro-interactions.
///
/// All interactions use `Theme.Design.spring` and respect `accessibilityReduceMotion`:
/// - With Reduce Motion ON: ambient loops are disabled; hover states fall back to
///   opacity-only (no scale transforms, no shadow shifts).
/// - With Reduce Motion OFF: full springs and ambient loops engage.

// MARK: - Milestone Pulse (ambient, looping) — Whitelisted loop #1

/// Drives a repeating scale animation: 1.0 → 1.12 → 1.0 over ~2.4 s, looping forever.
/// Automatically suppressed when Reduce Motion is enabled.
struct MilestonePulseModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: CGFloat = 0.0

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .scaleEffect(1.0 + pulse * 0.12)
                .onAppear {
                    withAnimation(
                        Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                    ) {
                        pulse = 1.0
                    }
                }
        }
    }
}

// MARK: - Hover Spring Scale

/// On hover, the view scales up (default 1.0 → 1.03) using `Theme.Design.spring`.
/// With Reduce Motion, falls back to a subtle opacity shift (no scale).
struct HoverSpringScaleModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let targetScale: CGFloat

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1.0 : (isHovering ? targetScale : 1.0))
            .opacity(reduceMotion ? (isHovering ? 0.7 : 1.0) : 1.0)
            .onHover { hovering in
                withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : Theme.Design.spring) {
                    isHovering = hovering
                }
            }
    }
}

// MARK: - Hover Lift + Warm Shadow

/// On hover, the view lifts 1–2 px and swaps the default shadow for a warmer one.
/// With Reduce Motion, the lift is suppressed (only a shadow swap remains).
struct HoverLiftModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .offset(y: reduceMotion ? 0 : (isHovering ? -2 : 0))
            .scaleEffect(reduceMotion ? 1.0 : (isHovering ? 1.02 : 1.0))
            .shadow(
                color: isHovering
                    ? Theme.Colors.warmAccent.opacity(0.12)
                    : Theme.Colors.divider.opacity(0.15),
                radius: isHovering ? 16 : 14,
                x: 0,
                y: 8
            )
            .onHover { hovering in
                withAnimation(Theme.Design.spring) {
                    isHovering = hovering
                }
            }
    }
}

// MARK: - View Extension Shorthands

extension View {

    /// Apply the ambient milestone pulse (whitelisted loop #1).
    /// Automatically disabled when Reduce Motion is on.
    func milestonePulse() -> some View {
        modifier(MilestonePulseModifier())
    }

    /// Scale-to `target` on hover using the spring curve.
    /// Falls back to opacity-only when Reduce Motion is enabled.
    /// - Parameter target: The scale factor to animate to on hover (default 1.03).
    func hoverSpringScale(targetScale: CGFloat = 1.03) -> some View {
        modifier(HoverSpringScaleModifier(targetScale: targetScale))
    }

    /// 1–2 px lift + warm shadow on hover.
    /// Falls back to shadow-only when Reduce Motion is enabled.
    func hoverLift() -> some View {
        modifier(HoverLiftModifier())
    }
}
