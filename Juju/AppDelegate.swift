import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    var statusItem: NSStatusItem!
    var dashboardWindow: NSWindow?
    var menuManager: MenuManager!
    var shortcutManager: ShortcutManager!
    var projects: [Project] = []
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("Juju app launching...")
        
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
        
        print("Menu bar icon created successfully!")
        print("Click the icon in the menu bar to see the menu!")
        print("Use Shift+Option+Cmd+J to toggle the menu!")
    }
    
    @objc func toggleMenu() {
        if let button = statusItem.button {
            menuManager.getMenu().popUp(positioning: nil, at: NSPoint.zero, in: button)
        }
    }
    
    func showMenuFromShortcut() {
        if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            menuManager.getMenu().popUp(positioning: nil, at: NSPoint.zero, in: button)
            print("Menu opened from shortcut")
        }
    }
    
    func showDashboard() {
        print("Show Dashboard clicked")
        if dashboardWindow == nil {
            createDashboardWindow()
        }
        
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func createDashboardWindow() {
        print("🔍 Creating dashboard window...")
        let windowSize = NSSize(width: 1200, height: 800)
        let minWindowSize = NSSize(width: 900, height: 600)
        let screen = NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1400, height: 900)
        let x = screenFrame.midX - windowSize.width / 2
        let y = screenFrame.midY - windowSize.height / 2
        let windowRect = NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height)
        print("🔍 Screen frame: \(screenFrame)")
        print("🔍 Window rect: \(windowRect)")
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
        print("🔍 Dashboard window created, making key and ordering front...")
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
        print("Juju app terminating...")
    }
    
    // MARK: - Window Delegate Methods
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === dashboardWindow {
            dashboardWindow = nil
            print("Dashboard window closed")
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
} 