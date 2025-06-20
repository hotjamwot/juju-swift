import Cocoa
import Carbon // Import Carbon for RegisterEventHotKey

class ShortcutManager {
    private var localMonitor: Any?
    private weak var appDelegate: AppDelegate?
    private var hotKeyRef: EventHotKeyRef? = nil // Store the Carbon hotkey reference
    private var hotKeyEventHandler: EventHandlerRef? = nil // Store the Carbon event handler
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }
    
    func registerGlobalShortcut() {
        print("Registering global shortcut: Shift+Option+Cmd+J (Carbon API)")
        unregisterGlobalShortcut() // Clean up any previous hotkey

        // Key code for 'J' is 38 (kVK_ANSI_J)
        let keyCode: UInt32 = UInt32(kVK_ANSI_J)
        // Modifiers: Shift + Option + Command
        let modifiers: UInt32 = UInt32(shiftKey | optionKey | cmdKey)

        // Define a unique signature and id for your hotkey
        var hotKeyID = EventHotKeyID(signature: OSType(UInt32(truncatingIfNeeded: "JUJU".hashValue)), id: 1)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
        if status == noErr {
            print("✅ Carbon global hotkey registered successfully!")
        } else {
            print("❌ Failed to register Carbon global hotkey. Status: \(status)")
        }

        // Install the event handler if not already installed
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            // This block is called when the hotkey is pressed
            print("✅ Carbon global shortcut detected! Toggling menu...")
            // Get the instance of ShortcutManager from userData
            if let userData = userData {
                let shortcutManager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                    shortcutManager.appDelegate?.showMenuFromShortcut()
                }
            }
            return noErr
        }
        // Pass self as userData so we can call appDelegate
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let installStatus = InstallEventHandler(GetEventDispatcherTarget(), handler, 1, &eventType, userData, &hotKeyEventHandler)
        if installStatus == noErr {
            print("✅ Carbon event handler installed for global hotkey.")
        } else {
            print("❌ Failed to install Carbon event handler. Status: \(installStatus)")
        }

        // Also register local monitor for when app is active (for in-app shortcut)
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
    }
    
    func unregisterGlobalShortcut() {
        // Unregister the Carbon hotkey
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
            print("🗑️ Carbon global hotkey unregistered.")
        }
        // Remove the Carbon event handler
        if let hotKeyEventHandler = hotKeyEventHandler {
            RemoveEventHandler(hotKeyEventHandler)
            self.hotKeyEventHandler = nil
            print("🗑️ Carbon event handler removed.")
        }
    }
    
    func cleanup() {
        // Clean up monitors and hotkeys
        unregisterGlobalShortcut()
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }
} 
