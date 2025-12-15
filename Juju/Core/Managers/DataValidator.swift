//
// DataValidator.swift
// Juju Project Tracking App
//
// MARK: - DATA VALIDATION SYSTEM
//
// Centralized validation for all data operations to prevent data corruption
// and ensure referential integrity across the application.
//

import Foundation

// MARK: - DataValidator Singleton
class DataValidator {
    static let shared = DataValidator()
    
    private init() {}
    
    // MARK: - Validation Result Types
    
    enum ValidationResult {
        case valid
        case invalid(reason: String)
        
        var isValid: Bool {
            switch self {
            case .valid: return true
            case .invalid: return false
            }
        }
    }
    
    enum ErrorSeverity {
        case warning    // Non-critical, can continue
        case error      // Critical, may need user action
        case fatal      // App cannot continue
    }
    
    // MARK: - Session Validation
    
    /// Validate a session record before persistence
    /// - Parameter session: The session to validate
    /// - Returns: ValidationResult indicating if the session is valid
    func validateSession(_ session: SessionRecord) -> ValidationResult {
        // Check required fields
        guard !session.id.isEmpty else {
            return .invalid(reason: "Session ID cannot be empty")
        }
        
        guard session.startDateTime != nil else {
            return .invalid(reason: "Session start time is required")
        }
        
        guard session.endDateTime != nil else {
            return .invalid(reason: "Session end time is required")
        }
        
        // Validate time consistency
        if let start = session.startDateTime, let end = session.endDateTime {
            guard end >= start else {
                return .invalid(reason: "Session end time must be after start time")
            }
        }
        
        // Validate project reference (if provided)
        if let projectID = session.projectID, !projectID.isEmpty {
            let projectManager = ProjectManager.shared
            let projects = projectManager.loadProjects()
            
            guard projects.contains(where: { $0.id == projectID && !$0.archived }) else {
                return .invalid(reason: "Session references non-existent or archived project: \(projectID)")
            }
            
            // If projectPhaseID is provided, validate it belongs to the project
            if let phaseID = session.projectPhaseID, !phaseID.isEmpty {
                guard let project = projects.first(where: { $0.id == projectID }) else {
                    return .invalid(reason: "Could not find project for phase validation")
                }
                
                let activePhases = project.phases.filter { !$0.archived }
                guard activePhases.contains(where: { $0.id == phaseID }) else {
                    return .invalid(reason: "Session references phase that doesn't belong to project: \(phaseID)")
                }
            }
        }
        
        // Validate activity type reference (if provided)
        if let activityTypeID = session.activityTypeID, !activityTypeID.isEmpty {
            let activityTypes = ActivityTypeManager.shared.loadActivityTypes()
            guard activityTypes.contains(where: { $0.id == activityTypeID && !$0.archived }) else {
                return .invalid(reason: "Session references non-existent or archived activity type: \(activityTypeID)")
            }
        }
        
        return .valid
    }
    
    // MARK: - Project Validation
    
    /// Validate a project before persistence
    /// - Parameter project: The project to validate
    /// - Returns: ValidationResult indicating if the project is valid
    func validateProject(_ project: Project) -> ValidationResult {
        // Check required fields
        guard !project.id.isEmpty else {
            return .invalid(reason: "Project ID cannot be empty")
        }
        
        guard !project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid(reason: "Project name cannot be empty")
        }
        
        guard !project.color.isEmpty else {
            return .invalid(reason: "Project color cannot be empty")
        }
        
        // Validate color format (should be hex color)
        guard project.color.hasPrefix("#") && project.color.count == 7 else {
            return .invalid(reason: "Project color must be a valid hex color (e.g., #FF0000)")
        }
        
        // Check for duplicate project names (case insensitive)
        let projectManager = ProjectManager.shared
        let existingProjects = projectManager.loadProjects()
        
