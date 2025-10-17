import SwiftUI

class ProjectsViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    @Published var isGridView: Bool = true
    @Published var searchText: String = ""
    @Published var sortOrder: SortOrder = .order
    
    enum SortOrder {
        case order, name, dateCreated
    }
    
    var filteredProjects: [Project] {
        let sorted = projects.sorted { p1, p2 in
            switch sortOrder {
            case .order:
                return p1.order < p2.order
            case .name:
                return p1.name.lowercased() < p2.name.lowercased()
            case .dateCreated:
                return p1.id < p2.id
            }
        }
        
        if searchText.isEmpty {
            return sorted
        }
        
        return sorted.filter {
            $0.name.lowercased().contains(searchText.lowercased()) ||
            ($0.about ?? "").lowercased().contains(searchText.lowercased())
        }
    }
    
    private let projectManager = ProjectManager.shared
    
    init() {
        loadProjects()
    }
    
    func loadProjects() {
        projects = projectManager.loadProjects()
        // Ensure projects have valid order values
        if projects.contains(where: { $0.order == 0 }) {
            reorderAllProjects()
        }
    }
    
    func addProject(name: String) {
        let maxOrder = projects.map(\.order).max() ?? 0
        let newProject = Project(name: name, order: maxOrder + 1)
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
}
