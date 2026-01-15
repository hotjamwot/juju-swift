import SwiftUI
import AppKit

@MainActor
class NotesManager: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = NotesManager()
    
    @Published private(set) var isPresented = false
    private var notesViewModel = NotesViewModel()
    private var hostingWindow: NSWindow?
    
    // currentAction and currentIsMilestone are no longer needed
    // as NotesModalView directly binds to NotesViewModel's properties.
    
    override private init() {}
    
    // MARK: - Presentation Methods
    
    func presentNotes(
        projectID: String?,
        projectName: String?,
        projects: [Project],
        completion: @escaping (String, Int?, String?, String?, String?, String, Bool) -> Void // Added action, isMilestone
    ) {
        // Ensure we're on main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.presentNotes(projectID: projectID, projectName: projectName, projects: projects, completion: completion)
            }
            return
        }
        
        // Activate the app to bring it to front
        NSApp.activate(ignoringOtherApps: true)
        
        // Create and configure the hosting window
        createHostingWindow(projectID: projectID, projectName: projectName, projects: projects, completion: completion)
        
        isPresented = true
    }
    
    private func createHostingWindow(
        projectID: String?,
        projectName: String?,
        projects: [Project],
        completion: @escaping (String, Int?, String?, String?, String?, String, Bool) -> Void
    ) {
        // Clean up existing window if any
        if let existingWindow = hostingWindow {
            existingWindow.close()
            hostingWindow = nil
        }
        
        // Create the SwiftUI view
        // NotesModalView now directly binds its UI to the notesViewModel's properties.
        let notesView = NotesModalView(viewModel: notesViewModel)
        
        // Create hosting controller
        let hostingController = NSHostingController(rootView: notesView)
        
        // Create window
        let windowSize = NSSize(width: 750, height: 450) // Adjusted height for new fields
        let screen = NSScreen.main
        _ = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1400, height: 900)
        
        // Create window with proper centering
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        // CONFIGURATIONS FOR "INVISIBLE BORDER" LOOK
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.minSize = NSSize(width: 750, height: 600) // Adjusted min height
        window.isReleasedWhenClosed = false
        window.level = .floating
        
        // Set the content view controller
        window.contentViewController = hostingController
        
        // Set window delegate to handle close events
        window.delegate = self
        
        // Show the window BEFORE centering to ensure proper positioning
        window.makeKeyAndOrderFront(nil)
        
        // Center the window after it's shown
        window.center()
        
        hostingWindow = window
        
        // Present the notes modal with completion handler
        notesViewModel.present(
            projectID: projectID,
            projectName: projectName,
            projects: projects
        ) { [weak self] notes, mood, activityTypeID, projectPhaseID, milestoneText, isMilestoneFromViewModel in
            guard let self = self else { return }
            
            // NotesModalView is bound to notesViewModel.action and notesViewModel.isMilestone.
            // So, notesViewModel.action will hold the current action text.
            let actionToPass = self.notesViewModel.action
            
            self.dismissNotes()
            completion(notes, mood, activityTypeID, projectPhaseID, milestoneText, actionToPass, isMilestoneFromViewModel)
        }
    }
    
    private func dismissNotes() {
        isPresented = false
        
        // Close the hosting window
        hostingWindow?.close()
        hostingWindow = nil
    }
    
    // MARK: - Public Interface
    
    func resetContentAndFocus() {
        notesViewModel.resetContent()
        // Reset local action/milestone state if they are managed by NotesManager directly
        // (Not needed anymore as they are part of NotesViewModel)
        
        // Bring window to front and focus
        if let window = hostingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        // Handle window close - treat as cancel if not explicitly saved
        if isPresented {
            notesViewModel.cancelNotes() // This now correctly handles new fields
        }
        
        hostingWindow = nil
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Window became key - ensure focus is on text field
        resetContentAndFocus()
    }
}

// MARK: - Legacy Compatibility

extension NotesManager {
    /// Legacy method to match the old NotesModalWindowController interface
    func present(completion: @escaping (String, Int?) -> Void) {
        // For backward compatibility, use empty project info
        // The new action and isMilestone fields are not part of this legacy flow.
        presentNotes(projectID: nil, projectName: nil, projects: []) { notes, mood, _, _, _, action, isMilestone in
            // The legacy completion only expects notes and mood.
            // The other fields (including new action/isMilestone) are ignored here.
            completion(notes, mood)
        }
    }
}
