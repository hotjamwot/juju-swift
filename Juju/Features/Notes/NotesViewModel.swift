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
        activityTypes = ActivityTypeManager.shared.loadActivityTypes()
    }
    
    private func loadPhasesForProject() {
        guard let projectID = currentProjectID else {
            availablePhases = []
            return
        }
        
        if let project = projects.first(where: { $0.id == projectID }) {
            availablePhases = project.phases
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
    
    // MARK: - Actions
    
    func saveNotes() {
        completion?(notesText, mood, selectedActivityTypeID, selectedProjectPhaseID, milestoneText.isEmpty ? nil : milestoneText)
        dismiss()
    }
    
    func cancelNotes() {
        completion?("", nil, nil, nil, nil)
        dismiss()
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
