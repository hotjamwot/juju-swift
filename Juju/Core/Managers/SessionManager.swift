import Foundation

// MARK: - Session Manager
class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    // MARK: - Component Managers
    private let sessionFileManager: SessionFileManager
    private let operationsManager: SessionOperationsManager
    private let dataManager: SessionDataManager
    
    // MARK: - Published Properties (Delegated to component managers)
    private var _allSessions: [SessionRecord] = []
    private var _lastUpdated: Date = Date()
    private var _isSessionActive: Bool = false
    private var _currentProjectName: String?
    private var _sessionStartTime: Date?
    
    var allSessions: [SessionRecord] {
        get { dataManager.allSessions }
        set { 
            dataManager.allSessions = newValue
            _allSessions = newValue
        }
    }
    
    var lastUpdated: Date {
        get { dataManager.lastUpdated }
        set { 
            dataManager.lastUpdated = newValue
            _lastUpdated = newValue
        }
    }
    
    var isSessionActive: Bool {
        get { operationsManager.isSessionActive }
        set { 
            operationsManager.isSessionActive = newValue
            _isSessionActive = newValue
        }
    }
    
    var currentProjectName: String? {
        get { operationsManager.currentProjectName }
        set { 
            operationsManager.currentProjectName = newValue
            _currentProjectName = newValue
        }
    }
    
    var sessionStartTime: Date? {
        get { operationsManager.sessionStartTime }
        set { 
            operationsManager.sessionStartTime = newValue
            _sessionStartTime = newValue
        }
    }
    
    // MARK: - CSV file path
    private let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    private let jujuPath: URL?
    private let dataFileURL: URL?
    
    // MARK: - Initialization
    private init() {
        // Setup file paths
        self.jujuPath = appSupportPath?.appendingPathComponent("Juju")
        self.dataFileURL = jujuPath?.appendingPathComponent("data.csv")
        
        guard let dataFileURL = dataFileURL else {
            fatalError("Could not create data file URL")
        }
        
        // Initialize component managers
        self.sessionFileManager = SessionFileManager()
        self.operationsManager = SessionOperationsManager(sessionFileManager: sessionFileManager, dataFileURL: dataFileURL)
        self.dataManager = SessionDataManager(sessionFileManager: sessionFileManager, dataFileURL: dataFileURL)
        
        // Setup observers to sync state changes
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe data manager changes and propagate to main manager
        NotificationCenter.default.addObserver(
            forName: Notification.Name("sessionDidEnd"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Reload sessions after session ends
            self?.dataManager.loadRecentSessions(limit: 40)
        }
    }
    
    // MARK: - Session State Management (Delegated to Operations Manager)
    
    func startSession(for projectName: String) {
        operationsManager.startSession(for: projectName)
    }
    
    func endSession(notes: String = "", mood: Int? = nil, completion: ((Bool) -> Void)? = nil) {
        operationsManager.endSession(notes: notes, mood: mood, completion: completion ?? { _ in })
    }
    
    func getCurrentSessionDuration() -> String {
        operationsManager.getCurrentSessionDuration()
    }
    
    // MARK: - Session Data Operations (Delegated to Data Manager)
    
    func loadAllSessions() -> [SessionRecord] {
        dataManager.loadAllSessions()
    }
    
    func loadSessions(in dateInterval: DateInterval?) -> [SessionRecord] {
        dataManager.loadSessions(in: dateInterval)
    }
    
    func loadRecentSessions(limit: Int = 40) {
        dataManager.loadRecentSessions(limit: limit)
    }
    
    func updateSession(id: String, field: String, value: String) -> Bool {
        dataManager.updateSession(id: id, field: field, value: value)
    }
    
    func updateSessionFull(id: String, date: String, startTime: String, endTime: String, projectName: String, notes: String, mood: Int?) -> Bool {
        dataManager.updateSessionFull(id: id, date: date, startTime: startTime, endTime: endTime, projectName: projectName, notes: notes, mood: mood)
    }
    
    func deleteSession(id: String) -> Bool {
        dataManager.deleteSession(id: id)
    }
    
    // MARK: - Session Export (Delegated to Data Manager)
    
    func exportSessions(_ sessions: [SessionRecord], format: String, fileName: String? = nil) -> URL? {
        dataManager.exportSessions(sessions, format: format, fileName: fileName)
    }
    
    func saveAllSessions(_ sessions: [SessionRecord]) {
        dataManager.saveAllSessions(sessions)
    }
    
    // MARK: - Utility Functions
    
    func minutesBetween(start: String, end: String) -> Int {
        operationsManager.minutesBetween(start: start, end: end)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
