import SwiftUI
import AppKit

extension Color {
    /// Lightens a color if its perceived luminance (Rec. 601) is below a threshold,
    /// blending it toward white so it remains visible against dark backgrounds.
    func lightenedByLuminance(threshold: CGFloat = 0.35, mixFactor: CGFloat = 0.55) -> Color {
        guard let nsColor = NSColor(self).usingColorSpace(.deviceRGB) else { return self }
        let r = nsColor.redComponent
        let g = nsColor.greenComponent
        let b = nsColor.blueComponent
        let a = nsColor.alphaComponent
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        if luminance < threshold {
            let mix = 1.0 - luminance
            return Color(
                red: min(r + mix * mixFactor, 1.0),
                green: min(g + mix * mixFactor, 1.0),
                blue: min(b + mix * mixFactor, 1.0),
                opacity: Double(a)
            )
        }
        return self
    }
    
    /// Creates a lightened color from a hex string using perceived luminance blending.
    /// Falls back to `Color(hex:)` if the hex cannot be parsed as an NSColor.
    static func lightenedHex(_ hex: String, threshold: CGFloat = 0.35, mixFactor: CGFloat = 0.55) -> Color {
        guard let nsColor = NSColor(hex: hex)?.usingColorSpace(.deviceRGB) else {
            return Color(hex: hex)
        }
        let r = nsColor.redComponent
        let g = nsColor.greenComponent
        let b = nsColor.blueComponent
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        if luminance < threshold {
            let mix = 1.0 - luminance
            return Color(
                red: min(r + mix * mixFactor, 1.0),
                green: min(g + mix * mixFactor, 1.0),
                blue: min(b + mix * mixFactor, 1.0)
            )
        }
        return Color(hex: hex)
    }
}