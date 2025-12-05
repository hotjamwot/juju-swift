import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    var statusItem: NSStatusItem!
    var menuManager: MenuManager!
    var shortcutManager: ShortcutManager!
    var projects: [Project] = []
    var dashboardWindowController: DashboardWindowController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
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
        
        // Register for session end notifications to refresh menu
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionDidEnd),
            name: .sessionDidEnd,
            object: nil
        )
        
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
        let windowMenuItem = NSMenuItem()
mainMenu.addItem(windowMenuItem)
let windowMenu = NSMenu(title: "Window")
windowMenuItem.submenu = windowMenu
windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
windowMenu.addItem(NSMenuItem.separator())
// Optional: Order Front (Cmd + `)
windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "`")
NSApp.mainMenu = mainMenu

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
        // Always reuse existing dashboard window controller if it exists
        if dashboardWindowController == nil {
            print("[AppDelegate] Creating new DashboardWindowController")
            dashboardWindowController = DashboardWindowController()
        } else {
            print("[AppDelegate] Reusing existing DashboardWindowController")
            // Ensure the window is properly configured for reuse
            if let window = dashboardWindowController?.window {
                // Reset the window to a clean state
                window.orderFront(nil)
            }
        }
        
        // Show the window (either existing or new)
        dashboardWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func forceCloseDashboard() {
        print("[AppDelegate] forceCloseDashboard called")
        if let controller = dashboardWindowController {
            controller.close()
            dashboardWindowController = nil
        }
    }
    
    func updateMenuBarIcon(isActive: Bool) {
        if let button = statusItem.button {
            let sessionManager = SessionManager.shared
            let activityTypeID: String? = sessionManager.isSessionActive ? nil : nil // Activity is nil during active session, set at end
            let projectID: String? = sessionManager.currentProjectID
            
            IconManager.updateIcon(
                for: button,
                isActive: isActive,
                activityTypeID: activityTypeID,
                projectID: projectID
            )
        }
    }
    
    func refreshMenu() {
        projects = ProjectManager.shared.loadProjects()
        menuManager.updateProjects(projects)
    }
    
    @objc private func onSessionDidEnd() {
        print("[AppDelegate] Session did end notification received, refreshing menu")
        refreshMenu()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        print("[AppDelegate] applicationWillTerminate called")
        
        // Close dashboard if open
        forceCloseDashboard()
        
        shortcutManager.cleanup()
    }
    
    // MARK: - Window Delegate Methods
    
    func windowWillClose(_ notification: Notification) {
        print("[AppDelegate] windowWillClose called for dashboard window")
        if let window = notification.object as? NSWindow, let controller = dashboardWindowController, controller.window == window {
            dashboardWindowController = nil
        }
    }
}
