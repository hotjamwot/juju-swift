import Foundation
import SwiftUI

extension Notification.Name {
    static let projectsDidChange = Notification.Name("projectsDidChange")
    static let sessionDidEnd = Notification.Name("sessionDidEnd")
    static let sessionDidStart = Notification.Name("sessionDidStart")
}

    // No Color extensions here - use JujuUtils

// MARK: - Phase Structure
struct Phase: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var order: Int
    var archived: Bool
    
    init(id: String = UUID().uuidString, name: String, order: Int = 0, archived: Bool = false) {
        self.id = id
        self.name = name
        self.order = order
        self.archived = archived
    }
}

// Project structure to match the original app
struct Project: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var color: String
    var about: String?
    var order: Int
    var emoji: String
    var archived: Bool 
    var phases: [Phase] 
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, about, order, emoji, archived, phases
    }
    
    // Computed SwiftUI Color from hex string (avoids storing Color)
    var swiftUIColor: Color {
        Color(hex: color)
    }
    
    init(name: String, color: String = "#4E79A7", about: String? = nil, order: Int = 0, emoji: String = "📁", phases: [Phase] = []) {
        self.id = Date().timeIntervalSince1970.description + String(format: "%03d", Int.random(in: 0...999))
        self.name = name
        self.color = color
        self.about = about
        self.order = order
        self.emoji = emoji
        self.archived = false
        self.phases = phases
    }
    
    init(id: String, name: String, color: String, about: String?, order: Int, emoji: String = "📁", phases: [Phase] = []) {
        self.id = id
        self.name = name
        self.color = color
        self.about = about
        self.order = order
        self.emoji = emoji
        self.archived = false
        self.phases = phases
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#4E79A7"
        about = try container.decodeIfPresent(String.self, forKey: .about)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? "📁"
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived) ?? false  // Default to false for legacy projects
        phases = try container.decodeIfPresent([Phase].self, forKey: .phases) ?? []  // Default to empty array for legacy projects
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color, forKey: .color)
        try container.encodeIfPresent(about, forKey: .about)
        try container.encode(order, forKey: .order)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(archived, forKey: .archived)
        try container.encode(phases, forKey: .phases)
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
    
    // Cache for loaded projects to avoid repeated disk access
    private var cachedProjects: [Project]?
    private var lastCacheTime: Date?
    
    private init() {
        self.jujuPath = appSupportPath?.appendingPathComponent("Juju")
        self.projectsFile = jujuPath?.appendingPathComponent("projects.json")
    }
    
    func loadProjects() -> [Project] {
        // Check cache first (cache for 5 minutes to avoid excessive disk access)
        if let cached = cachedProjects, 
           let lastTime = lastCacheTime, 
           Date().timeIntervalSince(lastTime) < 300 { // 5 minutes
            return cached
        }
        
        // Create directory if it doesn't exist
        if let jujuPath = jujuPath {
            try? FileManager.default.createDirectory(at: jujuPath, withIntermediateDirectories: true)
        }
        
        // Load projects from file or create default
        if let projectsFile = projectsFile, FileManager.default.fileExists(atPath: projectsFile.path) {
            do {
                let data = try Data(contentsOf: projectsFile)
                let loadedProjects = try JSONDecoder().decode([Project].self, from: data)
                print("Loaded \(loadedProjects.count) projects from \(projectsFile.path)")
                
                // Check if migration is needed (old format without archived fields)
                let needsMigration = loadedProjects.contains { project in
                    project.phases.contains { phase in
                        phase.archived != phase.archived
                    }
                }
                
                var resultProjects: [Project]
                if needsMigration {
                    print("🔄 Migrating projects to new schema...")
                    resultProjects = migrateProjects(loadedProjects)
                } else {
                    resultProjects = loadedProjects
                }
                
                // Cache the result
                cachedProjects = resultProjects
                lastCacheTime = Date()
                
                return resultProjects
            } catch {
                print("Error loading projects: \(error)")
                print("Deleting invalid projects.json and creating defaults")
                try? FileManager.default.removeItem(at: projectsFile)
                let defaults = createDefaultProjects()
                cachedProjects = defaults
                lastCacheTime = Date()
                return defaults
            }
        } else {
            let defaults = createDefaultProjects()
            cachedProjects = defaults
            lastCacheTime = Date()
            return defaults
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
                // Clear cache after saving to ensure fresh data on next load
                clearCache()
                NotificationCenter.default.post(name: .projectsDidChange, object: nil)
            } catch {
                print("❌ Error saving projects to \(projectsFile.path): \(error)")
            }
        }
    }
    
    // MARK: - Project Archiving Management
    
    /// Archive or unarchive a project
    func setProjectArchived(_ archived: Bool, for projectID: String) {
        var projects = loadProjects()
        if let projectIndex = projects.firstIndex(where: { $0.id == projectID }) {
            var project = projects[projectIndex]
            project.archived = archived
            projects[projectIndex] = project
            saveProjects(projects)
        }
    }
    
    /// Get active projects (non-archived)
    func getActiveProjects() -> [Project] {
        let projects = loadProjects()
        return projects.filter { !$0.archived }
    }
    
    /// Get archived projects
    func getArchivedProjects() -> [Project] {
        let projects = loadProjects()
        return projects.filter { $0.archived }
    }
    
    /// Get all projects (including archived)
    func getAllProjects() -> [Project] {
        return loadProjects()
    }
    
    // MARK: - Legacy Data Handling Helpers
    
    /// Get phase display name for a given project and phase ID, with fallback for legacy data
    func getPhaseDisplay(projectID: String?, phaseID: String?) -> String? {
        guard let projectID = projectID, let phaseID = phaseID else {
            return nil
        }
        
        let projects = loadProjects()
        guard let project = projects.first(where: { $0.id == projectID }),
              let phase = project.phases.first(where: { $0.id == phaseID && !$0.archived }) else {
            return nil
        }
        
        return phase.name
    }
    
    // MARK: - Phase Management with Archiving
    
    /// Add a phase to a project
    func addPhase(to projectID: String, phase: Phase) {
        var projects = loadProjects()
        if let projectIndex = projects.firstIndex(where: { $0.id == projectID }) {
            var project = projects[projectIndex]
            project.phases.append(phase)
            projects[projectIndex] = project
            saveProjects(projects)
        }
    }
    
    /// Update a phase in a project
    func updatePhase(in projectID: String, phase: Phase) {
        var projects = loadProjects()
        if let projectIndex = projects.firstIndex(where: { $0.id == projectID }),
           let phaseIndex = projects[projectIndex].phases.firstIndex(where: { $0.id == phase.id }) {
            var project = projects[projectIndex]
            project.phases[phaseIndex] = phase
            projects[projectIndex] = project
            saveProjects(projects)
        }
    }
    
    /// Archive or unarchive a phase in a project
    func setPhaseArchived(_ archived: Bool, in projectID: String, phaseID: String) {
        var projects = loadProjects()
        if let projectIndex = projects.firstIndex(where: { $0.id == projectID }),
           let phaseIndex = projects[projectIndex].phases.firstIndex(where: { $0.id == phaseID }) {
            var project = projects[projectIndex]
            project.phases[phaseIndex].archived = archived
            projects[projectIndex] = project
            saveProjects(projects)
        }
    }
    
    /// Delete a phase from a project (permanent removal)
    func deletePhase(from projectID: String, phaseID: String) {
        var projects = loadProjects()
        if let projectIndex = projects.firstIndex(where: { $0.id == projectID }) {
            var project = projects[projectIndex]
            project.phases.removeAll { $0.id == phaseID }
            projects[projectIndex] = project
            saveProjects(projects)
        }
    }
    
    /// Get active phases for a project (non-archived)
    func getActivePhases(for projectID: String) -> [Phase] {
        let projects = loadProjects()
        guard let project = projects.first(where: { $0.id == projectID }) else {
            return []
        }
        return project.phases.filter { !$0.archived }
    }
    
    /// Get all phases for a project (including archived)
    func getAllPhases(for projectID: String) -> [Phase] {
        let projects = loadProjects()
        guard let project = projects.first(where: { $0.id == projectID }) else {
            return []
        }
        return project.phases
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
            
            // Ensure project has an emoji field (use default folder emoji)
            if project.emoji.isEmpty {
                project.emoji = "📁"
                needsRewrite = true
                print("Adding missing 'emoji' field to project \(project.name)")
            }
            
            // Ensure project has an archived field (default to false for legacy projects)
            // This is handled by the decoder default, but we ensure it's properly set
            if !needsRewrite {
                // Only mark for rewrite if there are other issues
            }
            
                // Ensure phases have order values (for legacy projects without order field)
                if !project.phases.isEmpty {
                    let phasesNeedOrder = project.phases.contains { phase in
                        // If any phase doesn't have a proper order, we need to migrate
                        phase.order == 0 && project.phases.firstIndex(where: { $0.id == phase.id }) != 0
                    }
                    
                    if phasesNeedOrder {
                        var updatedProject = project
                        for (index, phase) in updatedProject.phases.enumerated() {
                            var mutablePhase = phase
                            mutablePhase.order = index
                            updatedProject.phases[index] = mutablePhase
                        }
                        project = updatedProject
                        needsRewrite = true
                        print("Adding order values to phases for project \(project.name)")
                    }
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
            Project(name: "Work", color: "#4E79A7", emoji: "💼"),
            Project(name: "Personal", color: "#F28E2C", emoji: "🏠"),
            Project(name: "Learning", color: "#E15759", emoji: "📚"),
            Project(name: "Other", color: "#76B7B2", emoji: "📁")
        ]
        print("Created default projects")
        saveProjects(defaults)
        return defaults
    }
    
    /// Clear the projects cache
    func clearCache() {
        cachedProjects = nil
        lastCacheTime = nil
    }
}
