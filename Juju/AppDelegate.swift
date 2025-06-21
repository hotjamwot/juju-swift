import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    var statusItem: NSStatusItem!
    var dashboardWindow: NSWindow?
    var menuManager: MenuManager!
    var shortcutManager: ShortcutManager!
    var projects: [Project] = []
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Enable Web Inspector for WKWebView
        UserDefaults.standard.set(true, forKey: "WebKitDeveloperExtras")
        
        // Load projects
        projects = ProjectManager.shared.loadProjects()
        
        // Create managers
        menuManager = MenuManager(appDelegate: self)
        shortcutManager = ShortcutManager(appDelegate: self)
        
        // Create the status item (menu bar icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Load icon
            IconManager.loadIcon(for: button)
            
            button.action = #selector(toggleMenu)
            button.target = self
        }
        
        // Create the menu
        menuManager.createMenu(with: projects)
        
        // Register global shortcut
        shortcutManager.registerGlobalShortcut()
    }
    
    @objc func toggleMenu() {
        if let button = statusItem.button {
            menuManager.getMenu().popUp(positioning: nil, at: NSPoint.zero, in: button)
        }
    }
    
    func showMenuFromShortcut() {
        if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            let menu = menuManager.getMenu()
            menu.popUp(positioning: nil, at: NSPoint.zero, in: button)
            // The first menu item is automatically highlighted when the menu opens
            // This is the standard macOS behavior for global shortcuts
        }
    }
    
    func showDashboard() {
        if dashboardWindow == nil {
            createDashboardWindow()
        }
        
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func createDashboardWindow() {
        let windowSize = NSSize(width: 1320, height: 840) // 10% wider (1200 -> 1320), 5% taller (800 -> 840)
        let minWindowSize = NSSize(width: 900, height: 600)
        let screen = NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1400, height: 900)
        let x = screenFrame.midX - windowSize.width / 2
        let y = screenFrame.midY - windowSize.height / 2
        let windowRect = NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height)
        dashboardWindow = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        dashboardWindow?.title = "Juju Time Tracker"
        dashboardWindow?.titleVisibility = .hidden
        dashboardWindow?.titlebarAppearsTransparent = true
        dashboardWindow?.isMovableByWindowBackground = true
        dashboardWindow?.backgroundColor = NSColor.windowBackgroundColor
        dashboardWindow?.isReleasedWhenClosed = false
        dashboardWindow?.level = .normal
        dashboardWindow?.contentMinSize = minWindowSize
        dashboardWindow?.delegate = self
        let dashboardView = DashboardWebViewController()
        dashboardWindow?.contentViewController = dashboardView
        dashboardWindow?.setFrame(windowRect, display: true)
        dashboardWindow?.makeKeyAndOrderFront(nil)
    }
    
    func updateMenuBarIcon(isActive: Bool) {
        if let button = statusItem.button {
            IconManager.updateIcon(for: button, isActive: isActive)
        }
    }
    
    func refreshMenu() {
        projects = ProjectManager.shared.loadProjects()
        menuManager.refreshMenu()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        shortcutManager.cleanup()
    }
    
    // MARK: - Window Delegate Methods
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === dashboardWindow {
            dashboardWindow = nil
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Allow the window to close normally
        return true
    }
    
    func window(_ window: NSWindow, willEncodeRestorableState state: NSCoder) {
        // Save window state if needed
    }
    
    func window(_ window: NSWindow, didDecodeRestorableState state: NSCoder) {
        // Restore window state if needed
    }
    
    // Handle keyboard shortcuts for the dashboard window
    func window(_ window: NSWindow, performKeyEquivalent event: NSEvent) -> Bool {
        // Only handle shortcuts for the dashboard window
        guard window === dashboardWindow else {
            return false
        }
        
        let commandKey = NSEvent.ModifierFlags.command.rawValue
        let eventFlags = event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue

        if event.type == .keyDown && eventFlags == commandKey {
            switch event.charactersIgnoringModifiers {
            case "w":
                window.close()
                return true
            case "a":
                if let dashboardView = window.contentViewController as? DashboardWebViewController {
                    dashboardView.webView?.evaluateJavaScript("document.execCommand('selectAll');", completionHandler: nil)
                }
                return true
            case "v":
                if let dashboardView = window.contentViewController as? DashboardWebViewController {
                    dashboardView.webView?.evaluateJavaScript("document.execCommand('paste');", completionHandler: nil)
                }
                return true
            case "c":
                if let dashboardView = window.contentViewController as? DashboardWebViewController {
                    dashboardView.webView?.evaluateJavaScript("document.execCommand('copy');", completionHandler: nil)
                }
                return true
            case "x":
                if let dashboardView = window.contentViewController as? DashboardWebViewController {
                    dashboardView.webView?.evaluateJavaScript("document.execCommand('cut');", completionHandler: nil)
                }
                return true
            default:
                // Don't intercept other shortcuts like Cmd+D, Cmd+Q, etc.
                break
            }
        }
        return false
    }
} 