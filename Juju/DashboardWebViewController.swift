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
        window.api = window.api || {};
        window.api.getComparisonStats = function() {
            console.log('window.api.getComparisonStats called');
            const sessions = window.allSessions && Array.isArray(window.allSessions) ? window.allSessions : [];
            if (!sessions.length) {
                console.warn('getComparisonStats: No session data available.');
                return Promise.resolve(null);
            }
            // Helper: parse date string to Date object
            function parseDate(dateStr) {
                return new Date(dateStr + 'T00:00:00');
            }
            // Helper: get ISO week number and year
            function getWeekYear(date) {
                const d = new Date(date);
                d.setHours(0,0,0,0);
                d.setDate(d.getDate() + 4 - (d.getDay()||7));
                const yearStart = new Date(d.getFullYear(),0,1);
                const weekNo = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
                return { year: d.getFullYear(), week: weekNo };
            }
            // Helper: get YYYY-MM for month key
            function getMonthKey(date) {
                return date.getFullYear() + '-' + (date.getMonth()+1).toString().padStart(2,'0');
            }
            // --- DAY COMPARISON ---
            const today = new Date();
            today.setHours(0,0,0,0);
            const weekday = today.getDay();
            // Find last 3 same weekdays (e.g., last 3 Fridays)
            const pastDays = [];
            for (let i = 1; i <= 3; i++) {
                const d = new Date(today);
                d.setDate(today.getDate() - 7*i);
                pastDays.push(d);
            }
            // Helper: sum duration for a given date
            function sumDay(date) {
                const key = date.toISOString().slice(0,10);
                return sessions.filter(s => s.date === key).reduce((sum, s) => sum + (s.duration_minutes || 0), 0) / 60;
            }
            const dayPast = pastDays.map(d => ({
                label: d.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' }),
                value: +sumDay(d).toFixed(1)
            }));
            const dayCurrentValue = +sumDay(today).toFixed(1);
            const dayAvg = dayPast.length ? dayPast.reduce((sum, d) => sum + d.value, 0) / dayPast.length : 0;
            const dayRange = dayAvg ? ((dayCurrentValue - dayAvg) >= 0 ? '+' : '') + (dayCurrentValue - dayAvg).toFixed(1) + 'h vs avg' : '';
            const dayCurrent = { label: today.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' }), value: dayCurrentValue, range: dayRange };
            // --- WEEK COMPARISON ---
            // This week: Monday to today
            const thisMonday = new Date(today);
            thisMonday.setDate(today.getDate() - ((today.getDay() + 6) % 7));
            function sumWeekRange(start, end) {
                return sessions.filter(s => {
                    const d = parseDate(s.date);
                    return d >= start && d <= end;
                }).reduce((sum, s) => sum + (s.duration_minutes || 0), 0) / 60;
            }
            const weekPast = [];
            for (let i = 3; i >= 1; i--) {
                const pastMonday = new Date(thisMonday);
                pastMonday.setDate(thisMonday.getDate() - 7*i);
                const pastEnd = new Date(pastMonday);
                pastEnd.setDate(pastMonday.getDate() + (today.getDay()));
                weekPast.push({
                    label: pastMonday.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) + '–' + pastEnd.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
                    value: +sumWeekRange(pastMonday, pastEnd).toFixed(1)
                });
            }
            const weekCurrentValue = +sumWeekRange(thisMonday, today).toFixed(1);
            const weekAvg = weekPast.length ? weekPast.reduce((sum, d) => sum + d.value, 0) / weekPast.length : 0;
            const weekRange = weekAvg ? ((weekCurrentValue - weekAvg) >= 0 ? '+' : '') + (weekCurrentValue - weekAvg).toFixed(1) + 'h vs avg' : '';
            const weekCurrent = { label: thisMonday.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) + '–' + today.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }), value: weekCurrentValue, range: weekRange };
            // --- MONTH COMPARISON ---
            // This month: 1st to today
            const thisMonthStart = new Date(today.getFullYear(), today.getMonth(), 1);
            function sumMonthRange(start, end) {
                return sessions.filter(s => {
                    const d = parseDate(s.date);
                    return d >= start && d <= end;
                }).reduce((sum, s) => sum + (s.duration_minutes || 0), 0) / 60;
            }
            const monthPast = [];
            for (let i = 3; i >= 1; i--) {
                const pastMonthStart = new Date(thisMonthStart);
                pastMonthStart.setMonth(thisMonthStart.getMonth() - i);
                const pastEnd = new Date(pastMonthStart);
                pastEnd.setDate(Math.min(today.getDate(), new Date(pastMonthStart.getFullYear(), pastMonthStart.getMonth() + 1, 0).getDate()));
                monthPast.push({
                    label: pastMonthStart.toLocaleDateString(undefined, { month: 'short', year: '2-digit' }),
                    value: +sumMonthRange(pastMonthStart, pastEnd).toFixed(1)
                });
            }
            const monthCurrentValue = +sumMonthRange(thisMonthStart, today).toFixed(1);
            const monthAvg = monthPast.length ? monthPast.reduce((sum, d) => sum + d.value, 0) / monthPast.length : 0;
            const monthRange = monthAvg ? ((monthCurrentValue - monthAvg) >= 0 ? '+' : '') + (monthCurrentValue - monthAvg).toFixed(1) + 'h vs avg' : '';
            const monthCurrent = { label: thisMonthStart.toLocaleDateString(undefined, { month: 'short', year: '2-digit' }), value: monthCurrentValue, range: monthRange };
            // Compose result
            const result = {
                day: { past: dayPast, current: dayCurrent },
                week: { past: weekPast, current: weekCurrent },
                month: { past: monthPast, current: monthCurrent }
            };
            console.log('getComparisonStats result:', result);
            return Promise.resolve(result);
        };
        window.jujuApi = {
            loadSessions: function() {
                console.log('window.jujuApi.loadSessions called');
                return new Promise((resolve, reject) => {
                    const callbackName = 'onSessionsLoaded';
                    const original = window[callbackName];
                    window[callbackName] = function(sessions) {
                        if (typeof original === 'function') original(sessions);
                        resolve(sessions);
                    };
                    window.webkit.messageHandlers.jujuBridge.postMessage({ type: 'loadSessions' });
                });
            },
            loadProjects: function() {
                console.log('window.jujuApi.loadProjects called');
                return new Promise((resolve, reject) => {
                    const callbackName = 'onProjectsLoaded';
                    const original = window[callbackName];
                    window[callbackName] = function(projects) {
                        if (typeof original === 'function') original(projects);
                        resolve(projects);
                    };
                    window.webkit.messageHandlers.jujuBridge.postMessage({ type: 'loadProjects' });
                });
            },
            updateSession: function(id, field, value) {
                console.log('window.jujuApi.updateSession called', id, field, value);
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
                console.log('window.jujuApi.deleteSession called', id, 'type:', typeof id);
                return new Promise((resolve, reject) => {
                    const callbackId = 'cb_' + Math.random().toString(36).substr(2, 9);
                    window[callbackId] = (result) => {
                        delete window[callbackId];
                        if (result && result.success) resolve(result);
                        else reject(result && result.error ? result.error : 'Unknown error');
                    };
                    console.log('[Polyfill] About to postMessage to Swift: type=deleteSession, id=', id, 'type:', typeof id, 'callbackId:', callbackId);
                    window.webkit.messageHandlers.jujuBridge.postMessage({
                        type: 'deleteSession',
                        id, callbackId
                    });
                });
            },
            getProjectNames: function() {
                console.log('window.jujuApi.getProjectNames called');
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
                console.log('window.jujuApi.addProject called', project);
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
                console.log('window.jujuApi.updateProjectColor called', id, color);
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
                console.log('[Polyfill] window.jujuApi.deleteProject called with id', id);
                return new Promise((resolve, reject) => {
                    const callbackId = 'cb_' + Math.random().toString(36).substr(2, 9);
                    window[callbackId] = (result) => {
                        delete window[callbackId];
                        if (result && result.success) resolve(result);
                        else reject(result && result.error ? result.error : 'Unknown error');
                    };
                    const msg = { type: 'deleteProject', id, callbackId };
                    console.log('[Polyfill] About to postMessage to Swift:', msg);
                    window.webkit.messageHandlers.jujuBridge.postMessage(msg);
                });
            }
        };
        window.jujuApi.getComparisonStats = window.api.getComparisonStats;
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
                let id: String? = {
                    if let strId = idValue as? String { return strId }
                    if let intId = idValue as? Int { return String(intId) }
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
                let id: String? = {
                    if let strId = idValue as? String { return strId }
                    if let intId = idValue as? Int { return String(intId) }
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
                print("[DashboardWebViewController] Sending sessions to JS: \(jsonString)")
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
                print("[DashboardWebViewController] Sending projects to JS: \(jsonString)")
                sendToJS(function: "window.onProjectsLoaded", argument: jsonString)
            }
        } catch {
            print("[DashboardWebViewController] Error encoding projects to JSON: \(error)")
        }
    }
    
    // MARK: - Session Editing
    private func handleUpdateSession(id: String, field: String, value: String, callbackId: String) {
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
        let header = "id,date,start_time,end_time,duration_minutes,project,notes\n"
        let rows = sessions.map { s in
            "\(s.id),\(s.date),\(s.startTime),\(s.endTime),\(s.durationMinutes),\"\(s.projectName)\",\"\(s.notes)\""
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
    private func handleDeleteSession(id: String, callbackId: String) {
        print("[DashboardWebViewController] handleDeleteSession called with id=\(id) (type: \(type(of: id))), callbackId=\(callbackId)")
        var sessions = SessionManager.shared.loadAllSessions()
        print("[DashboardWebViewController] Loaded session ids:", sessions.map { $0.id })
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else {
            print("[DashboardWebViewController] deleteSession: id not found: id=\(id)")
            sendUpdateSessionCallback(callbackId: callbackId, success: false, error: "Session not found")
            return
        }
        sessions.remove(at: idx)
        // Save all sessions back to CSV
        let header = "id,date,start_time,end_time,duration_minutes,project,notes\n"
        let rows = sessions.map { s in
            "\(s.id),\(s.date),\(s.startTime),\(s.endTime),\(s.durationMinutes),\"\(s.projectName)\",\"\(s.notes)\""
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