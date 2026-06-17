import SwiftUI
import AppKit

/// All colours, fonts, spacing, etc. lives here – no magic strings elsewhere.
///
/// DESIGN PHILOSOPHY — "The Editor"
///
/// Juju's visual language is editorial and personal: a dark journal you love cracking open.
/// It draws from Monocle's confident restraint and A24's intentional use of colour.
///
/// The core principle: the UI chrome should nearly disappear.
/// Backgrounds, surfaces, and cards are warm near-blacks with low chroma —
/// they recede so that project colours arrive with full force.
///
/// COLOUR RULES:
/// - No global accent colour. Project colours ARE the accent system. Note: we've kept accentColor in our assets (currently set to textPrimary color)
/// - Interactive states (buttons, selection, focus) use off-white — weight and opacity shifts only.
/// - Saturation lives exclusively in the data layer: project bars, session blocks, chart fills.
/// - Surfaces are warm but desaturated — enough to feel human, not enough to compete.
///
/// TYPOGRAPHY RULES:
/// - Design: .default throughout. No .rounded — it reads as "app-like"; we want editorial.
/// - Two weights only: .regular for body, .semibold for headers.
/// - Size hierarchy: 16 → 14 → 13 → 10. No magic sizes outside this scale.
///
/// SPACING RULES:
/// - 8pt grid system. Every gap is a multiple of 4.
/// - Generous outer padding (48pt) creates breathing room.
/// - No card borders. Depth comes from the subtle step between background and surface.
public struct Theme {

    // MARK: - Colors
    public struct Colors {

        /// Page background — warm near-black, the darkest layer.
        /// Brown-tinted rather than blue-cold. Feels like good newsprint in low light.
        /// Xcode asset: "Background" → #1A1714
        public static let background = Color("Background")

        /// Chart and panel surface — same warmth, significantly lower chroma.
        /// Almost neutral so it doesn't compete with project colours sitting on top.
        /// Xcode asset: "Surface" → #1E1C1A
        public static let surface = Color("Surface")

        /// Primary text — warm cream. Not pure white; not yellow. Sits naturally
        /// against the warm background without the harshness of #FFFFFF.
        /// Xcode asset: "textPrimary" → #EAE4DA
        public static let textPrimary = Color("textPrimary")

        /// Secondary text — muted warm grey. Labels, captions, metadata.
        /// Xcode asset: "textSecondary" → #7A7268
        public static let textSecondary = Color("textSecondary")

        /// Divider — very low opacity warm white. Hairline rules only.
        /// Xcode asset: "Divider" → rgba(234, 228, 218, 0.10)
        public static let divider = Color("Divider")

        /// Foreground alias — same value as textPrimary. Kept for legacy compatibility.
        public static let foreground = Color("foreground")

        /// Error — retained for destructive actions only.
        /// Xcode asset: "Error" → #B02A21
        public static let error = Color("Error")

        /// Accent — DEPRECATED for UI chrome, but kept for legacy compatibility.
        /// As of June 2026, the AppAccentColor asset has been updated to match textPrimary
        /// (off-white warm cream #EAE4DA), so references to accentColor now resolve to the
        /// same value as textPrimary. This means existing call sites (e.g. the projects add
        /// button) render correctly without breaking.
        ///
        /// Do NOT introduce new uses. Project colours own the accent role.
        /// If you find yourself reaching for accentColor, ask: can a project colour
        /// or an off-white opacity shift do this job instead?
        @available(*, deprecated, message: "Use project colour or off-white opacity shift instead. See Theme philosophy.")
        public static let accentColor = Color("AppAccentColor")

        /// Milestone gold — used for milestone indicators and highlighted accent bars.
        /// A warm amber that stands out against the dark background.
        public static let milestone: Color = Color(hex: "F5A623")
        
        /// Milestone highlight — brighter gold for active/hovered milestone states.
        public static let milestoneHighlight: Color = Color(hex: "FFD060")

        /// Positive delta — green for upward comparative trends.
        public static let positive: Color = Color.green

        /// Negative delta — red for downward comparative trends.
        public static let negative: Color = Color.red.opacity(0.8)

