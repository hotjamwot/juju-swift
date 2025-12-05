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
    
    var currentProjectID: String? {
        get { operationsManager.currentProjectID }
        set { 
            operationsManager.currentProjectID = newValue
        }
    }
    
    var sessionStartTime: Date? {
        get { operationsManager.sessionStartTime }
        set { 
            operationsManager.sessionStartTime = newValue
            _sessionStartTime = newValue
        }
    }
    
    // MARK: - Active Session Property
    
    /// The currently active session as a SessionRecord, or nil if no session is active
    var activeSession: SessionRecord? {
        get {
            guard isSessionActive,
                  let projectName = operationsManager.currentProjectName,
                  let startTime = operationsManager.sessionStartTime else {
                return nil
            }
            
            // Create a SessionRecord for the active session
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            
            let date = dateFormatter.string(from: startTime)
            let startTimeString = timeFormatter.string(from: startTime)
            
            return SessionRecord(
                id: "active-session", // Use a fixed ID for the active session
                date: date,
                startTime: startTimeString,
                endTime: "",
                durationMinutes: getCurrentSessionDurationMinutes(),
                projectName: projectName,
                projectID: operationsManager.currentProjectID,
                activityTypeID: operationsManager.currentActivityTypeID,
                projectPhaseID: operationsManager.currentProjectPhaseID,
                milestoneText: nil,
                notes: "",
                mood: nil
            )
        }
    }
    
    private func getCurrentSessionDurationMinutes() -> Int {
        guard let startTime = operationsManager.sessionStartTime else { return 0 }
        let durationMs = Date().timeIntervalSince(startTime)
        return Int(round(durationMs / 60))
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
        
        guard let dataFileURL = dataFileURL, let jujuPath = jujuPath else {
            fatalError("Could not create data file URL")
        }
        
        // Initialize component managers
        self.sessionFileManager = SessionFileManager()
        self.operationsManager = SessionOperationsManager(sessionFileManager: sessionFileManager, dataFileURL: dataFileURL)
        self.dataManager = SessionDataManager(sessionFileManager: sessionFileManager, dataFileURL: dataFileURL)
        
        // Setup observers to sync state changes
        setupObservers()
        
        // Run migration if necessary (async, non-blocking)
        Task {
            let migrationManager = SessionMigrationManager(sessionFileManager: sessionFileManager, jujuPath: jujuPath)
            _ = await migrationManager.migrateIfNecessary()
        }
    }
    
    private func setupObservers() {
        // Observe data manager changes and propagate to main manager
        NotificationCenter.default.addObserver(
            forName: Notification.Name("sessionDidEnd"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Reload sessions after session ends
            // This is in a notification handler, so we can't await
            // We'll use Task to run it asynchronously
            Task {
                await self?.dataManager.loadRecentSessions(limit: 40)
            }
        }
    }
    
    // MARK: - Session State Management (Delegated to Operations Manager)
    
    func startSession(for projectName: String, projectID: String? = nil) {
        operationsManager.startSession(for: projectName, projectID: projectID)
    }
    
    func endSession(
        notes: String = "",
        mood: Int? = nil,
        activityTypeID: String? = nil,
        projectPhaseID: String? = nil,
        milestoneText: String? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        operationsManager.endSession(
            notes: notes,
            mood: mood,
            activityTypeID: activityTypeID,
            projectPhaseID: projectPhaseID,
            milestoneText: milestoneText,
            completion: completion ?? { _ in }
        )
    }
    
    func getCurrentSessionDuration() -> String {
        operationsManager.getCurrentSessionDuration()
    }
    
    // MARK: - Session Data Operations (Delegated to Data Manager)
    
    func loadAllSessions() async -> [SessionRecord] {
        await dataManager.loadAllSessions()
    }
    
    func loadSessions(in dateInterval: DateInterval?) async -> [SessionRecord] {
        await dataManager.loadSessions(in: dateInterval)
    }
    
    func loadRecentSessions(limit: Int = 40) async {
        await dataManager.loadRecentSessions(limit: limit)
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
