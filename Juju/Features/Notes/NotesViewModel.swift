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
    @Published var milestoneText: String = ""
    
    // Project info (locked, pre-filled)
    var currentProjectID: String?
    var currentProjectName: String?
    
    // Available options
    @Published var activityTypes: [ActivityType] = []
    @Published var availablePhases: [Phase] = []
    @Published var projects: [Project] = []
    
    private var completion: ((String, Int?, String?, String?, String?) -> Void)?  // notes, mood, activityTypeID, projectPhaseID, milestoneText
    private var addPhaseCompletion: ((String) -> Void)?  // phase name
    
    // MARK: - Presentation Management
    
    func present(
        projectID: String?,
        projectName: String?,
        projects: [Project],
        completion: @escaping (String, Int?, String?, String?, String?) -> Void
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
        milestoneText = ""
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
        // For now, default to first activity type if available
        if selectedActivityTypeID == nil && !activityTypes.isEmpty {
            selectedActivityTypeID = activityTypes.first?.id
        }
        
        // Phase defaults to first phase if available
        if selectedProjectPhaseID == nil && !availablePhases.isEmpty {
            selectedProjectPhaseID = availablePhases.first?.id
        }
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
        completion?(notesText, mood, selectedActivityTypeID, selectedProjectPhaseID, milestoneText.isEmpty ? nil : milestoneText)
        dismiss()
    }
    
    func cancelNotes() {
        completion?("", nil, nil, nil, nil)
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
    }
    
    // MARK: - Validation
    
    var canSave: Bool {
        // Activity Type is required, notes are required
        selectedActivityTypeID != nil && !notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        return viewModel
    }
}
