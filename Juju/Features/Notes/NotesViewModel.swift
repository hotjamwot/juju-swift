import SwiftUI
import Foundation

@MainActor
class NotesViewModel: ObservableObject {
    @Published var notesText: String = ""
    @Published var isPresented: Bool = false
    @Published var mood: Int? = nil
    
    private var completion: ((String, Int?) -> Void)?
    
    // MARK: - Presentation Management
    
    func present(completion: @escaping (String, Int?) -> Void) {
        self.completion = completion
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
    }
    
    // MARK: - Actions
    
    func saveNotes() {
        completion?(notesText, mood)
        dismiss()
    }
    
    func cancelNotes() {
        completion?("", nil)
        dismiss()
    }
    
    // MARK: - Validation
    
    var canSave: Bool {
        !notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
