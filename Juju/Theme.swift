import SwiftUI

/// Global styling helper – accessible from any view or view‑model.
public struct Theme {
    // MARK: - Colors
    public static let primary     = Color("Primary")     // #1C1C1E
    public static let secondary   = Color("Secondary")   // #3A3A3C
    public static let accent      = Color("Accent")      // #8A2BE2
    public static let background  = Color("Background")  // #000000
    public static let surface     = Color("Surface")     // #2C2C2E
    public static let error       = Color("Error")       // #B02A21
    public static let foreground     = Color("Foreground")     // #E9E9E9

    // MARK: - Typography
    public static let headerFont = Font.system(size: 18, weight: .semibold)
    public static let bodyFont   = Font.system(size: 15, weight: .regular)
    public static let captionFont = Font.system(size: 13, weight: .light)

    // MARK: - Spacing / Padding
    public static let spacingSmall   = CGFloat(8)
    public static let spacingExtraSmall = CGFloat(4)
    public static let spacingMedium  = CGFloat(12)
    public static let spacingLarge   = CGFloat(18)

    // MARK: - Misc
    public static let cornerRadius = CGFloat(8)
    public static let animationDuration = 0.25
}
