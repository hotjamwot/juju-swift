import Cocoa
import WebKit

class NotesModalViewController: NSViewController, WKScriptMessageHandler {
    private var completion: ((String?) -> Void)?
    private var webView: WKWebView!
    
    convenience init(completion: @escaping (String?) -> Void) {
        self.init()
        self.completion = completion
    }
    
    override func loadView() {
        // Create simple WKWebView configuration
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "notesBridge")
        config.userContentController = userContentController
        
        // Create WKWebView
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 400), configuration: config)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]
        
        self.view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadNotesModal()
    }
    
    private func loadNotesModal() {
        // Look for notes-modal.html in the app bundle
        guard let htmlURL = Bundle.main.url(forResource: "dashboard-web/notes-modal", withExtension: "html") else {
            print("ERROR: notes-modal.html not found in bundle!")
            showFallbackTextView()
            return
        }
        
        // Load the HTML file
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }
    
    private func showFallbackTextView() {
        // Remove WKWebView and replace with simple text view
        webView.removeFromSuperview()
        
        let textView = NSTextView(frame: view.bounds)
        textView.isEditable = true
        textView.isSelectable = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.textColor
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.string = "Enter your session notes here..."
        
        let scrollView = NSScrollView(frame: view.bounds)
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        scrollView.autoresizingMask = [.width, .height]
        
        view.addSubview(scrollView)
        
        // Add buttons
        let buttonFrame = NSRect(x: view.bounds.width - 160, y: 10, width: 150, height: 30)
        let saveButton = NSButton(frame: buttonFrame)
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveNotes)
        view.addSubview(saveButton)
        
        let cancelFrame = NSRect(x: view.bounds.width - 240, y: 10, width: 70, height: 30)
        let cancelButton = NSButton(frame: cancelFrame)
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelNotes)
        view.addSubview(cancelButton)
    }
    
    @objc private func saveNotes() {
        // Get text from the fallback text view
        if let scrollView = view.subviews.first as? NSScrollView,
           let textView = scrollView.documentView as? NSTextView {
            let notes = textView.string
            closeWithResult(notes)
        }
    }
    
    @objc private func cancelNotes() {
        closeWithResult(nil)
    }
    
    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "notesBridge" else { return }
        
        if let dict = message.body as? [String: Any], let type = dict["type"] as? String {
            switch type {
            case "save":
                let notes = dict["notes"] as? String ?? ""
                closeWithResult(notes)
                
            case "cancel":
                closeWithResult(nil)
                
            default:
                print("Unknown message type: \(type)")
            }
        }
    }
    
    private func closeWithResult(_ result: String?) {
        view.window?.close()
        completion?(result)
    }
}

extension NotesModalViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Simple focus script - just ensure the textarea is focused
        let focusScript = """
        const textarea = document.getElementById('notesInput');
        if (textarea) {
            textarea.focus();
        }
        """
        
        webView.evaluateJavaScript(focusScript)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WKWebView failed to load: \(error)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WKWebView failed provisional navigation: \(error)")
    }
}

class NotesModalWindowController: NSWindowController {
    convenience init(completion: @escaping (String?) -> Void) {
        let notesViewController = NotesModalViewController(completion: completion)
        
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
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Session Notes"
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor.windowBackgroundColor
        window.contentViewController = notesViewController
        
        // Make window prominent
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Set minimum window size
        window.minSize = NSSize(width: 400, height: 300)
        
        self.init(window: window)
        window.delegate = self
    }
    
    override func showWindow(_ sender: Any?) {
        // Ensure the app is active first
        NSApp.activate(ignoringOtherApps: true)
        
        // Show the window
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
    }
}

extension NotesModalWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        // Window became key
    }
    
    func windowWillClose(_ notification: Notification) {
        // Window will close
    }
} 