        /// Interactive off-white — used for buttons, selected states, focus rings.
        /// Same colour family as textPrimary but slightly brighter.
        /// Weight and opacity shifts carry all interactive meaning — no hue change needed.
        public static let interactive: Color = Color(NSColor(
            srgbRed: 0.918, green: 0.894, blue: 0.863, alpha: 1.0
        )) // #EAE3DC

        /// Interactive hover — off-white at reduced opacity. For hover backgrounds.
        public static let interactiveHover: Color = Color(NSColor(
            srgbRed: 0.918, green: 0.894, blue: 0.863, alpha: 0.08
        ))

        /// Interactive selected — off-white at medium opacity. For selected row backgrounds.
        public static let interactiveSelected: Color = Color(NSColor(
            srgbRed: 0.918, green: 0.894, blue: 0.863, alpha: 0.12
        ))

        /// Convert a SwiftUI Color to NSColor (macOS only).
        public static func nsColor(_ color: Color) -> NSColor? {
            if let cg = color.cgColor {
                let comps = cg.components ?? [0, 0, 0, 1]
                return NSColor(srgbRed: comps[0], green: comps[1], blue: comps[2], alpha: comps[3])
            }
            return nil
        }
    }

    // MARK: - Typography
    //
    // Design: .default throughout — editorial, not "app-like".
    // Two weights only: .regular and .semibold.
    // If you need to express hierarchy, use size and opacity — not weight proliferation.
    //
    // Size hierarchy: 16 → 14 → 13 → 10. No magic sizes outside this scale.
    public struct Fonts {
        /// Hero page titles — 16pt semibold. For "Sessions", "Projects", "Activity Types" page titles.
        public static let hero = Font.system(size: 16, weight: .semibold, design: .default)

        /// Metric value — 16pt semibold. For large numeric displays (FOCUS hours, THIS WEEK value).
        public static let metricValue = Font.system(size: 16, weight: .semibold, design: .default)

        /// Dialog title — 16pt semibold. For modal titles like "Delete Project".
        public static let dialogTitle = Font.system(size: 16, weight: .semibold, design: .default)

        /// Title — 16pt semibold. For metric values, dialog titles, prominent numbers.
        public static let title = Font.system(size: 16, weight: .semibold, design: .default)

        /// Icon — 14pt regular. Standard SF Symbol size for icons.
        public static let icon = Font.system(size: 14, weight: .regular, design: .default)

        /// Icon large — 16pt regular. Larger SF Symbol size for overview card icons.
        public static let iconLarge = Font.system(size: 16, weight: .regular, design: .default)

        /// Subheader — 14pt semibold. For section headings like "Notable moments".
        public static let subheader = Font.system(size: 14, weight: .semibold, design: .default)

        /// Section headers and card titles — 16pt semibold, default design.
        public static let header = Font.system(size: 16, weight: .semibold, design: .default)

        /// Sidebar — 14pt regular/semibold toggle. For sidebar item labels.
        public static let sidebar = Font.system(size: 14, weight: .regular, design: .default)

        /// Body text — 14pt regular. The workhorse.
        public static let body = Font.system(size: 14, weight: .regular, design: .default)

        /// Narrative strip text — 13pt regular. For summary stat labels.
        public static let narrative = Font.system(size: 13, weight: .regular, design: .default)

        /// Narrative strip accent — 13pt semibold. For summary stat values.
        public static let narrativeAccent = Font.system(size: 13, weight: .semibold, design: .default)

        /// Mono — 13pt regular monospaced. For timestamps, durations, precise numeric data.
        /// .monospaced keeps numbers from jumping in width as they update.
        public static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)

