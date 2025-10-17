import Foundation

// Project structure to match the original app
struct Project: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var color: String
    var about: String?
    var order: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, about, order
    }
    
    init(name: String, color: String = "#4E79A7", about: String? = nil, order: Int = 0) {
        self.id = Date().timeIntervalSince1970.description + String(format: "%03d", Int.random(in: 0...999))
        self.name = name
        self.color = color
        self.about = about
        self.order = order
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#4E79A7"
        about = try container.decodeIfPresent(String.self, forKey: .about)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color, forKey: .color)
        try container.encodeIfPresent(about, forKey: .about)
        try container.encode(order, forKey: .order)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
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
                if FileManager.default.fileExists(atPath: projectsFile.path) {
                    // File exists but invalid JSON - return empty to prevent overwrite
                    print("Invalid projects.json exists, returning empty array to avoid overwrite")
                    return []
                } else {
                    // File doesn't exist, create defaults
                    return createDefaultProjects()
                }
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
        
        for var project in loadedProjects {
            // Ensure project has a valid name
            if project.name.isEmpty || project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                project.name = "Unnamed"
                needsRewrite = true
                print("Found project with invalid name, setting to 'Unnamed'")
            }
            
            // Ensure project has a valid color
            if project.color.isEmpty || !project.color.hasPrefix("#") {
                project.color = "#4E79A7"
                needsRewrite = true
                print("Found project with invalid color, setting to default")
            }
            // Ensure project has an about field (allow empty string by default)
            if project.about == nil {
                project.about = ""
                needsRewrite = true
                print("Adding missing 'about' field to project \(project.name)")
            }
            
            migratedProjects.append(project)
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
