import Cocoa

class DashboardWindowController: NSWindowController, NSWindowDelegate {
    private var isActuallyClosing = false
    
    init() {
        let windowSize = NSSize(width: 1400, height: 1000)
        let minWindowSize = NSSize(width: 1400, height: 900)
        let screen = NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1400, height: 900)
        let x = screenFrame.midX - windowSize.width / 2
        let y = screenFrame.midY - windowSize.height / 2
        let windowRect = NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height)
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Juju Time Tracker"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.isReleasedWhenClosed = false  // Don't release when closed to preserve the instance
        window.level = .normal
        window.contentMinSize = minWindowSize

        // Host SwiftUI root with native tabs and embedded web charts
        let hosting = NSHostingController(rootView: SwiftUIDashboardRootView())
        window.contentViewController = hosting

        super.init(window: window)
        window.delegate = self
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        print("[DashboardWindowController] windowWillClose called")
        
        if isActuallyClosing {
            print("[DashboardWindowController] Actually closing window and cleaning up")
            // Cleanup when actually closing
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.dashboardWindowController = nil
            }
            // Explicitly release the contentViewController to help cleanup WKWebView
            self.window?.contentViewController = nil
        } else {
            print("[DashboardWindowController] Hiding window for reuse instead of closing")
            // Cancel the close operation and hide instead
            if let window = self.window {
                window.orderOut(nil)
            }
        }
    }
    
    // Override close to hide instead of close
    override func close() {
        print("[DashboardWindowController] close called - hiding window instead")
        if let window = self.window {
            window.orderOut(nil)
        }
    }
    
    // Method to actually close the window (called during app termination)
    func forceClose() {
        print("[DashboardWindowController] forceClose called")
        isActuallyClosing = true
        if let window = self.window {
            window.close()
        }
    }
    
    // Override windowShouldClose to hide instead of close
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        print("[DashboardWindowController] windowShouldClose called - hiding instead")
        if let window = self.window {
            window.orderOut(nil)
        }
        return false // Prevent actual closing
    }

    deinit {
        print("Deinit: DashboardWindowController")
    }
} 