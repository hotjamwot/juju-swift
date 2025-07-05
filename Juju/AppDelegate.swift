import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    var statusItem: NSStatusItem!
    var menuManager: MenuManager!
    var shortcutManager: ShortcutManager!
    var projects: [Project] = []
    var dashboardWindow: NSWindow?
    var dashboardWindowController: DashboardWindowController?
    
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

        // Add a minimal main menu with Edit items to restore shortcut support
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
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
        if dashboardWindowController == nil {
            dashboardWindowController = DashboardWindowController()
        }
        dashboardWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func updateMenuBarIcon(isActive: Bool) {
        if let button = statusItem.button {
            IconManager.updateIcon(for: button, isActive: isActive)
        }
    }
    
    func refreshMenu() {
        projects = ProjectManager.shared.loadProjects()
        menuManager.updateProjects(projects)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        shortcutManager.cleanup()
    }
    
    // MARK: - Window Delegate Methods
    
    func windowWillClose(_ notification: Notification) {
        print("[AppDelegate] windowWillClose called for dashboard window")
        if let window = notification.object as? NSWindow, window == dashboardWindow {
            dashboardWindow = nil
        }
    }
} 