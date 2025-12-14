//
// ROBUST_HANDLING_PLAN.md
// Juju Project Tracking App
//
// MARK: - ROBUST HANDLING IMPLEMENTATION PLAN
//
// This document outlines the implementation plan for adding robust data handling,
// validation, and error management to the Juju application.
//

# 🛡️ Robust Handling Implementation Plan

## 📋 Executive Summary

Your Juju app already has excellent data migration and caching infrastructure. This plan focuses on adding **robust data validation, relationship management, and error handling** to make the system even more reliable and user-friendly.

---

## 🎯 **Phase 1: Data Validation Layer (COMPLETED ✅)**

### **Status**: FULLY IMPLEMENTED
### **Timeline**: Completed
### **Impact**: Prevents data corruption, ensures data integrity

### **1.1 DataValidator Component**

**Purpose**: Centralized validation for all data operations

**IMPLEMENTED**:
✅ **DataValidator Singleton** (`Juju/Core/Managers/DataValidator.swift`)
- Session validation with time consistency checks
- Project validation with duplicate name detection
- Referential integrity validation
- Automatic repair for orphaned sessions
- Quick validation methods for common checks

**Integration Points**:
✅ SessionDataManager.saveAllSessions() - Validates before saving
✅ ProjectManager.saveProjects() - Validates before saving
✅ SessionManager.updateSessionFull() - Validates before updating

### **1.2 Relationship Validation**

**Purpose**: Ensure referential integrity between entities

**IMPLEMENTED**:
✅ **Relationship validation integrated into DataValidator**
- Check if projectID exists and is not archived
- Check if activityTypeID exists and is not archived
- Check if phaseID belongs to the correct project
- Find orphaned sessions (sessions with invalid project references)
- Find broken references in projects

### **1.3 Data Integrity Checks**

**Purpose**: Proactive detection of data issues

**IMPLEMENTED**:
✅ **Comprehensive integrity checking in DataValidator**
- Run integrity checks on all data
- Automatic repair for common issues
- Console logging of validation results
- Integration with all data persistence operations

---

## 🎯 **Phase 2: Enhanced Error Handling (COMPLETED ✅)**

### **Status**: FULLY IMPLEMENTED
### **Timeline**: Completed
### **Impact**: Better user experience, graceful error recovery

### **2.1 ErrorHandler Component**

**Purpose**: Centralized error handling and user notifications

**IMPLEMENTED**:
✅ **ErrorHandler Singleton** (`Juju/Core/Managers/ErrorHandler.swift`)
- Error severity levels (warning, error, fatal)
- User-friendly error messages with suggested actions
- Comprehensive error logging
- Retry mechanisms with exponential backoff
- Error context and severity classification

**Integration Points**:
✅ SessionDataManager - Handles file I/O errors
✅ ProjectManager - Handles JSON serialization errors
✅ DataValidator - Handles validation errors
✅ All async operations - Catches and handles errors gracefully

### **2.2 Graceful Degradation**

**Purpose**: App continues to function even when parts fail

**IMPLEMENTED**:
✅ **Graceful error handling in all managers**
- Validation errors don't crash the app
- Invalid data is skipped with user notification
- File I/O errors have fallback strategies
- Comprehensive error logging for debugging

---

## 🎯 **Phase 3: Advanced Caching Strategy (PENDING)**

### **Priority**: MEDIUM
### **Timeline**: Future implementation
### **Impact**: Better performance, reduced I/O, improved user experience

### **3.1 Unified Cache Manager**

**Purpose**: Centralized caching with proper invalidation

**Future Implementation**:
- Implement unified caching strategy
- Add cache warming for frequently accessed data
- Implement cache invalidation policies

### **3.2 Performance Optimizations**

**Purpose**: Optimize performance with large datasets

**Future Implementation**:
- Pagination for session lists
- Memory management for large datasets
- Advanced caching strategies
- Performance monitoring and analytics

### **Priority**: CRITICAL
### **Timeline**: 3-5 days
### **Impact**: Prevents data corruption, ensures data integrity

**Note**: Implementation details are now in the actual code files:
- `Juju/Core/Managers/DataValidator.swift` - Complete implementation
- `Juju/Core/Managers/ErrorHandler.swift` - Complete implementation

---

## 🎯 **Phase 2: Enhanced Error Handling (High - Week 2)**

### **Priority**: HIGH
### **Timeline**: 4-6 days
### **Impact**: Better user experience, graceful error recovery

### **2.1 ErrorHandler Component**

**Purpose**: Centralized error handling and user notifications

**Implementation**:
```swift
class ErrorHandler {
    static let shared = ErrorHandler()
    
    enum ErrorSeverity {
        case warning    // Non-critical, can continue
        case error      // Critical, may need user action
        case fatal      // App cannot continue
    }
    
    struct ErrorInfo {
        let error: Error
        let severity: ErrorSeverity
        let context: String
        let timestamp: Date
        let canRetry: Bool
        let suggestedAction: String?
    }
    
    // Handle errors with appropriate user feedback
    func handleError(_ error: Error, context: String, severity: ErrorSeverity = .error)
    
    // Show user-friendly error messages
    func showUserError(_ errorInfo: ErrorInfo)
    
    // Log errors for debugging
    func logError(_ errorInfo: ErrorInfo)
    
    // Retry failed operations
    func retryOperation(_ operation: @escaping () async throws -> Void)
}
```

**Integration Points**:
- SessionDataManager - Handle file I/O errors
- ProjectManager - Handle JSON serialization errors
- SessionMigrationManager - Handle migration failures
- All async operations - Catch and handle errors gracefully

### **2.2 Graceful Degradation**

**Purpose**: App continues to function even when parts fail

**Implementation**:
```swift
class GracefulDegradationManager {
    // Fallback strategies for common failures
    func handleFileReadError(for component: String) -> FallbackStrategy {
        // Return cached data
        // Return empty dataset
        // Return last known good state
    }
    
    // Handle migration failures gracefully
    func handleMigrationFailure(error: Error) -> Bool {
        // Preserve legacy data
        // Show user-friendly error
        // Allow manual retry
    }
}
```

---

## 🎯 **Phase 3: Advanced Caching Strategy (Medium - Week 3)**

### **Priority**: MEDIUM
### **Timeline**: 5-7 days
### **Impact**: Better performance, reduced I/O, improved user experience

### **3.1 Unified Cache Manager**

**Purpose**: Centralized caching with proper invalidation

**Implementation**:
```swiftif let cached = cachedProjects, 
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
                            // Compute statistics directly to avoid cache corruption
                            let sessionManager = SessionManager.shared
                            let filteredSessions = sessionManager.allSessions.filter { $0.projectID == project.id }
                            let totalDuration = filteredSessions.reduce(0) { $0 + Double($1.durationMinutes) / 60.0 }
                            let lastDate = filteredSessions.compactMap { $0.startDateTime }.max()
                            
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
