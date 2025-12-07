import Cocoa

class IconManager {
    static func loadIcon(for button: NSStatusBarButton) {
        if let image = NSImage(named: "status-idle") {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            button.image = image
            print("✅ Custom icon loaded successfully from Assets catalog!")
        } else {
            button.title = "⏱"
            print("⚠️ Icon not found in Assets catalog, using fallback text")
        }
    }
    
    /// Updates the menu bar icon based on session state
    /// - Parameters:
    ///   - button: The status bar button to update
    ///   - isActive: Whether a session is currently active
    static func updateIcon(
        for button: NSStatusBarButton,
        isActive: Bool
    ) {
        if isActive {
            // Session is active - show app's active icon
            if let image = NSImage(named: "status-active") {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
                button.title = ""
                print("✅ Updated icon to active status")
            } else {
                button.title = "⏱"
                button.image = nil
                print("⚠️ Active icon not found, using fallback text")
            }
        } else {
            // Session is idle - show app's idle icon
            if let image = NSImage(named: "status-idle") {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
                button.title = ""
                print("✅ Updated icon to idle status")
            } else {
                button.title = "⏱"
                button.image = nil
                print("⚠️ Idle icon not found, using fallback text")
            }
        }
    }
    
}
