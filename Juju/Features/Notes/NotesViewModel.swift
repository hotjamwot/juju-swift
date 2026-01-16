import SwiftUI
import Foundation

@MainActor
class NotesViewModel: ObservableObject {
    @Published var notesText: String = ""
    @Published var isPresented: Bool = false
    @Published var mood: Int? = nil
    
    // New fields for Activity Type and Phase
    @Published var selectedActivityTypeID: String? = nil
    @Published var selectedProjectPhaseID: String? = nil
    
    // New fields for Action and Milestone
    @Published var action: String = ""
    @Published var isMilestone: Bool = false
    
    // Project info (locked, pre-filled)
    var currentProjectID: String?
    var currentProjectName: String?
    
    // Available options
    @Published var activityTypes: [ActivityType] = []
    @Published var availablePhases: [Phase] = []
    @Published var projects: [Project] = []
    
    // Most used activity types (computed property)
    var mostUsedActivityTypes: [ActivityType] {
        // Get recent sessions for activity type frequency calculation
        let recentSessions = SessionManager.shared.allSessions.prefix(50)
        
        // Count activity type usage
        var activityTypeCounts: [String: Int] = [:]
        for session in recentSessions {
            if let activityTypeID = session.activityTypeID {
                activityTypeCounts[activityTypeID, default: 0] += 1
            }
        }
        
        // Get active activity types and sort by usage frequency (most used first), then by name
        let activeActivityTypes = ActivityTypeManager.shared.getActiveActivityTypes()
        let sortedActivityTypes = activeActivityTypes.sorted { activityType1, activityType2 in
            let count1 = activityTypeCounts[activityType1.id] ?? 0
            let count2 = activityTypeCounts[activityType2.id] ?? 0
            
            // Sort by count first (descending), then by name (ascending)
            if count1 != count2 {
                return count1 > count2
            }
            return activityType1.name < activityType2.name
        }
        
        return sortedActivityTypes
    }
    
    /// Get the most recent activity type used for the current project
    private var mostRecentActivityTypeForProject: ActivityType? {
        guard let projectID = currentProjectID else { return nil }
        
        // Find the most recent session for this project
        let recentSessions = SessionManager.shared.allSessions
            .filter { $0.projectID == projectID }
            .sorted { $0.startDate > $1.startDate }
        
        guard let mostRecentSession = recentSessions.first,
              let activityTypeID = mostRecentSession.activityTypeID else {
            return nil
        }
        
        // Find the activity type by ID
        return ActivityTypeManager.shared.getActiveActivityTypes()
            .first { $0.id == activityTypeID }
    }
    
    private var completion: ((String, Int?, String?, String?, String, Bool) -> Void)?  // notes, mood, activityTypeID, projectPhaseID, action, isMilestone
    private var addPhaseCompletion: ((String) -> Void)?  // phase name
    
    // MARK: - Presentation Management
    
    func present(
        projectID: String?,
        projectName: String?,
        projects: [Project],
        completion: @escaping (String, Int?, String?, String?, String, Bool) -> Void
    ) {
        self.currentProjectID = projectID
        self.currentProjectName = projectName
        self.projects = projects
        self.completion = completion
        loadActivityTypes()
        loadPhasesForProject()
        setSmartDefaults()
        resetContent()
        isPresented = true
    }
    
    func dismiss() {
        isPresented = false
    }
    
    // MARK: - Content Management
    
    func resetContent() {
        notesText = ""
        mood = nil
        action = ""
        isMilestone = false
        // Don't reset activityTypeID and projectPhaseID - they may have smart defaults
    }
    
    // MARK: - Data Loading
    
    private func loadActivityTypes() {
        activityTypes = ActivityTypeManager.shared.getActiveActivityTypes()
    }
    
