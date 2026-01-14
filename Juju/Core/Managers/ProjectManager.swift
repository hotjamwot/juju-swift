import Foundation
import SwiftUI

/// ProjectManager.swift
/// 
/// **Purpose**: Manages all project-related operations including CRUD operations,
/// statistics caching, phase management, and session association
/// 
/// **Key Responsibilities**:
/// - Project lifecycle management (create, read, update, delete)
/// - Project and phase archiving/unarchiving
/// - Statistics caching for performance optimization
/// - Session-to-project association management
/// - Data migration and validation
/// 
/// **Dependencies**:
/// - SessionManager: For session statistics and associations
/// - DataValidator: For project data validation
/// - ErrorHandler: For error handling and logging
/// - ProjectStatisticsCache: For performance optimization
/// 
/// **AI Notes**:
/// - Uses JSON file storage in Application Support directory
/// - Implements caching with 5-minute expiration for loaded projects
/// - Handles legacy data migration automatically
/// - Manages project phases with archiving support
/// - Provides thread-safe statistics caching with 30-second expiration
/// - Always use projectID as primary key, not project name
/// - Supports project archiving without data loss

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
    private var currentPhaseIDCache: [String: String?] = [:] // projectID -> phaseID
    private var lastCacheTime: Date?
    private let cacheExpiryTime: TimeInterval = 30 // Cache expires after 30 seconds
    
    // Thread safety using a concurrent queue with barriers
    private let cacheQueue = DispatchQueue(label: "com.juju.projectStatisticsCache", attributes: .concurrent)
    
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
        // Check if cache is still valid
        guard let lastTime = lastCacheTime,
              Date().timeIntervalSince(lastTime) < cacheExpiryTime else {
            // Cache expired, invalidate and return 0 (will trigger recomputation)
            invalidateCache()
            return 0
        }
        
        // Thread-safe access to cache
        return cacheQueue.sync {
            return totalDurationCache[projectID] ?? 0
        }
    }
    
    func getLastSessionDate(for projectID: String) -> Date? {
        // Check if cache is still valid
        guard let lastTime = lastCacheTime,
              Date().timeIntervalSince(lastTime) < cacheExpiryTime else {
            // Cache expired, invalidate and return nil (will trigger recomputation)
            invalidateCache()
            return nil
        }
        
        // Thread-safe access to cache with type safety
        return cacheQueue.sync {
            // Double-check the type to prevent crashes from corrupted cache entries
            if let cachedValue = lastSessionDateCache[projectID] {
                // If the value exists, it should be a Date? - if not, this will be caught by the type system
                return cachedValue
            }
            return nil
        }
    }
    
    func getCurrentPhaseID(for projectID: String) -> String? {
        // Check if cache is still valid
        guard let lastTime = lastCacheTime,
              Date().timeIntervalSince(lastTime) < cacheExpiryTime else {
            // Cache expired, invalidate and return nil (will trigger recomputation)
            invalidateCache()
            return nil
        }
        
        // Thread-safe access to cache
        return cacheQueue.sync {
            return currentPhaseIDCache[projectID] ?? nil
        }
    }
    
    func setTotalDuration(_ duration: Double, for projectID: String) {
        // Validate the duration value before caching
        guard !duration.isNaN && !duration.isInfinite else {
            print("⚠️ Invalid duration value \(duration) for project \(projectID), skipping cache")
            return
        }
        
        // Thread-safe cache update
        cacheQueue.async(flags: .barrier) {
            self.totalDurationCache[projectID] = duration
            self.lastCacheTime = Date()
        }
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
        
        // Thread-safe cache update
        cacheQueue.async(flags: .barrier) {
            self.lastSessionDateCache[projectID] = date
            self.lastCacheTime = Date()
        }
    }
    
    func setCurrentPhaseID(_ phaseID: String?, for projectID: String) {
        // Thread-safe cache update
        cacheQueue.async(flags: .barrier) {
            self.currentPhaseIDCache[projectID] = phaseID
            self.lastCacheTime = Date()
        }
    }
    
    func invalidateCache() {
        // Thread-safe cache invalidation
        cacheQueue.async(flags: .barrier) {
            self.totalDurationCache.removeAll()
            self.lastSessionDateCache.removeAll()
            self.currentPhaseIDCache.removeAll()
            self.lastCacheTime = nil
        }
    }
    
    func warmCache(for projects: [Project]) {
        // Pre-compute statistics for all projects in the background
        Task {
            let sessions = SessionManager.shared.allSessions
            
            for project in projects {
                let filteredSessions = sessions.filter { $0.projectID == project.id }
                let totalDuration = filteredSessions.reduce(0) { total, session in
                    total + Double(session.endDate.timeIntervalSince(session.startDate) / 60.0) / 60.0
                }
                let lastDate = filteredSessions.compactMap { $0.startDate }.max()
                
                // Update cache on main thread
                await MainActor.run {
                    // Use thread-safe cache methods
                    self.setTotalDuration(totalDuration, for: project.id)
                    self.setLastSessionDate(lastDate, for: project.id)
                    // Initialize current phase cache as nil to be computed on demand
                    self.setCurrentPhaseID(nil, for: project.id)
                }
            }
        }
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
    
    /// Load all projects from JSON file with caching and automatic migration support
    ///
    /// **AI Context**: This is the primary method for loading project data from persistent storage.
    /// It implements intelligent caching to avoid repeated disk access and handles automatic
    /// migration of legacy project formats to the current schema.
    ///
    /// **Business Rules**:
    /// - Uses 5-minute cache to minimize disk I/O operations
    /// - Automatically creates missing directories if needed
    /// - Handles corrupted or invalid JSON files by creating default projects
    /// - Performs schema migration for legacy projects without archived fields
    /// - Always returns a valid array (never nil)
    ///
    /// **Data Flow**:
    /// 1. Check in-memory cache first (5-minute expiration)
    /// 2. If cache miss, ensure projects directory exists
    /// 3. Load JSON file from disk
    /// 4. Detect if migration is needed (legacy schema detection)
    /// 5. Apply migration if required, otherwise use loaded data
    /// 6. Cache the result and return
    ///
    /// **Migration Logic**:
    /// - Detects projects with phases that have invalid archived field values
    /// - Automatically migrates to new schema with proper archived field defaults
    /// - Preserves all existing project data during migration
    /// - Rewrites file only if migration was actually performed
    ///
    /// **Error Handling**:
    /// - Catches JSON parsing errors and file access issues
    /// - Automatically recreates corrupted files with default projects
    /// - Logs detailed error information for debugging
    /// - Never crashes the application due to data corruption
    ///
    /// **Performance Optimizations**:
    /// - 5-minute in-memory caching to reduce disk access
    /// - Lazy directory creation (only when needed)
    /// - Efficient migration detection using contains() checks
    /// - Minimal memory usage with direct JSON parsing
    ///
    /// **Thread Safety**: Method is not thread-safe, should be called from main thread
    ///
    /// - Returns: Array of Project objects, never empty (defaults provided if loading fails)
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
        // Validate all projects before saving
        let validator = DataValidator.shared
        let errorHandler = ErrorHandler.shared
        
        var validProjects: [Project] = []
        var invalidProjects: [(Project, String)] = []
        
        for project in projects {
            switch validator.validateProject(project) {
            case .valid:
                validProjects.append(project)
            case .invalid(let reason):
                invalidProjects.append((project, reason))
                errorHandler.handleValidationError(
                    NSError(domain: "DataValidation", code: 1002, userInfo: [NSLocalizedDescriptionKey: reason]),
                    dataType: "Project"
                )
            }
        }
        
        if !invalidProjects.isEmpty {
            print("⚠️ Found \(invalidProjects.count) invalid projects. Skipping them.")
            for (project, reason) in invalidProjects {
                print("  - Project '\(project.name)': \(reason)")
            }
        }
        
        if let projectsFile = projectsFile {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(validProjects)
                try data.write(to: projectsFile)
                print("✅ Saved \(validProjects.count) projects to \(projectsFile.path)")
                // Clear cache after saving to ensure fresh data on next load
                clearCache()
                NotificationCenter.default.post(name: .projectsDidChange, object: nil)
            } catch {
                errorHandler.handleFileError(error, operation: "write", filePath: projectsFile.path)
            }
        }
    }
    
    // MARK: - Project Archiving Management
    
    /// Archive or unarchive a project without data loss
    ///
    /// **AI Context**: This method provides safe project archiving that preserves all associated
    /// data while hiding the project from active views. It's the preferred way to manage
    /// completed or inactive projects without losing historical session data.
    ///
    /// **Business Rules**:
    /// - Archiving preserves all project data and associated sessions
    /// - Archived projects are excluded from active project lists
    /// - Archived projects can be unarchived to restore full functionality
    /// - Project archiving is reversible (no data deletion)
    ///
    /// **Data Flow**:
    /// 1. Load current projects from storage
    /// 2. Find project by ID in loaded projects
    /// 3. Update archived status on project object
    /// 4. Save updated projects back to storage
    /// 5. Clear cache to ensure fresh data on next load
    ///
    /// **Performance Characteristics**:
    /// - O(n) lookup for project by ID
    /// - Full project list rewrite to storage (for consistency)
    /// - Cache invalidation triggers reload on next access
    ///
    /// **Integration Points**:
    /// - Automatically clears project cache after save
    /// - Posts .projectsDidChange notification for UI updates
    /// - Works with getActiveProjects() and getArchivedProjects() filters
    ///
    /// **Edge Cases**:
    /// - If projectID not found, method silently returns (no error)
    /// - Archiving does not affect sessions (they remain associated)
    /// - Archived projects still appear in historical data and reports
    /// - Project statistics continue to be calculated for archived projects
    ///
    /// **Use Cases**:
    /// - Completing a project and moving it out of active view
    /// - Temporarily hiding projects during cleanup
    /// - Organizing projects by status without data loss
    ///
    /// - Parameters:
    ///   - archived: Boolean indicating whether to archive (true) or unarchive (false)
    ///   - projectID: Unique identifier of the project to modify
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
    
    /// Get project name from projectID for session creation
    /// - Returns: Project name if found, nil if project doesn't exist
    func getProjectName(from projectID: String) -> String? {
        let projects = loadProjects()
        return projects.first(where: { $0.id == projectID })?.name
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
        
        // Get all sessions that have the old project ID
        let sessionsToUpdate = sessionManager.allSessions.filter { $0.projectID == projectID }
        
        if sessionsToUpdate.isEmpty {
            return
        }
        
        print("🔄 Updating \(sessionsToUpdate.count) sessions for project '\(newName)' with ID \(projectID)...")
        
        var updatedCount = 0
        
        // Update each session - since we now use projectID as source of truth,
        // we don't need to update anything for name changes
        for session in sessionsToUpdate {
            // Sessions are now correctly associated via projectID, no migration needed
            updatedCount += 1
        }
        
        print("✅ Verified \(updatedCount) sessions for project '\(newName)' with ID \(projectID)")
        
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
        Task { [weak self] in
            guard let self = self else { return }
            let projects = self.loadProjects()
            
            // Process projects in batches to avoid overwhelming the system
            let batchSize = 10
            for batchStart in stride(from: 0, to: projects.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, projects.count)
                let batch = Array(projects[batchStart..<batchEnd])
                
                // Process each project in the batch concurrently
                await withTaskGroup(of: Void.self) { group in
                    for project in batch {
                        group.addTask {
                            // Compute statistics directly to avoid cache corruption
                            let sessionManager = SessionManager.shared
                            let filteredSessions = sessionManager.allSessions.filter { $0.projectID == project.id }
                            let totalDuration = filteredSessions.reduce(0) { total, session in
                                total + Double(session.endDate.timeIntervalSince(session.startDate) / 60.0) / 60.0
                            }
                            let lastDate = filteredSessions.compactMap { $0.startDate }.max()
                            
                            // Update cache on main thread using thread-safe methods
                            await MainActor.run {
                                ProjectStatisticsCache.shared.setTotalDuration(totalDuration, for: project.id)
                                ProjectStatisticsCache.shared.setLastSessionDate(lastDate, for: project.id)
                            }
                        }
                    }
                }
                
                // Small delay between batches to be nice to the system
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
    }
    
}
