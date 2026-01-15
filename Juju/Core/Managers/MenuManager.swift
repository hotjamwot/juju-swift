import Cocoa
import SwiftUI

class MenuManager {
    private var menu: NSMenu!
    private var projects: [Project] = []
    private weak var appDelegate: AppDelegate?
    private var sessionManager = SessionManager.shared
    private var updateTimer: Timer?
    private weak var endSessionMenuItem: NSMenuItem?
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        
        // Observe project changes to refresh menu
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onProjectsDidChange),
            name: .projectsDidChange,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func onProjectsDidChange() {
        projects = ProjectManager.shared.loadProjects()
        updateProjects(projects)
    }
    
    
    func createMenu(with projects: [Project]) {
        self.projects = projects
        menu = NSMenu()
        
        // Filter out archived projects for menu display
        let activeProjects = projects.filter { !$0.archived }
        
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
            
            // Add only active (non-archived) projects to submenu
            for project in activeProjects {
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
            
            // Start the session with projectID
            sessionManager.startSession(for: project.name, projectID: project.id)
            
            // Update UI
            appDelegate?.updateMenuBarIcon(isActive: true)
            refreshMenu()
            startUpdateTimer()
        }
    }
    
    @MainActor @objc private func endCurrentSession() {
        print("[MenuManager] endCurrentSession called")
        stopUpdateTimer()
        
        // Get current project info
        let projectID = sessionManager.currentProjectID
        let projectName = sessionManager.currentProjectName
        
        print("[MenuManager] Presenting SwiftUI Notes modal")
        // Show the new SwiftUI-based modal
        Task { @MainActor in
            await MainActor.run {
                NotesManager.shared.presentNotes(
                    projectID: projectID,
                    projectName: projectName,
                    projects: self.projects
                ) { [weak self] (note: String?, mood: Int?, activityTypeID: String?, projectPhaseID: String?, milestoneText: String?, action: String, isMilestone: Bool) in
                    print("[MenuManager] Notes modal completion handler called. Note: \(note ?? "nil") Mood: \(mood.map { String($0) } ?? "nil") Activity: \(activityTypeID ?? "nil") Phase: \(projectPhaseID ?? "nil") Milestone: \(milestoneText ?? "nil") Action: \(action) IsMilestone: \(isMilestone)")
                    // Only end the session if notes are provided (not empty) and action is provided
                    if let note = note, !note.isEmpty, !action.isEmpty {
                        self?.sessionManager.endSession(
                            notes: note,
                            mood: mood,
                            activityTypeID: activityTypeID,
                            projectPhaseID: projectPhaseID,
                            milestoneText: milestoneText, // Deprecated, but pass for transition
                            action: action,             // New parameter
                            isMilestone: isMilestone   // New parameter
                        )
                        self?.appDelegate?.updateMenuBarIcon(isActive: false)
                        self?.refreshMenu()
                    } else {
                        // Session was cancelled or action was missing, restart the update timer and keep session active
                        print("[MenuManager] Session cancelled or action missing, keeping session active")
                        self?.startUpdateTimer()
                    }
                }
            }
        }
        print("[MenuManager] SwiftUI Notes modal presentation completed")
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
