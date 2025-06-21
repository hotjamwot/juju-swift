import Cocoa
import WebKit

class NotesModalViewController: NSViewController, WKScriptMessageHandler {
    private var completion: ((String?) -> Void)?
    internal var webView: WKWebView!
    
    convenience init(completion: @escaping (String?) -> Void) {
        self.init()
        self.completion = completion
    }
    
    override func loadView() {
        // Create WKWebView configuration with clipboard permissions
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "notesBridge")
        config.userContentController = userContentController
        
        // Enable JavaScript and clipboard access
        config.preferences.javaScriptEnabled = true
        
        // Enable clipboard access
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // Create WKWebView
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 400), configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.autoresizingMask = [.width, .height]
        
        // Enable clipboard access
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        
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
        
        // Create a container view for better layout
        let containerView = NSView(frame: view.bounds)
        containerView.autoresizingMask = [.width, .height]
        
        // Create title label
        let titleLabel = NSTextField(labelWithString: "What did you work on?")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.frame = NSRect(x: 20, y: view.bounds.height - 40, width: view.bounds.width - 40, height: 20)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        containerView.addSubview(titleLabel)
        
        // Create text view with proper styling
        let textView = NSTextView(frame: NSRect(x: 20, y: 60, width: view.bounds.width - 40, height: view.bounds.height - 140))
        textView.isEditable = true
        textView.isSelectable = true
        textView.backgroundColor = NSColor.controlBackgroundColor
        textView.textColor = NSColor.textColor
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.string = ""
        textView.autoresizingMask = [.width, .height]
        
        // Add placeholder text
        textView.string = "Enter your session notes here..."
        
        let scrollView = NSScrollView(frame: textView.frame)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .lineBorder
        scrollView.backgroundColor = NSColor.controlBackgroundColor
        
        containerView.addSubview(scrollView)
        
        // Add buttons with better styling
        let buttonHeight: CGFloat = 30
        let buttonWidth: CGFloat = 80
        let buttonY: CGFloat = 20
        
        let saveButton = NSButton(frame: NSRect(x: view.bounds.width - buttonWidth - 20, y: buttonY, width: buttonWidth, height: buttonHeight))
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r" // Enter key
        saveButton.target = self
        saveButton.action = #selector(saveNotes)
        saveButton.autoresizingMask = [.minXMargin, .minYMargin]
        containerView.addSubview(saveButton)
        
        let cancelButton = NSButton(frame: NSRect(x: view.bounds.width - buttonWidth * 2 - 30, y: buttonY, width: buttonWidth, height: buttonHeight))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}" // Escape key
        cancelButton.target = self
        cancelButton.action = #selector(cancelNotes)
        cancelButton.autoresizingMask = [.minXMargin, .minYMargin]
        containerView.addSubview(cancelButton)
        
        // Add keyboard hint
        let hintLabel = NSTextField(labelWithString: "Press ⌘+Enter to save, or Esc to cancel")
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = NSColor.secondaryLabelColor
        hintLabel.frame = NSRect(x: 20, y: buttonY + buttonHeight + 5, width: view.bounds.width - 40, height: 15)
        hintLabel.autoresizingMask = [.width, .minYMargin]
        containerView.addSubview(hintLabel)
        
        view.addSubview(containerView)
        
        // Focus the text view and clear placeholder
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
            if textView.string == "Enter your session notes here..." {
                textView.string = ""
            }
        }
    }
    
    @objc private func saveNotes() {
        // Get text from the text view in the container
        if let containerView = view.subviews.first,
           let scrollView = containerView.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
           let textView = scrollView.documentView as? NSTextView {
            let notes = textView.string
            closeWithResult(notes)
        }
    }
    
    @objc private func cancelNotes() {
        closeWithResult(nil)
    }
    
    private func closeWithResult(_ result: String?) {
        view.window?.close()
        completion?(result)
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
}

extension NotesModalViewController: WKUIDelegate {
    // Handle JavaScript dialogs and clipboard permissions
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        completionHandler(defaultText)
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