import Foundation
import SwiftUI

extension Notification.Name {
    static let projectsDidChange = Notification.Name("projectsDidChange")
    static let sessionDidEnd = Notification.Name("sessionDidEnd")
    static let sessionDidStart = Notification.Name("sessionDidStart")
}

    // No Color extensions here - use JujuUtils

// MARK: - Project Statistics Cache Manager
class ProjectStatisticsCache {
    static let shared = ProjectStatisticsCache()
    
    private var totalDurationCache: [String: Double] = [:] // projectID -> total hours
    private var lastSessionDateCache: [String: Date?] = [:]
    private var lastCacheTime: Date?
    private let cacheExpiryTime: TimeInterval = 30 // Cache expires after 30 seconds
    
    private init() {
        // Listen for session changes to invalidate cache
        NotificationCenter.default.addObserver(
            forName: .sessionDidEnd,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateCache()
        }
        
        NotificationCenter.default.addObserver(
            forName: .projectsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateCache()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func getTotalDuration(for projectID: String) -> Double {
        // Validate cache integrity before accessing (clears corrupted entries)
        validateCacheIntegrity()
        
        // Check if cache is still valid
        guard let lastTime = lastCacheTime,
              Date().timeIntervalSince(lastTime) < cacheExpiryTime else {
            // Cache expired, invalidate and return 0 (will trigger recomputation)
            invalidateCache()
            return 0
        }
        
        // Safe access with nil coalescing - this prevents crashes from corrupted cache
        return totalDurationCache[projectID] ?? 0
    }
    
    func getLastSessionDate(for projectID: String) -> Date? {
        // Validate cache integrity before accessing (clears corrupted entries)
        validateCacheIntegrity()
        
        // Check if cache is still valid
        guard let lastTime = lastCacheTime,
              Date().timeIntervalSince(lastTime) < cacheExpiryTime else {
            // Cache expired, invalidate and return nil (will trigger recomputation)
            invalidateCache()
            return nil
        }
        
        // Safe access with nil coalescing - this prevents crashes from corrupted cache
        return lastSessionDateCache[projectID] ?? nil
    }
    
    func setTotalDuration(_ duration: Double, for projectID: String) {
        // Validate the duration value before caching
        guard !duration.isNaN && !duration.isInfinite else {
            print("⚠️ Invalid duration value \(duration) for project \(projectID), skipping cache")
            return
        }
        totalDurationCache[projectID] = duration
        lastCacheTime = Date()
    }
    
    func setLastSessionDate(_ date: Date?, for projectID: String) {
        // Validate the date before caching (check for corrupted dates)
        if let date = date {
            // Check if date is reasonable (not a corrupted tagged pointer)
            let now = Date()
            let minReasonableDate = Calendar.current.date(byAdding: .year, value: -50, to: now) ?? Date.distantPast
            let maxReasonableDate = Calendar.current.date(byAdding: .year, value: 50, to: now) ?? Date.distantFuture
            
            if date < minReasonableDate || date > maxReasonableDate {
                print("⚠️ Suspicious date \(date) for project \(projectID), skipping cache")
                return
            }
        }
        
        lastSessionDateCache[projectID] = date
        lastCacheTime = Date()
    }
    
    func invalidateCache() {
        totalDurationCache.removeAll()
        lastSessionDateCache.removeAll()
        lastCacheTime = nil
    }
    
    /// Validate cache integrity and clear if corrupted
    func validateCacheIntegrity() {
        // Check for any suspicious cache entries that might cause crashes
        var hasCorruptedEntries = false
        
        // Validate duration cache (safe iteration with error handling)
        do {
            for (projectID, duration) in totalDurationCache {
                if duration.isNaN || duration.isInfinite {
                    print("⚠️ Found corrupted duration \(duration) for project \(projectID)")
                    hasCorruptedEntries = true
                    break
                }
            }
        } catch {
            print("⚠️ Error iterating duration cache, clearing cache")
            hasCorruptedEntries = true
        }
        
        // Validate date cache (basic check for obviously corrupted dates)
        let now = Date()
        let minReasonableDate = Calendar.current.date(byAdding: .year, value: -50, to: now) ?? Date.distantPast
        let maxReasonableDate = Calendar.current.date(byAdding: .year, value: 50, to: now) ?? Date.distantFuture
        
        do {
            for (projectID, date) in lastSessionDateCache {
                if let date = date, (date < minReasonableDate || date > maxReasonableDate) {
                    print("⚠️ Found suspicious date \(date) for project \(projectID)")
                    hasCorruptedEntries = true
                    break
                }
            }
        } catch {
            print("⚠️ Error iterating date cache, clearing cache")
            hasCorruptedEntries = true
        }
        
        if hasCorruptedEntries {
            print("⚠️ Cache corruption detected, clearing cache")
            invalidateCache()
        }
    }
    
    func warmCache(for projects: [Project]) {
        // Pre-compute statistics for all projects in the background
        Task {
            let sessions = SessionManager.shared.allSessions
            
            for project in projects {
                let filteredSessions = sessions.filter { $0.projectID == project.id }
                let totalDuration = filteredSessions.reduce(0) { $0 + Double($1.durationMinutes) / 60.0 }
                let lastDate = filteredSessions.compactMap { $0.startDateTime }.max()
                
                // Update cache on main thread
                await MainActor.run {
                    ProjectStatisticsCache.shared.setTotalDuration(totalDuration, for: project.id)
                    ProjectStatisticsCache.shared.setLastSessionDate(lastDate, for: project.id)
                }
            }
        }
    }
}

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
    var id: String
    var name: String
    var color: String
    var about: String?
    var order: Int
    var emoji: String
    var archived: Bool 
    var phases: [Phase]
    
    // Computed properties for session statistics (using cache)
    var totalDurationHours: Double {
        // Try to get from cache first
        let cachedDuration = ProjectStatisticsCache.shared.getTotalDuration(for: id)
        if cachedDuration > 0 {
            return cachedDuration
        }
        
        // If not in cache or cache expired, compute and cache it
        // Use a safe access pattern to avoid crashes
        let sessionManager = SessionManager.shared
        let totalDuration = sessionManager.allSessions
            .filter { $0.projectID == id }
            .reduce(0) { $0 + Double($1.durationMinutes) / 60.0 }
        ProjectStatisticsCache.shared.setTotalDuration(totalDuration, for: id)
        return totalDuration
    }
    
    var lastSessionDate: Date? {
        // Try to get from cache first
        if let cachedDate = ProjectStatisticsCache.shared.getLastSessionDate(for: id) {
            return cachedDate
        }
        
        // If not in cache or cache expired, compute and cache it
        // Use a safe access pattern to avoid crashes
        let sessionManager = SessionManager.shared
        let sessions = sessionManager.allSessions
            .filter { $0.projectID == id }
            .compactMap { $0.startDateTime }
        let date = sessions.max()
        ProjectStatisticsCache.shared.setLastSessionDate(date, for: id)
        return date
    }
    
    // MARK: - Background Session Counting
    
    /// Update session statistics asynchronously in the background
    /// This is a static method to avoid mutating self on a let constant
    static func updateSessionStatistics(for project: Project) -> Project {
        Task {
            // Compute total duration and last session date in background
            let sessions = SessionManager.shared.allSessions
            let filteredSessions = sessions.filter { $0.projectID == project.id }
            let totalDuration = filteredSessions.reduce(0) { $0 + Double($1.durationMinutes) / 60.0 }
            let lastDate = filteredSessions.compactMap { $0.startDateTime }.max()
            
            // Update cached values on main thread
            await MainActor.run {
                // Since we can't mutate the struct directly, we'll rely on the computed properties
                // The caching will happen naturally when the properties are accessed
                NotificationCenter.default.post(name: .projectsDidChange, object: nil)
            }
        }
        
        // Return the project as-is since we can't mutate it directly
        return project
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, about, order, emoji, archived, phases
    }
    
    // Computed SwiftUI Color from hex string (avoids storing Color)
    var swiftUIColor: Color {
        Color(hex: color)
    }
    
    init(name: String, color: String = "#4E79A7", about: String? = nil, order: Int = 0, emoji: String = "📁", phases: [Phase] = []) {
        self.id = UUID().uuidString
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
    
    /// Add a new project with proper handling of phases and order
    func addProject(_ project: Project) {
        var projects = loadProjects()
        var newProject = project
        
        // Ensure the project has a proper ID
        if newProject.id.isEmpty {
            newProject.id = UUID().uuidString
        }
        
        // Set proper order (max order + 1)
        let maxOrder = projects.map(\.order).max() ?? 0
        newProject.order = maxOrder + 1
        
        projects.append(newProject)
        saveProjects(projects)
    }
    
    // MARK: - Project Name Migration Helper
    
    /// Migrate sessions from old project name to new project name when project is renamed
    /// This ensures that sessions continue to be associated with the correct project
    func migrateSessionProjectNames(oldName: String, newName: String, projectID: String) {
        let sessionManager = SessionManager.shared
        
        // Get all sessions that have the old project name
        let sessionsToUpdate = sessionManager.allSessions.filter { $0.projectName == oldName }
        
        if sessionsToUpdate.isEmpty {
            return
        }
        
        print("🔄 Updating \(sessionsToUpdate.count) sessions from project '\(oldName)' to '\(newName)'...")
        
        var updatedCount = 0
        
        // Update each session to use the new project name
        for session in sessionsToUpdate {
            let success = sessionManager.updateSessionFull(
                id: session.id,
                date: session.date,
                startTime: session.startTime,
                endTime: session.endTime,
                projectName: newName,
                notes: session.notes,
                mood: session.mood,
                activityTypeID: session.activityTypeID,
                projectPhaseID: session.projectPhaseID,
                milestoneText: session.milestoneText
            )
            
            if success {
                updatedCount += 1
            }
        }
        
        print("✅ Migrated \(updatedCount) sessions from project '\(oldName)' to '\(newName)' with ID \(projectID)")
        
        // Notify that projects have changed to refresh any cached data (on main thread)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .projectsDidChange, object: nil)
        }
    }
    
    /// Update a project and automatically migrate all associated sessions
    /// This ensures CSV files remain clean and human-readable
    func updateProject(_ project: Project, oldName: String? = nil) {
        var projects = loadProjects()
        guard let projectIndex = projects.firstIndex(where: { $0.id == project.id }) else {
            print("❌ Project \(project.id) not found for update")
            return
        }
        
        let oldProject = projects[projectIndex]
        let oldName = oldName ?? oldProject.name
        
        // Update the project
        projects[projectIndex] = project
        saveProjects(projects)
        
        // If the project name changed, migrate all associated sessions
        if oldName != project.name {
            print("📝 Project name changed from '\(oldName)' to '\(project.name)' - updating sessions...")
            migrateSessionProjectNames(oldName: oldName, newName: project.name, projectID: project.id)
        }
    }
    
    // MARK: - Background Session Counting
    
    /// Update session statistics for all projects in the background
    func updateAllProjectStatistics() {
        Task {
            let projects = loadProjects()
            
            // Process projects in batches to avoid overwhelming the system
            let batchSize = 10
            for batchStart in stride(from: 0, to: projects.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, projects.count)
                let batch = Array(projects[batchStart..<batchEnd])
                
                // Process each project in the batch concurrently
                await withTaskGroup(of: Void.self) { group in
                    for project in batch {
                        group.addTask {
                            // Just trigger the background computation by accessing the properties
                            // This will populate the cache automatically
                            _ = project.totalDurationHours
                            _ = project.lastSessionDate
                        }
                    }
                }
                
                // Small delay between batches to be nice to the system
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
    }
    
}
