import Cocoa

class MenuManager {
    private var menu: NSMenu!
    private var projects: [Project] = []
    private weak var appDelegate: AppDelegate?
    private var sessionManager = SessionManager.shared
    private var updateTimer: Timer?
    private var notesWindowController: NotesModalWindowController?
    private weak var endSessionMenuItem: NSMenuItem?
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }
    
    func createMenu(with projects: [Project]) {
        self.projects = projects
        menu = NSMenu()
        
        // Session management based on state
        if sessionManager.isSessionActive {
            // Session is active - show End Session
            let endSessionItem = NSMenuItem(
                title: "End Session (\(sessionManager.currentProjectName ?? "Unknown") - \(sessionManager.getCurrentSessionDuration()))",
                action: #selector(endCurrentSession),
                keyEquivalent: "e"
            )
            endSessionItem.target = self
            menu.addItem(endSessionItem)
            endSessionMenuItem = endSessionItem
        } else {
            // Session is idle - show Start Session with project submenu
            let startSessionItem = NSMenuItem(title: "Start Session", action: nil, keyEquivalent: "s")
            let projectSubmenu = NSMenu()
            
            // Add projects to submenu
            for project in projects {
                let projectItem = NSMenuItem(title: project.name, action: #selector(startSessionForProject(_:)), keyEquivalent: "")
                projectItem.target = self
                projectItem.representedObject = project
                projectSubmenu.addItem(projectItem)
            }
            
            startSessionItem.submenu = projectSubmenu
            menu.addItem(startSessionItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // View Dashboard
        let dashboardItem = NSMenuItem(title: "View Dashboard", action: #selector(showDashboard), keyEquivalent: "d")
        dashboardItem.target = self
        menu.addItem(dashboardItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Juju", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    func getMenu() -> NSMenu {
        return menu
    }
    
    func updateProjects(_ projects: [Project]) {
        self.projects = projects
        createMenu(with: projects)
    }
    
    func refreshMenu() {
        createMenu(with: projects)
    }
    
    func startUpdateTimer() {
        // Clear any existing timer
        updateTimer?.invalidate()
        
        // Start new timer to update menu every minute
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.sessionManager.isSessionActive, let item = self.endSessionMenuItem {
                item.title = "End Session (\(self.sessionManager.currentProjectName ?? "Unknown") - \(self.sessionManager.getCurrentSessionDuration()))"
            } else {
                self.refreshMenu()
            }
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    @objc private func startSessionForProject(_ sender: NSMenuItem) {
        if let project = sender.representedObject as? Project {
            print("Starting session for project: \(project.name) (ID: \(project.id))")
            
            // Start the session
            sessionManager.startSession(for: project.name)
            
            // Update UI
            appDelegate?.updateMenuBarIcon(isActive: true)
            refreshMenu()
            startUpdateTimer()
        }
    }
    
    @objc private func endCurrentSession() {
        print("[MenuManager] endCurrentSession called")
        stopUpdateTimer()
        
        print("[MenuManager] Preparing NotesModalWindowController")
        if notesWindowController == nil {
            notesWindowController = NotesModalWindowController { [weak self] (note: String?, mood: Int?) in
                print("[MenuManager] Notes modal completion handler called. Note: \(note ?? "<nil>") Mood: \(mood.map { String($0) } ?? "<nil>")")
                // Only end the session if notes are provided (not null)
                if let note = note {
                    self?.sessionManager.endSession(notes: note, mood: mood)
                    self?.appDelegate?.updateMenuBarIcon(isActive: false)
                    self?.refreshMenu()
                } else {
                    // Session was cancelled, restart the update timer and keep session active
                    print("[MenuManager] Session cancelled, keeping session active")
                    self?.startUpdateTimer()
                }
            }
        }
        guard let notesWindow = notesWindowController else { return }
        
        // Show the AppKit-based modal
        print("[MenuManager] Calling present on NotesModalWindowController")
        notesWindow.present { [weak self] (note: String?, mood: Int?) in
            print("[MenuManager] Notes modal completion handler called. Note: \(note ?? "<nil>") Mood: \(mood.map { String($0) } ?? "<nil>")")
            if let note = note {
                self?.sessionManager.endSession(notes: note, mood: mood)
                self?.appDelegate?.updateMenuBarIcon(isActive: false)
                self?.refreshMenu()
            } else {
                print("[MenuManager] Session cancelled, keeping session active")
                self?.startUpdateTimer()
            }
        }
        print("[MenuManager] showWindow call completed")
    }
    
    @objc private func showDashboard() {
        print("Show Dashboard clicked")
        appDelegate?.showDashboard()
    }
    
    @objc private func quit() {
        print("Quit clicked")
        NSApplication.shared.terminate(nil)
    }
} 