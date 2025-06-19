import Cocoa
import WebKit

class DashboardWebViewController: NSViewController, WKScriptMessageHandler {
    private var webView: WKWebView!
    
    override func loadView() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        // Explicitly enable developer extras for WKWebView Inspector
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "jujuBridge")
        // Inject window.jujuApi polyfill with debug logs
        let apiPolyfill = """
        console.log('Polyfill injected');
        window.jujuApi = {
            loadSessions: function() {
                console.log('window.jujuApi.loadSessions called');
                window.webkit.messageHandlers.jujuBridge.postMessage({ type: 'loadSessions' });
            },
            loadProjects: function() {
                console.log('window.jujuApi.loadProjects called');
                window.webkit.messageHandlers.jujuBridge.postMessage({ type: 'loadProjects' });
            },
            updateSession: function(id, field, value) {
                return new Promise((resolve, reject) => {
                    const callbackId = 'cb_' + Math.random().toString(36).substr(2, 9);
                    window[callbackId] = (result) => {
                        delete window[callbackId];
                        if (result && result.success) resolve(result);
                        else reject(result && result.error ? result.error : 'Unknown error');
                    };
                    window.webkit.messageHandlers.jujuBridge.postMessage({
                        type: 'updateSession',
                        id, field, value, callbackId
                    });
                });
            },
            deleteSession: function(id) {
                return new Promise((resolve, reject) => {
                    const callbackId = 'cb_' + Math.random().toString(36).substr(2, 9);
                    window[callbackId] = (result) => {
                        delete window[callbackId];
                        if (result && result.success) resolve(result);
                        else reject(result && result.error ? result.error : 'Unknown error');
                    };
                    window.webkit.messageHandlers.jujuBridge.postMessage({
                        type: 'deleteSession',
                        id, callbackId
                    });
                });
            },
            getProjectNames: function() {
                return new Promise((resolve, reject) => {
                    const callbackId = 'cb_' + Math.random().toString(36).substr(2, 9);
                    window[callbackId] = (result) => {
                        delete window[callbackId];
                        if (result && result.success) resolve(result.names);
                        else reject(result && result.error ? result.error : 'Unknown error');
                    };
                    window.webkit.messageHandlers.jujuBridge.postMessage({
                        type: 'getProjectNames',
                        callbackId
                    });
                });
            },
            testLog: function() {
                console.log('window.jujuApi.testLog called');
            },
            addProject: function(project) {
                return new Promise((resolve, reject) => {
                    const callbackId = 'cb_' + Math.random().toString(36).substr(2, 9);
                    window[callbackId] = (result) => {
                        delete window[callbackId];
                        if (result && result.success) resolve(result);
                        else reject(result && result.error ? result.error : 'Unknown error');
                    };
                    window.webkit.messageHandlers.jujuBridge.postMessage({
                        type: 'addProject',
                        project, callbackId
                    });
                });
            },
            updateProjectColor: function(id, color) {
                return new Promise((resolve, reject) => {
                    const callbackId = 'cb_' + Math.random().toString(36).substr(2, 9);
                    window[callbackId] = (result) => {
                        delete window[callbackId];
                        if (result && result.success) resolve(result);
                        else reject(result && result.error ? result.error : 'Unknown error');
                    };
                    window.webkit.messageHandlers.jujuBridge.postMessage({
                        type: 'updateProjectColor',
                        id, color, callbackId
                    });
                });
            },
            deleteProject: function(id) {
                return new Promise((resolve, reject) => {
                    const callbackId = 'cb_' + Math.random().toString(36).substr(2, 9);
                    window[callbackId] = (result) => {
                        delete window[callbackId];
                        if (result && result.success) resolve(result);
                        else reject(result && result.error ? result.error : 'Unknown error');
                    };
                    window.webkit.messageHandlers.jujuBridge.postMessage({
                        type: 'deleteProject',
                        id, callbackId
                    });
                });
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
            print("[DashboardWebViewController] Parsed message type: \(type), dict: \(dict)")
            switch type {
            case "loadSessions":
                handleLoadSessions()
            case "loadProjects":
                handleLoadProjects()
            case "updateSession":
                print("[DashboardWebViewController] Handling updateSession with dict: \(dict)")
                let idValue = dict["id"]
                let id: Int? = {
                    if let intId = idValue as? Int { return intId }
                    if let strId = idValue as? String, let intId = Int(strId) { return intId }
                    return nil
                }()
                if let id = id,
                   let field = dict["field"] as? String,
                   let value = dict["value"] as? String,
                   let callbackId = dict["callbackId"] as? String {
                    print("[DashboardWebViewController] updateSession params: id=\(id), field=\(field), value=\(value), callbackId=\(callbackId)")
                    handleUpdateSession(id: id, field: field, value: value, callbackId: callbackId)
                } else {
                    print("[DashboardWebViewController] Invalid updateSession params: \(dict)")
                }
            case "deleteSession":
                print("[DashboardWebViewController] Handling deleteSession with dict: \(dict)")
                let idValue = dict["id"]
                let id: Int? = {
                    if let intId = idValue as? Int { return intId }
                    if let strId = idValue as? String, let intId = Int(strId) { return intId }
                    return nil
                }()
                if let id = id,
                   let callbackId = dict["callbackId"] as? String {
                    print("[DashboardWebViewController] deleteSession params: id=\(id), callbackId=\(callbackId)")
                    handleDeleteSession(id: id, callbackId: callbackId)
                } else {
                    print("[DashboardWebViewController] Invalid deleteSession params: \(dict)")
                }
            case "getProjectNames":
                if let callbackId = dict["callbackId"] as? String {
                    handleGetProjectNames(callbackId: callbackId)
                } else {
                    print("[DashboardWebViewController] Invalid getProjectNames params: \(dict)")
                }
            case "addProject":
                if let dictProject = dict["project"] as? [String: Any],
                   let name = dictProject["name"] as? String,
                   let color = dictProject["color"] as? String,
                   let callbackId = dict["callbackId"] as? String {
                    handleAddProject(name: name, color: color, callbackId: callbackId)
                } else {
                    print("[DashboardWebViewController] Invalid addProject params: \(dict)")
                }
            case "updateProjectColor":
                let idValue = dict["id"]
                let id: String? = {
                    if let strId = idValue as? String { return strId }
                    if let intId = idValue as? Int { return String(intId) }
                    return nil
                }()
                if let id = id,
                   let color = dict["color"] as? String,
                   let callbackId = dict["callbackId"] as? String {
                    handleUpdateProjectColor(id: id, color: color, callbackId: callbackId)
                } else {
                    print("[DashboardWebViewController] Invalid updateProjectColor params: \(dict)")
                }
            case "deleteProject":
                let idValue = dict["id"]
                let id: String? = {
                    if let strId = idValue as? String { return strId }
                    if let intId = idValue as? Int { return String(intId) }
                    return nil
                }()
                if let id = id,
                   let callbackId = dict["callbackId"] as? String {
                    handleDeleteProject(id: id, callbackId: callbackId)
                } else {
                    print("[DashboardWebViewController] Invalid deleteProject params: \(dict)")
                }
            default:
                print("[DashboardWebViewController] Unknown message type: \(type)")
            }
        } else {
            print("[DashboardWebViewController] Could not parse message body as [String: Any]: \(message.body)")
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
    
    // MARK: - Session Editing
    private func handleUpdateSession(id: Int, field: String, value: String, callbackId: String) {
        print("[DashboardWebViewController] handleUpdateSession called with id=\(id), field=\(field), value=\(value), callbackId=\(callbackId)")
        // Load all sessions
        var sessions = SessionManager.shared.loadAllSessions()
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else {
            print("[DashboardWebViewController] updateSession: id not found: id=\(id)")
            sendUpdateSessionCallback(callbackId: callbackId, success: false, error: "Session not found")
            return
        }
        var session = sessions[idx]
        switch field {
        case "date": session = SessionRecord(id: session.id, date: value, startTime: session.startTime, endTime: session.endTime, durationMinutes: session.durationMinutes, projectName: session.projectName, notes: session.notes)
        case "start_time": session = SessionRecord(id: session.id, date: session.date, startTime: value, endTime: session.endTime, durationMinutes: session.durationMinutes, projectName: session.projectName, notes: session.notes)
        case "end_time": session = SessionRecord(id: session.id, date: session.date, startTime: session.startTime, endTime: value, durationMinutes: session.durationMinutes, projectName: session.projectName, notes: session.notes)
        case "duration_minutes":
            if let mins = Int(value) {
                session = SessionRecord(id: session.id, date: session.date, startTime: session.startTime, endTime: session.endTime, durationMinutes: mins, projectName: session.projectName, notes: session.notes)
            } else {
                sendUpdateSessionCallback(callbackId: callbackId, success: false, error: "Invalid duration")
                return
            }
        case "project": session = SessionRecord(id: session.id, date: session.date, startTime: session.startTime, endTime: session.endTime, durationMinutes: session.durationMinutes, projectName: value, notes: session.notes)
        case "notes": session = SessionRecord(id: session.id, date: session.date, startTime: session.startTime, endTime: session.endTime, durationMinutes: session.durationMinutes, projectName: session.projectName, notes: value)
        default:
            sendUpdateSessionCallback(callbackId: callbackId, success: false, error: "Unknown field")
            return
        }
        sessions[idx] = session
        // Save all sessions back to CSV
        let header = "date,start_time,end_time,duration_minutes,project,notes\n"
        let rows = sessions.map { s in
            "\(s.date),\(s.startTime),\(s.endTime),\(s.durationMinutes),\"\(s.projectName)\",\"\(s.notes)\""
        }
        let csv = header + rows.joined(separator: "\n") + "\n"
        do {
            let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            let jujuPath = appSupportPath?.appendingPathComponent("Juju")
            let dataFile = jujuPath?.appendingPathComponent("data.csv")
            if let dataFile = dataFile {
                try? FileManager.default.createDirectory(at: jujuPath!, withIntermediateDirectories: true)
                try csv.write(to: dataFile, atomically: true, encoding: .utf8)
                sendUpdateSessionCallback(callbackId: callbackId, success: true, error: nil)
                handleLoadSessions() // Immediately send updated data to JS
            } else {
                sendUpdateSessionCallback(callbackId: callbackId, success: false, error: "Data file not found")
            }
        } catch {
            sendUpdateSessionCallback(callbackId: callbackId, success: false, error: error.localizedDescription)
        }
    }
    
    // MARK: - Session Deletion
    private func handleDeleteSession(id: Int, callbackId: String) {
        print("[DashboardWebViewController] handleDeleteSession called with id=\(id), callbackId=\(callbackId)")
        var sessions = SessionManager.shared.loadAllSessions()
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else {
            print("[DashboardWebViewController] deleteSession: id not found: id=\(id)")
            sendUpdateSessionCallback(callbackId: callbackId, success: false, error: "Session not found")
            return
        }
        sessions.remove(at: idx)
        // Save all sessions back to CSV
        let header = "date,start_time,end_time,duration_minutes,project,notes\n"
        let rows = sessions.map { s in
            "\(s.date),\(s.startTime),\(s.endTime),\(s.durationMinutes),\"\(s.projectName)\",\"\(s.notes)\""
        }
        let csv = header + rows.joined(separator: "\n") + "\n"
        do {
            let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            let jujuPath = appSupportPath?.appendingPathComponent("Juju")
            let dataFile = jujuPath?.appendingPathComponent("data.csv")
            if let dataFile = dataFile {
                try? FileManager.default.createDirectory(at: jujuPath!, withIntermediateDirectories: true)
                try csv.write(to: dataFile, atomically: true, encoding: .utf8)
                sendUpdateSessionCallback(callbackId: callbackId, success: true, error: nil)
                handleLoadSessions() // Immediately send updated data to JS
            } else {
                sendUpdateSessionCallback(callbackId: callbackId, success: false, error: "Data file not found")
            }
        } catch {
            sendUpdateSessionCallback(callbackId: callbackId, success: false, error: error.localizedDescription)
        }
    }
    
    private func sendUpdateSessionCallback(callbackId: String, success: Bool, error: String?) {
        var result = "{success: \(success)"
        if let error = error {
            result += ", error: '" + error.replacingOccurrences(of: "'", with: "\\'") + "'"
        }
        result += "}"
        let js = "window['\(callbackId)'](\(result));"
        webView.evaluateJavaScript(js) { result, error in
            if let error = error {
                print("[DashboardWebViewController] Error sending updateSession callback: \(error)")
            }
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
    
    // MARK: - Project Names for Dropdown
    private func handleGetProjectNames(callbackId: String) {
        let projects = ProjectManager.shared.loadProjects()
        let names = projects.map { $0.name }
        let result: [String: Any] = ["success": true, "names": names]
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: result, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let js = "window['\(callbackId)'](\(jsonString));"
                webView.evaluateJavaScript(js) { result, error in
                    if let error = error {
                        print("[DashboardWebViewController] Error sending getProjectNames callback: \(error)")
                    }
                }
            }
        } catch {
            print("[DashboardWebViewController] Error encoding project names: \(error)")
        }
    }
    
    // MARK: - Project CRUD Handlers
    private func handleAddProject(name: String, color: String, callbackId: String) {
        var projects = ProjectManager.shared.loadProjects()
        let newProject = Project(name: name, color: color)
        projects.append(newProject)
        ProjectManager.shared.saveProjects(projects)
        sendProjectCallback(callbackId: callbackId, success: true, error: nil)
        handleLoadProjects() // Refresh UI
    }
    private func handleUpdateProjectColor(id: String, color: String, callbackId: String) {
        var projects = ProjectManager.shared.loadProjects()
        guard let idx = projects.firstIndex(where: { $0.id == id }) else {
            sendProjectCallback(callbackId: callbackId, success: false, error: "Project not found")
            return
        }
        projects[idx].color = color
        ProjectManager.shared.saveProjects(projects)
        sendProjectCallback(callbackId: callbackId, success: true, error: nil)
        handleLoadProjects() // Refresh UI
    }
    private func handleDeleteProject(id: String, callbackId: String) {
        var projects = ProjectManager.shared.loadProjects()
        guard let idx = projects.firstIndex(where: { $0.id == id }) else {
            sendProjectCallback(callbackId: callbackId, success: false, error: "Project not found")
            return
        }
        projects.remove(at: idx)
        ProjectManager.shared.saveProjects(projects)
        sendProjectCallback(callbackId: callbackId, success: true, error: nil)
        handleLoadProjects() // Refresh UI
    }
    private func sendProjectCallback(callbackId: String, success: Bool, error: String?) {
        var result: [String: Any] = ["success": success]
        if let error = error {
            result["error"] = error
        }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: result, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let js = "window['\(callbackId)'](\(jsonString));"
                webView.evaluateJavaScript(js) { result, error in
                    if let error = error {
                        print("[DashboardWebViewController] Error sending project callback: \(error)")
                    }
                }
            }
        } catch {
            print("[DashboardWebViewController] Error encoding project callback: \(error)")
        }
    }
} 