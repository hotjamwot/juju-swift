import Cocoa

class ShortcutManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private weak var appDelegate: AppDelegate?
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }
    
    func registerGlobalShortcut() {
        print("Registering global shortcut: Shift+Option+Cmd+J")
        
        // Register Shift+Option+Cmd+J to toggle menu
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            print("🔍 Global key event detected:")
            print("   Key code: \(event.keyCode)")
            print("   Modifiers: \(event.modifierFlags)")
            print("   Characters: '\(event.characters ?? "none")'")
            print("   App: \(event.window?.title ?? "unknown")")
            
            if event.modifierFlags.contains([.command, .shift, .option]) && event.keyCode == 38 { // 38 = J
                print("✅ Global shortcut detected! Toggling menu...")
                DispatchQueue.main.async {
                    // Ensure the app is active when showing menu
                    NSApp.activate(ignoringOtherApps: true)
                    self?.appDelegate?.showMenuFromShortcut()
                }
            }
        }
        
        // Also register local monitor for when app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            print("🔍 Local key event detected:")
            print("   Key code: \(event.keyCode)")
            print("   Modifiers: \(event.modifierFlags)")
            
            if event.modifierFlags.contains([.command, .shift, .option]) && event.keyCode == 38 { // 38 = J
                print("✅ Local shortcut detected! Toggling menu...")
                self?.appDelegate?.showMenuFromShortcut()
                return nil // Consume the event
            }
            return event
        }
        
        print("✅ Global shortcut registered successfully!")
        print("   Try pressing Shift+Option+Cmd+J from any app")
        print("   Note: You may need to grant Accessibility permissions in System Preferences")
    }
    
    func cleanup() {
        // Clean up monitors
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }
} 