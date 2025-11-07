import SwiftUI
import AppKit

@MainActor
class NotesManager: NSObject, ObservableObject, NSWindowDelegate {
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
        createHostingWindow(completion: completion)
        
        isPresented = true
    }
    
    private func createHostingWindow(completion: @escaping (String, Int?) -> Void) {
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
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.minSize = NSSize(width: 750, height: 450)
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
        notesViewModel.present { [weak self] notes, mood in
            self?.dismissNotes()
            completion(notes, mood)
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
