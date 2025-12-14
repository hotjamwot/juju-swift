import SwiftUI
import AppKit

/// All colours, fonts, spacing, etc. lives here – no magic strings elsewhere.
public struct Theme {

    // MARK: Colors
    public struct Colors {
        public static let background  = Color("Background")  // #121212
        public static let surface     = Color("Surface")  // #1C1C1E
        public static let textPrimary = Color("textPrimary")  // #E5E5E7
        public static let textSecondary = Color("textSecondary")  // #9A9AA0
        public static let divider     = Color("Divider")  // rgba(255,255,255,0.1)
        public static let foreground  = Color("foreground") // #E5E5E7
        public static let error       = Color("Error")  // #B02A21
        public static let accentColor       = Color("AppAccentColor")  // #E100FF or #C800C8 in dark mode

        /// Convert a SwiftUI `Color` to the underlying `NSColor` (macOS only)
        public static func nsColor(_ color: Color) -> NSColor? {
            #if arch(x86_64) || arch(arm64) // macOS build
            if let cg = color.cgColor {
                let comps = cg.components ?? [0, 0, 0, 1]
                return NSColor(srgbRed: comps[0], green: comps[1], blue: comps[2], alpha: comps[3])
            }
            return nil
            #else
            return nil
            #endif
        }
    }

    // MARK: Typography
    public struct Fonts {
        public static let header   = Font.system(size: 16, weight: .semibold, design: .rounded)
        public static let body     = Font.system(size: 14, weight: .regular)
        public static let caption  = Font.system(size: 10, weight: .medium)
        public static let icon     = Font.system(size: 20, weight: .regular)
    }

    // MARK: Spacing & Sizing
    public static let spacingSmall       = CGFloat(8)
    public static let spacingExtraSmall  = CGFloat(4)
    public static let spacingMedium      = CGFloat(16)
    public static let spacingLarge       = CGFloat(24)
    public static let spacingExtraLarge       = CGFloat(32)

    // MARK: Corners / Animation
    public struct Design {
        public static let cornerRadius     = CGFloat(18)
        public static let animationDuration = 0.2
    }

    // MARK: Dashboard Layout Constants
    // Single source of truth for all dashboard layout values
    public struct DashboardLayout {
        // Core spacing system - single source of truth
        public static let chartPadding: CGFloat = 12
        public static let chartGap: CGFloat = 24
        public static let dashboardPadding: CGFloat = 24
        public static let chartCornerRadius: CGFloat = 16
        public static let chartBorderWidth: CGFloat = 1
        
        // Responsive breakpoints
        public static let breakpoints = (
            small: 800,
            medium: 1200,
            large: 1600
        )
        
        // Chart aspect ratios
        public static let topChartAspectRatio: CGFloat = 0.6
        public static let bottomChartAspectRatio: CGFloat = 0.4
        
        // Yearly layout ratios
        public static let yearlyLeftColumnRatio: CGFloat = 0.45
        public static let yearlyRightColumnRatio: CGFloat = 0.55
    }

    // MARK: Row-specific styling for list layout
    public struct Row {
        public static let height: CGFloat = 44
        public static let expandedHeight: CGFloat = 90
        public static let cornerRadius: CGFloat = 10
        public static let hoverOpacity: CGFloat = 0.2
        public static let separatorHeight: CGFloat = 1
        public static let projectDotSize: CGFloat = 6
        public static let emojiSize: CGFloat = 14
        public static let compactSpacing: CGFloat = 8
        public static let contentPadding: CGFloat = 8
    }

    // MARK: Tab‑Bar specific colours
    public struct Tab {
        // Use the helper so both `Color` (SwiftUI) and `NSColor` are available
        public static let background      = Colors.nsColor(Colors.background)!
        public static let hoverBackground = Colors.nsColor(Colors.background)!.withAlphaComponent(0.8)  // Subtle hover
        public static let selectedBackground = Colors.nsColor(Colors.accentColor)!
        public static let icon            = NSColor(srgbRed: 0.929, green: 0.929, blue: 0.929, alpha: 1.0)  // #EDEDED
        public static let selectedIcon    = NSColor.white
        public static let glow            = Colors.nsColor(Colors.accentColor)!.withAlphaComponent(0.3)
    }
}