        let existingProject = existingProjects.first { existingProject in
            existingProject.id != project.id && // Don't compare with itself
            existingProject.name.lowercased() == project.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let duplicateProject = existingProject {
            return .invalid(reason: "A project with the name '\(project.name)' already exists (ID: \(duplicateProject.id))")
        }
        
        // Validate phases
        for phase in project.phases {
            guard !phase.id.isEmpty else {
                return .invalid(reason: "Phase ID cannot be empty")
            }
            
            guard !phase.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .invalid(reason: "Phase name cannot be empty")
            }
            
            // Check for duplicate phase names within the project
            let duplicatePhase = project.phases.first { otherPhase in
                otherPhase.id != phase.id &&
                otherPhase.name.lowercased() == phase.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            if duplicatePhase != nil {
                return .invalid(reason: "Duplicate phase name within project: '\(phase.name)'")
            }
        }
        
        return .valid
    }
    
    // MARK: - Referential Integrity Validation
    
    /// Validate referential integrity across all data
    /// - Returns: ValidationResult indicating if data integrity is maintained
    func validateReferentialIntegrity() -> ValidationResult {
        let projectManager = ProjectManager.shared
        let sessionManager = SessionManager.shared
        let activityTypes = ActivityTypeManager.shared.loadActivityTypes()
        
        let projects = projectManager.loadProjects()
        let sessions = sessionManager.allSessions
        
        // Check for orphaned sessions (sessions with invalid project references)
        let orphanedSessions = sessions.filter { session in
            if let projectID = session.projectID, !projectID.isEmpty {
                return !projects.contains { $0.id == projectID }
            }
            return false // Sessions without projectID are legacy and allowed
        }
        
        if !orphanedSessions.isEmpty {
            let sessionIDs = orphanedSessions.map { $0.id }.joined(separator: ", ")
            return .invalid(reason: "Found \(orphanedSessions.count) sessions with invalid project references: \(sessionIDs)")
        }
        
        // Check for sessions with invalid activity type references
        let invalidActivityTypeSessions = sessions.filter { session in
            if let activityTypeID = session.activityTypeID, !activityTypeID.isEmpty {
                return !activityTypes.contains { $0.id == activityTypeID }
            }
            return false
        }
        
        if !invalidActivityTypeSessions.isEmpty {
            let sessionIDs = invalidActivityTypeSessions.map { $0.id }.joined(separator: ", ")
            return .invalid(reason: "Found \(invalidActivityTypeSessions.count) sessions with invalid activity type references: \(sessionIDs)")
        }
        
        // Check for phases that have duplicate names within the same project (already validated above)
        // No additional validation needed here since phases are contained within projects
        
        return .valid
    }
    
    // MARK: - Data Integrity Check
    
    /// Run comprehensive data integrity check
    /// - Returns: Array of validation errors found
    func runIntegrityCheck() -> [String] {
        var errors: [String] = []
        
        // Validate all projects
        let projectManager = ProjectManager.shared
        let projects = projectManager.loadProjects()
        
        for project in projects {
            if case .invalid(let reason) = validateProject(project) {
                errors.append("Project \(project.id) '\(project.name)': \(reason)")
            }
        }
        
        // Validate all sessions
        let sessionManager = SessionManager.shared
        let sessions = sessionManager.allSessions
        
        for session in sessions {
            if case .invalid(let reason) = validateSession(session) {
                errors.append("Session \(session.id): \(reason)")
            }
        }
        
        // Check referential integrity
        if case .invalid(let reason) = validateReferentialIntegrity() {
            errors.append("Referential integrity: \(reason)")
        }
        
        return errors
    }
    
    // MARK: - Automatic Repair
    
