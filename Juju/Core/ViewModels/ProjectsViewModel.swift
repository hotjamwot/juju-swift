import SwiftUI

@MainActor
class ProjectsViewModel: ObservableObject {
    static let shared = ProjectsViewModel()

    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    
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
    
    
    
    func addProject(name: String, color: String, about: String?) {
        let maxOrder = projects.map(\.order).max() ?? 0
        let newProject = Project(name: name, color: color, about: about, order: maxOrder + 1)
        projects.append(newProject)
        projectManager.saveProjects(projects)
    }
    
    func moveProject(fromOffsets source: IndexSet, toOffset destination: Int) {
        projects.move(fromOffsets: source, toOffset: destination)
        reorderAllProjects()
        projectManager.saveProjects(projects)
    }
    
    private func reorderAllProjects() {
        for (index, var project) in projects.enumerated() {
            project.order = index + 1
            projects[index] = project
        }
    }
    
    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            projectManager.saveProjects(projects)
        }
    }
    
    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        if selectedProject?.id == project.id {
            selectedProject = nil
        }
        projectManager.saveProjects(projects)
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
}
