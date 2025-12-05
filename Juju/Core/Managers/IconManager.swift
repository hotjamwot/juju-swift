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
    ///   - activityTypeID: Optional activity type ID (if set, shows activity emoji)
    ///   - projectID: Optional project ID (used for interim state when activity not set)
    static func updateIcon(
        for button: NSStatusBarButton,
        isActive: Bool,
        activityTypeID: String? = nil,
        projectID: String? = nil
    ) {
        if isActive {
            // Session is active - show activity emoji if present, otherwise project emoji/color
            if let activityTypeID = activityTypeID,
               let activityType = ActivityTypeManager.shared.getActivityType(id: activityTypeID) {
                // Show activity type emoji
                button.title = activityType.emoji
                button.image = nil
                print("✅ Updated icon to activity type: \(activityType.name) (\(activityType.emoji))")
            } else if let projectID = projectID,
                      let project = ProjectManager.shared.loadProjects().first(where: { $0.id == projectID }) {
                // Show project emoji during interim state
                button.title = project.emoji
                button.image = nil
                print("✅ Updated icon to project emoji: \(project.name) (\(project.emoji))")
            } else {
                // Fallback to generic active icon
                if let image = NSImage(named: "status-active") {
                    image.size = NSSize(width: 18, height: 18)
                    image.isTemplate = true
                    button.image = image
                    button.title = ""
                    print("✅ Updated icon to generic active status")
                } else {
                    button.title = "⏱"
                    button.image = nil
                    print("⚠️ Active icon not found, using fallback text")
                }
            }
        } else {
            // Session is idle - show generic idle icon
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
    
    /// Legacy method for backward compatibility
    static func updateIcon(for button: NSStatusBarButton, isActive: Bool) {
        updateIcon(for: button, isActive: isActive, activityTypeID: nil, projectID: nil)
    }
} 