    /// Attempt to automatically repair common data issues
    /// - Returns: Array of repair actions taken
    func autoRepairIssues() -> [String] {
        var repairs: [String] = []
        
        // Check if we need to run project ID migration
        let sessionManager = SessionManager.shared
        let sessionsWithoutProjectID = sessionManager.allSessions.filter { $0.projectID == nil }
        
        if !sessionsWithoutProjectID.isEmpty {
            print("🔄 Found \(sessionsWithoutProjectID.count) sessions without projectID - triggering migration")
            
            // Import SessionMigrationManager to access migration functionality
            // We need to access the jujuPath from SessionManager
            // Since SessionManager is a singleton, we can access it directly
            guard let jujuPath = sessionManager.jujuPathForMigration else {
                print("❌ Could not access jujuPath for migration")
                return repairs
            }
            
            let sessionFileManager = SessionFileManager()
            let migrationManager = SessionMigrationManager(sessionFileManager: sessionFileManager, jujuPath: jujuPath)
            
            // Run project ID migration
            Task {
                await migrationManager.migrateSessionProjectIDs()
                print("✅ Project ID migration completed")
            }
            
            repairs.append("Triggered project ID migration for \(sessionsWithoutProjectID.count) sessions")
        }
        
        // Find sessions with invalid project references
        let projectManager = ProjectManager.shared
        let projects = projectManager.loadProjects()
        
        let sessionsToUpdate = sessionManager.allSessions.filter { session in
            if let projectID = session.projectID, !projectID.isEmpty {
                return !projects.contains { $0.id == projectID }
            }
            return false
        }
        
        // Create projects for orphaned sessions
        for session in sessionsToUpdate {
            guard !session.projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            
            // Check if project already exists with this name
            if let existingProject = projects.first(where: { $0.name.lowercased() == session.projectName.lowercased() }) {
                // Update session to use existing project
                let success = sessionManager.updateSession(id: session.id, field: "project_id", value: existingProject.id)
                if success {
                    repairs.append("Updated session \(session.id) to use existing project '\(session.projectName)' (ID: \(existingProject.id))")
                }
            } else {
                // Create new project for the session
                let newProject = Project(
                    name: session.projectName,
                    color: "#808080", // Grey color for auto-created projects
                    about: "Auto-created from session data",
                    order: 0,
                    emoji: "📁",
                    phases: []
                )
                
                projectManager.addProject(newProject)
                
                // Update session to use new project
                let success = sessionManager.updateSession(id: session.id, field: "project_id", value: newProject.id)
                if success {
                    repairs.append("Created new project '\(session.projectName)' (ID: \(newProject.id)) and updated session \(session.id)")
                }
            }
        }
        
        return repairs
    }
    
    // MARK: - Quick Validation Methods
    
    /// Quick check if a project ID is valid
    /// - Parameter projectID: The project ID to check
    /// - Returns: True if the project ID is valid and not archived
    func isValidProjectID(_ projectID: String?) -> Bool {
        guard let projectID = projectID, !projectID.isEmpty else {
            return false
        }
        
        let projectManager = ProjectManager.shared
        let projects = projectManager.loadProjects()
        return projects.contains { $0.id == projectID && !$0.archived }
    }
    
    /// Quick check if an activity type ID is valid
    /// - Parameter activityTypeID: The activity type ID to check
    /// - Returns: True if the activity type ID is valid and not archived
    func isValidActivityTypeID(_ activityTypeID: String?) -> Bool {
        guard let activityTypeID = activityTypeID, !activityTypeID.isEmpty else {
            return false
        }
        
        let activityTypes = ActivityTypeManager.shared.loadActivityTypes()
        return activityTypes.contains { $0.id == activityTypeID && !$0.archived }
    }
    
    /// Quick check if a phase ID belongs to a project
    /// - Parameters:
    ///   - phaseID: The phase ID to check
    ///   - projectID: The project ID to validate against
    /// - Returns: True if the phase belongs to the project and is not archived
    func isValidPhaseForProject(_ phaseID: String?, projectID: String?) -> Bool {
        guard let phaseID = phaseID, !phaseID.isEmpty,
              let projectID = projectID, !projectID.isEmpty else {
            return false
        }
        
        let projectManager = ProjectManager.shared
        let projects = projectManager.loadProjects()
        
        guard let project = projects.first(where: { $0.id == projectID }) else {
            return false
        }
        
        let activePhases = project.phases.filter { !$0.archived }
        return activePhases.contains { $0.id == phaseID }
    }
}
