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
    
    static func updateIcon(for button: NSStatusBarButton, isActive: Bool) {
        let iconName = isActive ? "status-active" : "status-idle"
        
        if let image = NSImage(named: iconName) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            button.image = image
            print("✅ \(iconName) loaded successfully from Assets catalog!")
        } else {
            print("⚠️ \(iconName) not found in Assets catalog")
        }
    }
} 