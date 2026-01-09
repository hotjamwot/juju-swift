import Cocoa
import SwiftUI
import Charts

class DashboardWindowController: NSWindowController, NSWindowDelegate {

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
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.isReleasedWhenClosed = false // Keep instance until fully cleaned up
        window.level = .normal
        window.contentMinSize = minWindowSize
        let hostingController = NSHostingController(rootView: DashboardRootView())
        super.init(window: window)
        window.delegate = self
        window.center()
        window.contentViewController = hostingController
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        print("[DashboardWindowController] windowWillClose - cleaning up")
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.dashboardWindowController = nil
        }
    }

    // Tell the system we’re happy to close.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        print("[DashboardWindowController] windowShouldClose - returning true")
        return true   // Allow the close to happen
    }
    // Optional: handle Cmd+W explicitly
    override func cancelOperation(_ sender: Any?) {
        print("[DashboardWindowController] Cmd+W pressed - closing window")
        self.window?.close()
    }


    deinit {
        print("[DashboardWindowController] deinit")
    }
}
