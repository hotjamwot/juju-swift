import SwiftUI
import AppKit

extension NSColor {
    /// Converts an NSColor to SwiftUI Color
    var swiftUIColor: Color {
        Color(self)
    }
}
