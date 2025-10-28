import SwiftUI
import AppKit

@MainActor
class NotesManager: NSObject, ObservableObject {
    static let shared = NotesManager()
    
    @Published private(set) var isPresented = false
    private var notesViewModel = NotesViewModel()
    private var hostingWindow: NSWindow?
    
    override private init() {}
    
    // MARK: - Presentation Methods
    
    func presentNotes(completion: @escaping (String, Int?) -> Void) {
        // Ensure we're on main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.presentNotes(completion: completion)
            }
            return
        }
        
        // Activate the app to bring it to front
        NSApp.activate(ignoringOtherApps: true)
        
        // Create and configure the hosting window
        createHostingWindow()
        
        // Present the notes modal
        notesViewModel.present { [weak self] notes, mood in
            self?.dismissNotes()
            completion(notes, mood)
        }
        
        isPresented = true
    }
    
    private func createHostingWindow() {
        // Clean up existing window if any
        if let existingWindow = hostingWindow {
            existingWindow.close()
            hostingWindow = nil
        }
        
        // Create the SwiftUI view
        let notesView = NotesModalView(viewModel: notesViewModel)
        
        // Create hosting controller
        let hostingController = NSHostingController(rootView: notesView)
        
        // Create window
        let windowSize = NSSize(width: 600, height: 400)
        let screen = NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1400, height: 900)
        
        // Position at center of screen
        let x = screenFrame.midX - windowSize.width / 2
        let y = screenFrame.midY - windowSize.height / 2
        let windowRect = NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height)
        
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Session Notes"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.minSize = NSSize(width: 400, height: 300)
        
        // Set window delegate to handle close events
        window.delegate = self
        
        // Show the window
        window.makeKeyAndOrderFront(nil)
        
        hostingWindow = window
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
        
        // Bring window to front and focus
        if let window = hostingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - NSWindowDelegate

extension NotesManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Handle window close - treat as cancel if not explicitly saved
        if isPresented {
            notesViewModel.cancelNotes()
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
        presentNotes(completion: completion)
    }
}