        /// Caption — 10pt regular. The single smallest size. For badges, metadata, SF Symbol icons,
        /// chart labels, timestamps, and all minimal UI chrome. Use sparingly.
        public static let caption = Font.system(size: 10, weight: .regular, design: .default)
    }

    // MARK: - Spacing
    //
    // 8pt grid. Every value is a multiple of 4.
    // Use named constants — never magic numbers in layout code.
    public static let spacingExtraSmall = CGFloat(4)
    public static let spacingSmall      = CGFloat(8)
    public static let spacingMedium     = CGFloat(16)
    public static let spacingLarge      = CGFloat(24)
    public static let spacingExtraLarge = CGFloat(32)

    public struct Spacing {
        /// 2pt — micro gaps, almost invisible.
        public static let micro: CGFloat = 2
        /// 4pt — very tight, for inline elements.
        public static let xxs: CGFloat = 4
        /// 8pt — small, for compact content.
        public static let xs: CGFloat = 8
        /// 12pt — standard inner padding.
        public static let sm: CGFloat = 12
        /// 16pt — medium, for section gaps.
        public static let md: CGFloat = 16
        /// 24pt — large, for major section breaks.
        public static let lg: CGFloat = 24
        /// 32pt — extra large, for page-level padding.
        public static let xl: CGFloat = 32
        /// 48pt — outer dashboard padding. Generous breathing room.
        public static let xxl: CGFloat = 48
    }

    // MARK: - Design
    public struct Design {
        /// Standard corner radius — 12pt for cards, containers, dialogs.
        public static let cornerRadius = CGFloat(12)
        /// Reduced corner radius for blocks, bars, buttons, and compact elements — editorial, not "bubbly".
        public static let blockCornerRadius = CGFloat(5)
        /// Standard animation duration.
        public static let animationDuration = 0.2
    }

    // MARK: - Dashboard Layout
    //
    // Single source of truth for all dashboard layout values.
    // Charts declare their own ideal height and fill full width.
    public struct DashboardLayout {
        /// Outer padding applied by chartContainer.
        public static let chartPadding: CGFloat = 20
        /// Page-level horizontal + vertical padding for the dashboard scroll view.
        public static let dashboardPadding: CGFloat = 48
        /// Chart corner radius.
        public static let chartCornerRadius: CGFloat = 12
        /// Border width — 0 for the borderless look.
        public static let chartBorderWidth: CGFloat = 0
        /// Internal padding inside each chart's plot area.
        public static let chartInnerPadding: CGFloat = 16
        /// Gap between narrative strip and dashboard charts.
        public static let narrativeToContentGap: CGFloat = 24

        public static let breakpoints = (
            small: 800,
            medium: 1200,
            large: 1600
        )
    }

    // MARK: - Row
    public struct Row {
        public static let height: CGFloat = 44
        public static let expandedHeight: CGFloat = 90
        public static let cornerRadius: CGFloat = 10
        public static let hoverOpacity: CGFloat = 0.08   // Reduced — more subtle than before
        public static let separatorHeight: CGFloat = 1
        public static let projectDotSize: CGFloat = 6
        public static let emojiSize: CGFloat = 14
        public static let compactSpacing: CGFloat = 8
        public static let contentPadding: CGFloat = 8
    }

    // MARK: - Tab Bar
    //
    // Tab bar uses NSColor directly for AppKit compatibility.
    // Interactive states use off-white rather than the former accent colour.
    public struct Tab {
        public static let background = NSColor(srgbRed: 0.102, green: 0.090, blue: 0.078, alpha: 1.0)         // #1A1714
        public static let hoverBackground = NSColor(srgbRed: 0.918, green: 0.894, blue: 0.863, alpha: 0.08)   // off-white 8%
        public static let selectedBackground = NSColor(srgbRed: 0.918, green: 0.894, blue: 0.863, alpha: 0.15) // off-white 15%
        public static let icon = NSColor(srgbRed: 0.475, green: 0.447, blue: 0.408, alpha: 1.0)               // #796F68 — muted
        public static let selectedIcon = NSColor(srgbRed: 0.918, green: 0.894, blue: 0.863, alpha: 1.0)       // #EAE4DA — cream
        /// No glow. Removed — glow required the accent colour and read as decorative noise.
    }
}

