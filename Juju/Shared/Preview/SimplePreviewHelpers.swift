import SwiftUI

/// Simple preview helpers for common preview patterns
public enum SimplePreviewHelpers {
    
    /// Creates a standard preview with modal frame size (750x450)
    /// - Parameter view: The view to preview
    public static func modal(_ view: @escaping () -> some View) -> some View {
        view().frame(width: 750, height: 450)
    }
    
    /// Creates a notes modal preview with notes modal frame size (900x700)
    /// - Parameter view: The view to preview
    public static func notesModal(_ view: @escaping () -> some View) -> some View {
        view().frame(width: 900, height: 700)
    }
    
    /// Creates a project preview with project frame size (650x600)
    /// - Parameter view: The view to preview
    public static func project(_ view: @escaping () -> some View) -> some View {
        view().frame(width: 650, height: 600)
    }
    
    /// Creates a chart preview with chart frame size and background
    /// - Parameter view: The chart view to preview
    public static func chart(_ view: @escaping () -> some View) -> some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            view()
                .frame(width: 850, height: 350)
                .padding()
        }
    }
    
    /// Creates a session preview with session frame size (450x600)
    /// - Parameter view: The view to preview
    public static func session(_ view: @escaping () -> some View) -> some View {
        view().frame(width: 450, height: 600)
    }
}
