import Foundation

// Project structure to match the original app
struct Project: Codable {
    let id: String
    var name: String
    var color: String
    
    init(name: String, color: String = "#4E79A7") {
        self.id = Date().timeIntervalSince1970.description + String(format: "%03d", Int.random(in: 0...999))
        self.name = name
        self.color = color
    }
}

// Project management functionality
class ProjectManager {
    static let shared = ProjectManager()
    private let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    private let jujuPath: URL?
    private let projectsFile: URL?
    
    private init() {
        self.jujuPath = appSupportPath?.appendingPathComponent("Juju")
        self.projectsFile = jujuPath?.appendingPathComponent("projects.json")
    }
    
    func loadProjects() -> [Project] {
        // Create directory if it doesn't exist
        if let jujuPath = jujuPath {
            try? FileManager.default.createDirectory(at: jujuPath, withIntermediateDirectories: true)
        }
        
        // Load projects from file or create default
        if let projectsFile = projectsFile {
            do {
                let data = try Data(contentsOf: projectsFile)
                let loadedProjects = try JSONDecoder().decode([Project].self, from: data)
                let migratedProjects = migrateProjects(loadedProjects)
                print("Loaded \(migratedProjects.count) projects from \(projectsFile.path)")
                return migratedProjects
            } catch {
                print("Error loading projects: \(error)")
                // Create default projects if file doesn't exist or is invalid
                return createDefaultProjects()
            }
        } else {
            return createDefaultProjects()
        }
    }
    
    func saveProjects(_ projects: [Project]) {
        if let projectsFile = projectsFile {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(projects)
                try data.write(to: projectsFile)
                print("✅ Saved \(projects.count) projects to \(projectsFile.path)")
            } catch {
                print("❌ Error saving projects to \(projectsFile.path): \(error)")
            }
        }
    }
    
    private func migrateProjects(_ loadedProjects: [Project]) -> [Project] {
        var needsRewrite = false
        var migratedProjects: [Project] = []
        
        for project in loadedProjects {
            var migratedProject = project
            
            // Ensure project has a valid name
            if project.name.isEmpty || project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                migratedProject.name = "Unnamed"
                needsRewrite = true
                print("Found project with invalid name, setting to 'Unnamed'")
            }
            
            // Ensure project has a valid color
            if project.color.isEmpty || !project.color.hasPrefix("#") {
                migratedProject.color = "#4E79A7"
                needsRewrite = true
                print("Found project with invalid color, setting to default")
            }
            
            migratedProjects.append(migratedProject)
        }
        
        if needsRewrite {
            print("Projects migrated, will rewrite file")
            saveProjects(migratedProjects)
        }
        
        return migratedProjects
    }
    
    private func createDefaultProjects() -> [Project] {
        let defaults = [
            Project(name: "Work", color: "#4E79A7"),
            Project(name: "Personal", color: "#F28E2C"),
            Project(name: "Learning", color: "#E15759"),
            Project(name: "Other", color: "#76B7B2")
        ]
        print("Created default projects")
        saveProjects(defaults)
        return defaults
    }
} 