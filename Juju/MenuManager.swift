import Cocoa

class MenuManager {
    private var menu: NSMenu!
    private var projects: [Project] = []
    private weak var appDelegate: AppDelegate?
    private var sessionManager = SessionManager.shared
    private var updateTimer: Timer?
    
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
            
            // Add separator and "Add Project" option
            projectSubmenu.addItem(NSMenuItem.separator())
            let addProjectItem = NSMenuItem(title: "Add New Project...", action: #selector(addNewProject), keyEquivalent: "n")
            addProjectItem.target = self
            projectSubmenu.addItem(addProjectItem)
            
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
    
    private func startUpdateTimer() {
        // Clear any existing timer
        updateTimer?.invalidate()
        
        // Start new timer to update menu every minute
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.refreshMenu()
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
        
        print("[MenuManager] Creating NotesModalWindowController")
        let notesWindow = NotesModalWindowController { [weak self] (note: String?) in
            print("[MenuManager] Notes modal completion handler called. Note: \(note ?? "<nil>")")
            self?.sessionManager.endSession(notes: note ?? "")
            self?.appDelegate?.updateMenuBarIcon(isActive: false)
            self?.refreshMenu()
        }
        
        // Show the WKWebView-based modal
        print("[MenuManager] Calling showWindow on NotesModalWindowController")
        notesWindow.showWindow(nil)
        print("[MenuManager] showWindow call completed")
    }
    
    @objc private func addNewProject() {
        print("Add new project clicked")
        // TODO: Show dialog to add new project
        // For now, just add a test project
        let newProject = Project(name: "New Project \(projects.count + 1)")
        projects.append(newProject)
        ProjectManager.shared.saveProjects(projects)
        appDelegate?.refreshMenu()
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