import Cocoa
import SwiftUI

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
        window.title = "Juju Time Tracker"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.isReleasedWhenClosed = false // Keep instance until fully cleaned up
        window.level = .normal
        window.contentMinSize = minWindowSize

        // Host SwiftUI root
        let hostingController = NSHostingController(rootView: SwiftUIDashboardRootView())
        window.contentViewController = hostingController

        super.init(window: window)
        window.delegate = self
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        print("[DashboardWindowController] windowWillClose - cleaning up")
        cleanupWebViewIfNeeded()
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.dashboardWindowController = nil
        }
    }

    // Optional: handle Cmd+W explicitly
    override func cancelOperation(_ sender: Any?) {
        print("[DashboardWindowController] Cmd+W pressed - closing window")
        self.window?.close()
    }

    // MARK: - WebView cleanup

    private func cleanupWebViewIfNeeded() {
        if let hosting = window?.contentViewController as? NSHostingController<SwiftUIDashboardRootView> {
            NotificationCenter.default.post(name: .cleanupWebView, object: nil)
        }
    }

    deinit {
        print("[DashboardWindowController] deinit")
    }
}
