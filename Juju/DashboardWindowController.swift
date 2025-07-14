import Cocoa

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
        window.isReleasedWhenClosed = true
        window.level = .normal
        window.contentMinSize = minWindowSize

        let dashboardView = DashboardWebViewController()
        window.contentViewController = dashboardView

        super.init(window: window)
        window.delegate = self
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.dashboardWindowController = nil
        }
        // Explicitly release the contentViewController to help cleanup WKWebView
        self.window?.contentViewController = nil
    }

    deinit {
        print("Deinit: DashboardWindowController")
    }
} 