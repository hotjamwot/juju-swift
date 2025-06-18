import Cocoa
import WebKit

class DashboardWebViewController: NSViewController, WKScriptMessageHandler {
    private var webView: WKWebView!
    
    override func loadView() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "jujuBridge")
        // Inject window.api polyfill with debug logs
        let apiPolyfill = """
        console.log('Polyfill injected');
        window.api = {
            loadSessions: function() {
                console.log('window.api.loadSessions called');
                window.webkit.messageHandlers.jujuBridge.postMessage({ type: 'loadSessions' });
            },
            loadProjects: function() {
                console.log('window.api.loadProjects called');
                window.webkit.messageHandlers.jujuBridge.postMessage({ type: 'loadProjects' });
            },
            testLog: function() {
                console.log('window.api.testLog called');
            }
        };
        """
        let apiScript = WKUserScript(source: apiPolyfill, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(apiScript)
        config.userContentController = userContentController
        print("[DashboardWebViewController] Polyfill user script injected")
        webView = WKWebView(frame: .zero, configuration: config)
        self.view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadDashboardHTML()
    }
    
    private func loadDashboardHTML() {
        // Look for dashboard-web/dashboard.html in the app bundle
        guard let htmlURL = Bundle.main.url(forResource: "dashboard-web/dashboard", withExtension: "html") else {
            print("[DashboardWebViewController] ERROR: dashboard.html not found in bundle!")
            return
        }
        // Load the HTML file, allowing access to its folder for assets
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        print("[DashboardWebViewController] dashboard.html loaded into WKWebView")
    }
    
    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "jujuBridge" else { return }
        print("[DashboardWebViewController] JS message received: \(message.body)")
        if let dict = message.body as? [String: Any], let type = dict["type"] as? String {
            switch type {
            case "loadSessions":
                handleLoadSessions()
            case "loadProjects":
                handleLoadProjects()
            default:
                print("[DashboardWebViewController] Unknown message type: \(type)")
            }
        }
    }
    
    private func handleLoadSessions() {
        let sessions = SessionManager.shared.loadAllSessions()
        let sessionDicts: [[String: Any]] = sessions.map { s in
            return [
                "id": s.id,
                "date": s.date,
                "start_time": s.startTime,
                "end_time": s.endTime,
                "duration_minutes": s.durationMinutes,
                "project": s.projectName,
                "notes": s.notes
            ]
        }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sessionDicts, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                sendToJS(function: "window.onSessionsLoaded", argument: jsonString)
            }
        } catch {
            print("[DashboardWebViewController] Error encoding sessions to JSON: \(error)")
        }
    }
    
    private func handleLoadProjects() {
        let projects = ProjectManager.shared.loadProjects()
        do {
            let jsonData = try JSONEncoder().encode(projects)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                sendToJS(function: "window.onProjectsLoaded", argument: jsonString)
            }
        } catch {
            print("[DashboardWebViewController] Error encoding projects to JSON: \(error)")
        }
    }
    
    // MARK: - Send data to JS
    func sendToJS(function: String, argument: String) {
        let js = "\(function)(\(argument));"
        webView.evaluateJavaScript(js) { result, error in
            if let error = error {
                print("[DashboardWebViewController] Error sending to JS: \(error)")
            }
        }
    }
} 