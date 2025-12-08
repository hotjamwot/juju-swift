import SwiftUI

@MainActor
class ProjectsViewModel: ObservableObject {
    static let shared = ProjectsViewModel()

    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    @Published var isLoading = false
    
    var filteredProjects: [Project] {
        projects.sorted { p1, p2 in
            p1.order < p2.order
        }
    }
    
    /// Active projects (non-archived) sorted by order
    var activeProjects: [Project] {
        projects.filter { !$0.archived }.sorted { p1, p2 in
            p1.order < p2.order
        }
    }
    
    /// Archived projects sorted by order
    var archivedProjects: [Project] {
        projects.filter { $0.archived }.sorted { p1, p2 in
            p1.order < p2.order
        }
    }
    
    private let projectManager = ProjectManager.shared
    
init() {
    Task {
        await loadProjects()
    }
}
    
    func loadProjects() async {
        print("DEBUG: loadProjects() called")
        let loaded = projectManager.loadProjects()
        print("DEBUG: Loaded \(loaded.count) projects")
        await MainActor.run {
            self.projects = loaded
            if self.projects.contains(where: { $0.order == 0 }) {
                print("DEBUG: Reordering projects")
                self.reorderAllProjects()
            }
            print("DEBUG: Done updating view model")
        }
    }
    
    
    
    func addProject(name: String, color: String, about: String?, phases: [Phase] = [], archived: Bool = false) -> Project {
        let newProject = Project(
            name: name,
            color: color,
            about: about,
            order: 0, // Will be set by ProjectManager
            emoji: "📝",
            phases: phases
        )
        
        // Use ProjectManager to handle proper ID and order assignment
        projectManager.addProject(newProject)
        
        // Refresh the UI after saving
        Task {
            await loadProjects()
        }
        
        // Return the project with proper ID and order
        return newProject
    }
    
    func moveProject(fromOffsets source: IndexSet, toOffset destination: Int) {
        projects.move(fromOffsets: source, toOffset: destination)
        reorderAllProjects()
        projectManager.saveProjects(projects)
        
        // Refresh the UI after saving
        Task {
            await loadProjects()
        }
    }
    
    private func reorderAllProjects() {
        for (index, var project) in projects.enumerated() {
            project.order = index + 1
            projects[index] = project
        }
    }
    
    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            let oldProject = projects[index]
            projects[index] = project
            projectManager.saveProjects(projects)
            
            // Refresh the UI after saving
            Task {
                await loadProjects()
            }
            
            // If project name changed, update all sessions with the old name
            if oldProject.name != project.name {
                updateSessionProjectNames(oldName: oldProject.name, newName: project.name)
            }
        }
    }
    
    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        if selectedProject?.id == project.id {
            selectedProject = nil
        }
        projectManager.saveProjects(projects)
        
        // Refresh the UI after saving
        Task {
            await loadProjects()
        }
    }
    
    /// Archive a project
    func archiveProject(_ project: Project) async {
        projectManager.setProjectArchived(true, for: project.id)
        await loadProjects()
    }
    
    /// Unarchive a project
    func unarchiveProject(_ project: Project) async {
        projectManager.setProjectArchived(false, for: project.id)
        await loadProjects()
    }
    
    /// Update all sessions that reference the old project name to use the new name
    private func updateSessionProjectNames(oldName: String, newName: String) {
        let sessionManager = SessionManager.shared
        
        // Get all sessions that have the old project name
        let sessionsToUpdate = sessionManager.allSessions.filter { $0.projectName == oldName }
        
        if sessionsToUpdate.isEmpty {
            return
        }
        
        // Update each session
        for session in sessionsToUpdate {
            sessionManager.updateSessionFull(
                id: session.id,
                date: session.date,
                startTime: session.startTime,
                endTime: session.endTime,
                projectName: newName,
                notes: session.notes,
                mood: session.mood
            )
        }
        
        print("✅ Updated \(sessionsToUpdate.count) sessions from project '\(oldName)' to '\(newName)'")
    }
}