    private func loadPhasesForProject() {
        guard let projectID = currentProjectID else {
            availablePhases = []
            return
        }
        
        if let project = projects.first(where: { $0.id == projectID }) {
            // Filter out archived phases
            availablePhases = project.phases.filter { !$0.archived }
        } else {
            availablePhases = []
        }
    }
    
    // MARK: - Smart Defaults
    
    private func setSmartDefaults() {
        // Set smart defaults based on last used for this project
        // First, try to use the most recent activity type for this project
        if selectedActivityTypeID == nil {
            if let mostRecentActivityType = mostRecentActivityTypeForProject {
                selectedActivityTypeID = mostRecentActivityType.id
            } else if !activityTypes.isEmpty {
                // Fall back to first activity type if no recent history
                selectedActivityTypeID = activityTypes.first?.id
            }
        }
        
        // Phase defaults to first phase if available
        if selectedProjectPhaseID == nil && !availablePhases.isEmpty {
            selectedProjectPhaseID = availablePhases.first?.id
        }
        
        // TODO: Set smart defaults for action and isMilestone if historical data exists
        // For now, they start empty/False
    }
    
    // MARK: - Phase Management
    
    func updateSelectedProject(_ projectID: String?) {
        currentProjectID = projectID
        loadPhasesForProject()
        // Reset phase selection when project changes
        selectedProjectPhaseID = availablePhases.first?.id
    }
    
    // MARK: - Phase Selection Validation
    
    /// Validate that the selected phase is still valid for the current project
    func validatePhaseSelection() {
        guard let projectID = currentProjectID,
              let phaseID = selectedProjectPhaseID else {
            return
        }
        
        // Check if the selected phase exists in the current project
        if let project = projects.first(where: { $0.id == projectID }),
           let phase = project.phases.first(where: { $0.id == phaseID && !$0.archived }) {
            // Phase is valid, keep selection
            return
        }
        
        // Phase is invalid, clear selection
        selectedProjectPhaseID = nil
    }
    
    // MARK: - Actions
    
    func saveNotes() {
        // Pass the new action and isMilestone to the completion handler
        completion?(notesText, mood, selectedActivityTypeID, selectedProjectPhaseID, action, isMilestone)
        dismiss()
    }
    
    func cancelNotes() {
        // Pass nil/default for the new fields
        completion?("", nil, nil, nil, "", false)
        dismiss()
    }
    
    // MARK: - Phase Creation
    
    func addPhase(name: String) {
        guard let projectID = currentProjectID else { return }
        
        // Create new phase with proper order
        let newPhase = Phase(name: name, order: availablePhases.count, archived: false)
        
        // Add to project via ProjectManager
        ProjectManager.shared.addPhase(to: projectID, phase: newPhase)
        
        // Refresh the projects array to include the new phase
        projects = ProjectManager.shared.loadProjects()
        
        // Refresh phases list
        loadPhasesForProject()
        
        // Set the new phase as selected
        selectedProjectPhaseID = newPhase.id
        
        // Validate the selection to ensure it's still valid
        validatePhaseSelection()
        
        // Post notification to refresh projects data in other views
        NotificationCenter.default.post(name: .projectsDidChange, object: nil)
    }
    
    // MARK: - Validation
    
    var canSave: Bool {
        // Activity Type is required, notes are required, action is required
        selectedActivityTypeID != nil && !notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Keyboard Shortcuts
    
    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let characters = event.characters else { return false }
        
        // Handle ⌘+Enter to save
        if event.modifierFlags.contains(.command) && characters == "\r" {
            if canSave {
                saveNotes()
            }
            return true
        }
        
        // Handle Escape to cancel
        if characters == "\u{1b}" {
            cancelNotes()
            return true
        }
        
        return false
    }
}

// MARK: - Preview Helper

extension NotesViewModel {
    static var preview: NotesViewModel {
        let viewModel = NotesViewModel()
        viewModel.notesText = "Sample notes for preview"
        viewModel.action = "Sample action for preview" // Add a sample action for preview
        return viewModel
    }
}
