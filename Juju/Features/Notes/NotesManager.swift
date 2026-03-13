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
    
    // MARK: - Initialization
    
    private var hasSetupAppLifecycleObservers = false

    private func setupAppLifecycleObservers() {
        // Ensure we only register observers once
        guard !hasSetupAppLifecycleObservers else { return }
        hasSetupAppLifecycleObservers = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidActivate),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidActivate() {
        // When app comes back to foreground, ensure the window is visible if it was previously shown
        if isPresented, let window = hostingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    // MARK: - Presentation Methods
    
    func presentNotes(
        projectID: String?,
        projectName: String?,
        projects: [Project],
        completion: @escaping (String, Int?, String?, String?, String, Bool) -> Void // notes, mood, activityTypeID, projectPhaseID, action, isMilestone
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
        
        // Set up app lifecycle observers (only once)
        setupAppLifecycleObservers()
        
        // Create and configure the hosting window
        createHostingWindow(projectID: projectID, projectName: projectName, projects: projects, completion: completion)
        
        isPresented = true
    }
    
    private func createHostingWindow(
        projectID: String?,
        projectName: String?,
        projects: [Project],
        completion: @escaping (String, Int?, String?, String?, String, Bool) -> Void
    ) {
        // If window already exists, just bring it to front and update context
        if let existingWindow = hostingWindow {
            // Detect if we're switching to a different project so we don't keep stale selections
            let projectChanged = notesViewModel.currentProjectID != projectID

            // Use a centralized helper on the view model to prepare project-related state
            notesViewModel.prepareForPresentation(projectID: projectID, projectName: projectName, projects: projects)

            // Always reset ephemeral content (notes, action) when presenting for a new session
            // Smart defaults will still apply for activityType and phase
            notesViewModel.resetContent()

            // Update completion handler with wrapper that hides window
            let wrappedCompletion: (String, Int?, String?, String?, String, Bool) -> Void = { [weak self] notes, mood, activityTypeID, projectPhaseID, action, isMilestone in
                self?.dismissNotes()
                completion(notes, mood, activityTypeID, projectPhaseID, action, isMilestone)
            }
            notesViewModel.updateCompletion(wrappedCompletion)

            // Ensure the window appears centered when re-presenting (use async to allow frame calculation)
            DispatchQueue.main.async {
                existingWindow.center()
            }

            // Bring window back to front
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create the SwiftUI view
        let notesView = NotesModalView(viewModel: notesViewModel)
        
        // Create hosting controller
        let hostingController = NSHostingController(rootView: notesView)
        
        // Create window
        let windowSize = NSSize(width: 750, height: 450)
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
        window.minSize = NSSize(width: 750, height: 600)
        window.isReleasedWhenClosed = false
        
        // Set the content view controller
        window.contentViewController = hostingController
        
        // Set window delegate to handle close events
        window.delegate = self
        
        // Show the window BEFORE centering to ensure proper positioning
        window.makeKeyAndOrderFront(nil)
        
        // Center the window after a brief delay to ensure window frame is calculated
        DispatchQueue.main.async {
            window.center()
        }
        
        hostingWindow = window
        
        // Wrap the completion handler so it also hides the window
        let wrappedCompletion: (String, Int?, String?, String?, String, Bool) -> Void = { [weak self] notes, mood, activityTypeID, projectPhaseID, action, isMilestone in
            self?.dismissNotes()
            completion(notes, mood, activityTypeID, projectPhaseID, action, isMilestone)
        }
        
        // Present the notes modal with wrapped completion handler
        notesViewModel.present(
            projectID: projectID,
            projectName: projectName,
            projects: projects,
            completion: wrappedCompletion
        )
    }
    
    private func dismissNotes() {
        isPresented = false
        
        // Hide the window instead of closing it
        hostingWindow?.orderOut(nil)
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
        // Close button clicked - treat as cancel
        notesViewModel.cancelNotes()
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Window became key - ensure focus is on the action field, but don't clear user's content
        if let window = hostingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        // Request focus in the SwiftUI view (without resetting content)
        notesViewModel.requestActionFieldFocus()
    }
}

// MARK: - Legacy Compatibility

extension NotesManager {
    /// Legacy method to match the old NotesModalWindowController interface
    func present(completion: @escaping (String, Int?) -> Void) {
        // For backward compatibility, use empty project info
        // The new action and isMilestone fields are not part of this legacy flow.
        presentNotes(projectID: nil, projectName: nil, projects: []) { notes, mood, _, _, action, isMilestone in
            // The legacy completion only expects notes and mood.
            // The other fields (including new action/isMilestone) are ignored here.
            completion(notes, mood)
        }
    }
}
