import SwiftUI
import AppKit

/// All colours, fonts, spacing, etc. lives here – no magic strings elsewhere.
public struct Theme {

    // MARK: Colors
    public struct Colors {
        // 1️⃣ Asset‑catalog colours (created in Assets.xcassets, names must match)
        public static let primary     = Color("Primary")     // #1C1C1E
        public static let secondary   = Color("Secondary")   // #3A3A3C
        public static let accent      = Color("Accent")      // #8A2BE2
        public static let background  = Color ("Background")  // #000000
        public static let surface     = Color("Surface")     // #2C2C2E
        public static let error       = Color("Error")       // #B02A21
        public static let foreground  = Color("Foreground")  // #E9E9E9

        /// Convert a SwiftUI `Color` to the underlying `NSColor` (macOS only)
        public static func nsColor(_ color: Color) -> NSColor {
            #if arch(x86_64) || arch(arm64) // macOS build
            guard let cg = color.cgColor else { return .black }
            let comps = cg.components ?? [0, 0, 0, 1]
            return NSColor(calibratedRed: comps[0],
                           green: comps[1],
                           blue: comps[2],
                           alpha: comps[3])
            #else
            return .black   // query path for other platforms – not used here
            #endif
        }
    }

    // MARK: Typography
    public struct Fonts {
        public static let header   = Font.system(size: 18, weight: .semibold)
        public static let body     = Font.system(size: 15, weight: .regular)
        public static let caption  = Font.system(size: 13, weight: .light)
    }

    // MARK: Spacing & Sizing
    public static let spacingSmall       = CGFloat(8)
    public static let spacingExtraSmall  = CGFloat(4)
    public static let spacingMedium      = CGFloat(12)
    public static let spacingLarge       = CGFloat(18)

    // MARK: Corners / Animation
    public struct Design {
        public static let cornerRadius     = CGFloat(8)
        public static let animationDuration = 0.25
    }

    // MARK: Tab‑Bar specific colours
    public struct Tab {
        // Use the helper so both `Color` (SwiftUI) and `NSColor` are available
        public static let background      = Colors.nsColor(Colors.background)       // lighter grey
        public static let hoverBackground = Colors.nsColor(Colors.surface)          // slightly darker
        public static let selectedBackground = NSColor.controlAccentColor           // (the macOS accent colour)
        public static let icon            = NSColor(calibratedWhite: 0.7, alpha: 1.0)  // light grey glyph
        public static let selectedIcon    = NSColor.white
        public static let glow            = NSColor.controlAccentColor
    }
}