// MARK: - Xcode Asset Catalogue reference
//
// Update your .xcassets to match these values.
// All colours are sRGB. Dark mode only — Juju has no light mode.
//
// "Background"   Any: #1A1714  (r:0.102 g:0.090 b:0.078)
// "Surface"      Any: #1E1C1A  (r:0.118 g:0.110 b:0.102)
// "textPrimary"  Any: #EAE4DA  (r:0.918 g:0.894 b:0.855)
// "textSecondary"Any: #7A7268  (r:0.478 g:0.447 b:0.408)
// "Divider"      Any: rgba(234,228,218, 0.10)
// "foreground"   Any: #EAE4DA  (same as textPrimary)
// "Error"        Any: #B02A21  (unchanged)
// "AppAccentColor" Any: #EAE4DA (updated June 2026 to match textPrimary — was #E100FF.
//                              Kept for legacy call sites, not for new uses.)
//                              See Theme.Colors.accentColor deprecation note.
//
// interactive is defined programmatically above
// and does not require an asset catalogue entry.

// MARK: - NSColor Extensions
extension NSColor {
    var swiftUIColor: Color { Color(self) }
}

// MARK: - Preview Helpers
public enum SimplePreviewHelpers {

    public static func modal(_ view: @escaping () -> some View) -> some View {
        view().frame(width: 750, height: 450)
    }

    public static func notesModal(_ view: @escaping () -> some View) -> some View {
        view().frame(width: 900, height: 700)
    }

    public static func project(_ view: @escaping () -> some View) -> some View {
        view().frame(width: 650, height: 600)
    }

    public static func chart(_ view: @escaping () -> some View) -> some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            view()
                .frame(width: 850, height: 350)
                .padding()
        }
    }

    public static func session(_ view: @escaping () -> some View) -> some View {
        view().frame(width: 450, height: 600)
    }
}

// MARK: - View Extensions
extension View {

    /// Standard outer padding for dashboard views.
    func dashboardPadding() -> some View {
        self.padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
            .padding(.vertical, Theme.DashboardLayout.dashboardPadding)
    }

    /// Standard inner padding for chart components.
    func chartPadding() -> some View {
        self.padding(.horizontal, Theme.DashboardLayout.chartPadding)
            .padding(.vertical, Theme.DashboardLayout.chartPadding)
    }

    /// Loading overlay for dashboard views while data is being prepared.
    @ViewBuilder
    func loadingOverlay(isLoading: Bool, message: String = "Loading...") -> some View {
        if isLoading {
            self.overlay(
                Rectangle()
                    .fill(Theme.Colors.background.opacity(0.6))
                    .overlay(
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text(message)
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Colors.surface)
                        .cornerRadius(Theme.Design.cornerRadius)
                    )
            )
        } else {
            self
        }
    }

    /// Chart container — no border, depth from background step alone.
    func chartContainer() -> some View {
        self
            .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
            .padding(.vertical, Theme.DashboardLayout.chartPadding)
    }

    /// Dashboard card — surface background, standard corner radius, no border.
    func dashboardCard() -> some View {
        self
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.Design.cornerRadius)
            .dashboardPadding()
    }

    /// Subtle shadow for depth — uses divider colour family.
    func subtleShadow() -> some View {
        self.shadow(color: Theme.Colors.divider.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    /// Full-bleed dashboard container with background fill.
    func dashboardContainer() -> some View {
        ZStack {
            Theme.Colors.background
            self
        }
        .ignoresSafeArea()
    }

    /// Section header with optional subtitle and divider rule below.
    func withHeader(title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            Text(title)
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textPrimary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Divider()
                .background(Theme.Colors.divider)

            self
        }
        .dashboardPadding()
    }

    /// Section wrapper with optional title label.
    func section(title: String? = nil) -> some View {
        VStack(spacing: Theme.spacingSmall) {
            if let title = title {
                Text(title)
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            self
        }
        .padding(.vertical, Theme.spacingMedium)
    }

    /// Footer with action buttons separated by a hairline rule.
    @ViewBuilder
    func withFooter(@ViewBuilder buttons: @escaping () -> some View) -> some View {
        VStack(spacing: 0) {
            self
            Divider()
                .background(Theme.Colors.divider)
            HStack {
                Spacer()
                buttons()
                Spacer()
            }
            .padding(.vertical, Theme.spacingSmall)
            .padding(.horizontal, Theme.spacingMedium)
        }
    }
}