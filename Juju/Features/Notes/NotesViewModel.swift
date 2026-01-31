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

    // Focus request flag to tell the view to focus the action text field without modifying content
    @Published var shouldFocusActionField: Bool = false

    func requestActionFieldFocus() {
        shouldFocusActionField = true
    }
    
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
    
    private var completion: ((String, Int?, String?, String?, String, Bool) -> Void)?  // notes, mood, activityTypeID, projectPhaseID, action, isMilestone
    private var addPhaseCompletion: ((String) -> Void)?  // phase name
    
    // MARK: - Presentation Management
    
    /// Prepare the view model for a particular project without showing the modal.
    /// This centralizes the logic needed by both the present flow and the existing-window update flow.
    func prepareForPresentation(projectID: String?, projectName: String?, projects: [Project]) {
        self.currentProjectID = projectID
        self.currentProjectName = projectName
        self.projects = projects

        // Clear any previous activity/phase selection so smart defaults for the
        // current project (based on the last recorded session) can be applied.
        selectedActivityTypeID = nil
        selectedProjectPhaseID = nil

        loadActivityTypes()
        loadPhasesForProject()

        // Minimal structured debug: record presentation context
        ErrorHandler.shared.logDebug("prepareForPresentation", context: "NotesViewModel", data: ["projectID": projectID ?? "nil", "projectName": projectName ?? "nil", "activityTypes": activityTypes.map { $0.id }])

        setSmartDefaults()

        // If sessions haven't been loaded yet, load them asynchronously and re-run smart defaults
        if SessionManager.shared.allSessions.isEmpty {
            print("[NotesViewModel] allSessions empty, loading sessions to attempt smart defaults")
            Task { @MainActor in
                _ = await SessionManager.shared.loadAllSessions()
                print("[NotesViewModel] sessions loaded, re-running setSmartDefaults")
                self.setSmartDefaults()
            }
        }
    }

    func present(
        projectID: String?,
        projectName: String?,
        projects: [Project],
        completion: @escaping (String, Int?, String?, String?, String, Bool) -> Void
    ) {
        // Set completion first
        self.completion = completion

        // Prepare the view model for the provided project
        prepareForPresentation(projectID: projectID, projectName: projectName, projects: projects)

        // Reset ephemeral content (notes, mood, action, milestone)
        resetContent()

        // Show the modal
        isPresented = true
    }
    
    func dismiss() {
        isPresented = false
    }
    
    func updateCompletion(_ newCompletion: @escaping (String, Int?, String?, String?, String, Bool) -> Void) {
        self.completion = newCompletion
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
    
    func loadActivityTypes() {
        activityTypes = ActivityTypeManager.shared.getActiveActivityTypes()
    }
    
    func loadPhasesForProject() {
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
    
    func setSmartDefaults() {
        // Set smart defaults based on last session with the same project ID
        if let lastSessionForProject = getLastSessionForCurrentProject() {
            // Minimal structured debug: last session info for this project
            ErrorHandler.shared.logDebug("Last session found", context: "NotesViewModel", data: ["sessionID": lastSessionForProject.id, "activityType": lastSessionForProject.activityTypeID ?? "nil", "phase": lastSessionForProject.projectPhaseID ?? "nil"])

            // Use the activity type from the last session if it's valid
            if let candidate = lastSessionForProject.activityTypeID {
                let resolved = ActivityTypeManager.shared.getActivityType(id: candidate)
                let isActive = resolved != nil && resolved!.archived == false
                ErrorHandler.shared.logDebug("Candidate activity type", context: "NotesViewModel", data: ["candidate": candidate, "resolved": resolved != nil, "active": isActive])
                if isActive {
                    // Only override an existing selection if it is empty or it is the fallback (first type)
                    let currentSelection = selectedActivityTypeID
                    let fallbackID = activityTypes.first?.id
                    if currentSelection == nil || currentSelection == fallbackID {
                        ErrorHandler.shared.logStateChange("selectedActivityTypeID", fromValue: currentSelection, toValue: candidate, context: "Applied smart default (overrode fallback)")
                        selectedActivityTypeID = candidate
                    } else {
                        ErrorHandler.shared.logDebug("Not overriding existing activity selection", context: "NotesViewModel", data: ["currentSelection": currentSelection ?? "nil", "candidate": candidate])
                    }
                } else if resolved != nil {
                    ErrorHandler.shared.logDebug("Candidate activity type archived", context: "NotesViewModel", data: ["candidate": candidate])
                } else {
                    ErrorHandler.shared.logDebug("Candidate activity type not found", context: "NotesViewModel", data: ["candidate": candidate])
                }
            }
            
            // Use the phase from the last session
            if selectedProjectPhaseID == nil && lastSessionForProject.projectPhaseID != nil {
                selectedProjectPhaseID = lastSessionForProject.projectPhaseID
            }
        }
        
        // Fallback: If no last session or missing values, use defaults
        if selectedActivityTypeID == nil {
            if !activityTypes.isEmpty {
                let fallbackID = activityTypes.first?.id
                ErrorHandler.shared.logStateChange("selectedActivityTypeID", fromValue: nil, toValue: fallbackID, context: "Fallback to first activity type")
                selectedActivityTypeID = fallbackID
            } else {
                ErrorHandler.shared.logDebug("No activity types available to fall back to", context: "NotesViewModel")
            }
        } else {
            ErrorHandler.shared.logDebug("Final selectedActivityTypeID", context: "NotesViewModel", data: selectedActivityTypeID ?? "nil")
        }
        
        // Phase defaults to first phase if available
        if selectedProjectPhaseID == nil && !availablePhases.isEmpty {
            selectedProjectPhaseID = availablePhases.first?.id
        }
    }
    
    /// Get the most recent session for the current project
    ///
    /// Prefer the most recent session that has a valid activityTypeID so we don't
    /// inherit an "uncategorized" (nil) activity type when a later session exists
    /// without an activityType.
    private func getLastSessionForCurrentProject() -> SessionRecord? {
        guard let projectID = currentProjectID else { return nil }

        // Find sessions for this project and sort by start date (newest first)
        let sessionsForProject = SessionManager.shared.allSessions
            .filter { $0.projectID == projectID }
            .sorted { $0.startDate > $1.startDate }

        // Prefer the most recent session that has a non-nil, valid activity type
        for session in sessionsForProject {
            if let activityID = session.activityTypeID,
               ActivityTypeManager.shared.getActivityType(id: activityID) != nil {
                return session
            }
        }

        // Fallback: return the most recent session even if it lacks an activity type
        return sessionsForProject.first
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
        // Only call completion handler on explicit Save
        completion?(notesText, mood, selectedActivityTypeID, selectedProjectPhaseID, action, isMilestone)
        dismiss()
    }
    
    func cancelNotes() {
        // Pass empty data so MenuManager knows to keep session active
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
