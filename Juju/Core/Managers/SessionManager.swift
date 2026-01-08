import Foundation

// MARK: - Simplified Session Manager
class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    // MARK: - Published Properties (Direct Access)
    @Published var allSessions: [SessionRecord] = []
    @Published var lastUpdated: Date = Date()
    @Published var isSessionActive: Bool = false
    @Published var currentProjectName: String?
    @Published var currentProjectID: String?
    @Published var currentActivityTypeID: String?
    @Published var currentProjectPhaseID: String?
    @Published var sessionStartTime: Date?
    
    // MARK: - Active Session Property
    var activeSession: SessionRecord? {
        get {
            guard isSessionActive,
                  let projectName = currentProjectName,
                  let startTime = sessionStartTime else {
                return nil
            }
            
            let endTime = Date()
            return SessionRecord(
                id: "active-session",
                startDate: startTime,
                endDate: endTime,
                projectID: currentProjectID ?? "",
                activityTypeID: currentActivityTypeID,
                projectPhaseID: currentProjectPhaseID,
                milestoneText: nil,
                notes: "",
                mood: nil
            )
        }
    }
    
    private func getCurrentSessionDurationMinutes() -> Int {
        guard let startTime = sessionStartTime else { return 0 }
        let durationMs = Date().timeIntervalSince(startTime)
        return Int(round(durationMs / 60))
    }
    
    // MARK: - CSV file path
    private let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    private let jujuPath: URL?
    private let dataFileURL: URL?
    
    // Public access to jujuPath for migration and validation
    var jujuPathForMigration: URL? {
        return jujuPath
    }
    
    // MARK: - Component Managers (Internal)
    private let sessionFileManager: SessionFileManager
    private let csvManager: SessionCSVManager
    private let parser: SessionDataParser
    
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
        self.csvManager = SessionCSVManager(fileManager: sessionFileManager, jujuPath: jujuPath)
        self.parser = SessionDataParser()
        
        // Ensure data directory exists
        csvManager.ensureDataDirectoryExists()
        
        // Setup observers
        setupObservers()
        
        // Run migration if necessary (async, non-blocking)
        Task {
            let migrationManager = SessionMigrationManager(sessionFileManager: sessionFileManager, jujuPath: jujuPath)
            _ = await migrationManager.migrateIfNecessary()
            
            // After migration, run data validation and auto-repair
            await self.runDataValidationAndRepair()
        }
    }
    
    private func setupObservers() {
        // Observe data manager changes and propagate to main manager
        NotificationCenter.default.addObserver(
            forName: Notification.Name("sessionDidEnd"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.lastUpdated = Date()
            }
        }
        
        // Observe when sessions are loaded from file
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("sessionsDidLoad"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.lastUpdated = Date()
            }
        }
    }
    
    // MARK: - Session State Management
    
    func startSession(for projectName: String, projectID: String? = nil) {
        guard !isSessionActive else {
            return
        }
        
        isSessionActive = true
        currentProjectName = projectName
        currentProjectID = projectID
        currentActivityTypeID = nil
        currentProjectPhaseID = nil
        sessionStartTime = Date()
        
        // Notify that session started
        NotificationCenter.default.post(name: .sessionDidStart, object: nil)
    }
    
    func endSession(
        notes: String = "",
        mood: Int? = nil,
        activityTypeID: String? = nil,
        projectPhaseID: String? = nil,
        milestoneText: String? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard isSessionActive, let projectName = currentProjectName, let startTime = sessionStartTime else {
            completion?(false)
            return
        }
        
        let endTime = Date()
        let durationMs = endTime.timeIntervalSince(startTime)
        let durationMinutes = Int(round(durationMs / 60))
        
        // Create session data with new fields
        guard let projectID = currentProjectID else {
            completion?(false)
            return
        }
        
        let sessionData = SessionData(
            startTime: startTime,
            endTime: endTime,
            projectID: projectID,
            activityTypeID: activityTypeID,
            projectPhaseID: projectPhaseID,
            milestoneText: milestoneText,
            notes: notes
        )
        
        // Save to CSV with file locking
        saveSessionToCSV(sessionData, mood: mood) { [weak self] success in
            guard let self = self else { 
                completion?(false)
                return 
            }
            
            if success {
                // Reset state first
                self.isSessionActive = false
                self.currentProjectName = nil
                self.currentProjectID = nil
                self.currentActivityTypeID = nil
                self.currentProjectPhaseID = nil
                self.sessionStartTime = nil
                
                // Update timestamp to trigger UI refresh
                self.lastUpdated = Date()
                
                // Notify that session ended (after state is reset)
                NotificationCenter.default.post(name: .sessionDidEnd, object: nil)
            }
            
            completion?(success)
        }
    }
    
    func getCurrentSessionDuration() -> String {
        guard isSessionActive, let startTime = sessionStartTime else {
            return "0h 0m"
        }
        
        let durationMs = Date().timeIntervalSince(startTime)
        let totalSeconds = Int(durationMs)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        return "\(hours)h \(minutes)m"
    }
    
    // MARK: - Session Data Operations
    
    func loadAllSessions() async -> [SessionRecord] {
        let availableYears = csvManager.getAvailableYears()
        
        if availableYears.isEmpty {
            if let legacyURL = dataFileURL, FileManager.default.fileExists(atPath: legacyURL.path) {
                let sessions = loadSessionsFromLegacyFile(legacyURL)
                await MainActor.run { [weak self] in
                    self?.allSessions = sessions
                    self?.lastUpdated = Date()
                }
                return sessions
            }
            await MainActor.run { [weak self] in
                self?.allSessions = []
                self?.lastUpdated = Date()
            }
            return []
        }
        
        let loadedSessions = await withTaskGroup(of: [SessionRecord].self) { group in
            for year in availableYears {
                group.addTask { [weak self] in
                    guard let self = self else { return [] }
                    do {
                        let content = try await self.csvManager.readFromYearFile(for: year)
                        let hasIdColumn = content.lowercased().contains("id")
                        let (sessions, needsRewrite) = self.parser.parseSessionsFromCSV(content, hasIdColumn: hasIdColumn)
                        if needsRewrite {
                            let csvContent = self.parser.convertSessionsToCSV(sessions)
                            try await self.csvManager.writeToYearFile(csvContent, for: year)
                        }
                        return sessions
                    } catch { return [] }
                }
            }
            var all: [SessionRecord] = []
            for await sessions in group { all.append(contentsOf: sessions) }
            return all
        }
        
        let sorted = loadedSessions.sorted { $0.startDate > $1.startDate }
        await MainActor.run { [weak self] in
            self?.allSessions = sorted
            self?.lastUpdated = Date()
            NotificationCenter.default.post(name: NSNotification.Name("sessionsDidLoad"), object: nil, userInfo: ["sessionCount": sorted.count])
        }
        return sorted
    }
    
    private func loadSessionsFromLegacyFile(_ url: URL) -> [SessionRecord] {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let hasIdColumn = content.lowercased().contains("id")
            let (sessions, _) = parser.parseSessionsFromCSV(content, hasIdColumn: hasIdColumn)
            return sessions
        } catch { return [] }
    }
    
    func loadSessions(in dateInterval: DateInterval?) async -> [SessionRecord] {
        guard let interval = dateInterval else { return await loadAllSessions() }
        
        let startYear = Calendar.current.component(.year, from: interval.start)
        let endYear = Calendar.current.component(.year, from: interval.end)
        let yearsToLoad = csvManager.getAvailableYears().filter { $0 >= startYear && $0 <= endYear }
        
        if yearsToLoad.isEmpty { return [] }
        
        let query = SessionQuery(dateInterval: interval)
        
        let loadedSessions = await withTaskGroup(of: [SessionRecord].self) { group in
            for year in yearsToLoad {
                group.addTask { [weak self] in
                    guard let self = self else { return [] }
                    do {
                        let content = try await self.csvManager.readFromYearFile(for: year)
                        return self.parser.parseSessionsFromCSVWithQuery(content, query: query)
                    } catch { return [] }
                }
            }
            var all: [SessionRecord] = []
            for await sessions in group { all.append(contentsOf: sessions) }
            return all
        }
        
        let sorted = loadedSessions.sorted { $0.startDate > $1.startDate }
        await MainActor.run { [weak self] in
            self?.allSessions = sorted
            self?.lastUpdated = Date()
            NotificationCenter.default.post(name: NSNotification.Name("sessionsDidLoad"), object: nil, userInfo: ["sessionCount": sorted.count])
        }
        ProjectManager.shared.updateAllProjectStatistics()
        return sorted
    }
    
    func loadCurrentWeekSessions() async {
        let query = SessionQuery.currentWeek()
        let currentYear = Calendar.current.component(.year, from: Date())
        
        do {
            let content = try await csvManager.readFromYearFile(for: currentYear)
            let sessions = parser.parseSessionsFromCSVWithQuery(content, query: query)
            
            allSessions = sessions.sorted { $0.startDate > $1.startDate }
            lastUpdated = Date()
            NotificationCenter.default.post(name: NSNotification.Name("sessionsDidLoad"), object: nil, userInfo: ["sessionCount": sessions.count])
        } catch {}
    }
    
    func loadCurrentYearSessions() async -> [SessionRecord] {
        let query = SessionQuery.currentYear()
        let currentYear = Calendar.current.component(.year, from: Date())
        
        do {
            let content = try await csvManager.readFromYearFile(for: currentYear)
            let sessions = parser.parseSessionsFromCSVWithQuery(content, query: query)
            
            let sortedSessions = sessions.sorted { $0.startDate > $1.startDate }
            allSessions = sortedSessions
            lastUpdated = Date()
            NotificationCenter.default.post(name: NSNotification.Name("sessionsDidLoad"), object: nil, userInfo: ["sessionCount": sessions.count])
            return sortedSessions
        } catch {
            return []
        }
    }
    
    func updateSession(id: String, field: String, value: String) -> Bool {
        guard let session = allSessions.first(where: { $0.id == id }) else { return false }
        var updated = session
        switch field {
        case "notes": updated = SessionRecord(id: session.id, startDate: session.startDate, endDate: session.endDate, projectID: session.projectID, activityTypeID: session.activityTypeID, projectPhaseID: session.projectPhaseID, milestoneText: session.milestoneText, notes: value, mood: session.mood)
        case "mood": 
            if let m = Int(value) {
                updated = SessionRecord(id: session.id, startDate: session.startDate, endDate: session.endDate, projectID: session.projectID, activityTypeID: session.activityTypeID, projectPhaseID: session.projectPhaseID, milestoneText: session.milestoneText, notes: session.notes, mood: m)
            }
        default: return false
        }
        if let idx = allSessions.firstIndex(where: { $0.id == id }) {
            allSessions[idx] = updated
            saveAllSessions(allSessions)
            lastUpdated = Date()
            NotificationCenter.default.post(name: .sessionDidEnd, object: nil, userInfo: ["sessionID": id])
            return true
        }
        return false
    }
    
    func updateSessionFull(id: String, date: String, startTime: String, endTime: String, projectName: String, notes: String, mood: Int?, activityTypeID: String? = nil, projectPhaseID: String? = nil, milestoneText: String? = nil, projectID: String? = nil) -> Bool {
        guard let session = allSessions.first(where: { $0.id == id }) else { return false }
        
        let projects = ProjectManager.shared.loadProjects()
        let resolvedProjectID: String
        if let pid = projectID, !pid.isEmpty {
            resolvedProjectID = pid
        } else {
            resolvedProjectID = projects.first { $0.name == projectName }?.id ?? session.projectID
        }
        
        guard !resolvedProjectID.isEmpty else { return false }
        
        // Parse the date string
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let parsedDate = dateFormatter.date(from: date) else { return false }
        
        // Combine date with start time using direct logic
        let startDate = combineDateWithTimeString(parsedDate, timeString: startTime)
        
        // Combine date with end time using direct logic
        let endDate = combineDateWithTimeString(parsedDate, timeString: endTime)
        
        // Handle midnight sessions (end time before start time means next day)
        var finalEndDate = endDate
        if endDate < startDate, let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: endDate) {
            finalEndDate = nextDay
        }
        
        let updated = SessionRecord(
            id: session.id,
            startDate: startDate,
            endDate: finalEndDate,
            projectID: resolvedProjectID,
            activityTypeID: activityTypeID ?? session.activityTypeID,
            projectPhaseID: projectPhaseID,
            milestoneText: milestoneText ?? session.milestoneText,
            notes: notes,
            mood: mood
        )
        
        if let idx = allSessions.firstIndex(where: { $0.id == id }) {
            allSessions[idx] = updated
            saveAllSessions(allSessions)
            lastUpdated = Date()
            NotificationCenter.default.post(name: .sessionDidEnd, object: nil, userInfo: ["sessionID": id])
            return true
        }
        return false
    }
    
    func deleteSession(id: String) -> Bool {
        guard allSessions.contains(where: { $0.id == id }) else { return false }
        allSessions.removeAll { $0.id == id }
        saveAllSessions(allSessions)
        lastUpdated = Date()
        return true
    }
    
    func exportSessions(_ sessions: [SessionRecord], format: String, fileName: String? = nil) -> URL? {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        let baseName = fileName ?? "juju_sessions"
        let content = parser.convertSessionsToCSVForExport(sessions, format: format)
        
        guard format == "csv" || format == "txt" || format == "md" else { return nil }
        let path = downloads?.appendingPathComponent("\(baseName).\(format)") ?? URL(fileURLWithPath: "\(baseName).\(format)")
        try? content.write(to: path, atomically: true, encoding: .utf8)
        return path
    }
    
    func saveAllSessions(_ sessions: [SessionRecord]) {
        var sessionsByYear: [Int: [SessionRecord]] = [:]
        for session in sessions {
            let year = Calendar.current.component(.year, from: session.startDate)
            sessionsByYear[year, default: []].append(session)
        }
        
        Task { [sessionsByYear] in
            for year in sessionsByYear.keys.sorted() {
                guard let yearSessions = sessionsByYear[year] else { continue }
                do {
                    let csvContent = parser.convertSessionsToCSV(yearSessions)
                    try await self.csvManager.writeToYearFile(csvContent, for: year)
                } catch {}
            }
            await MainActor.run { [weak self] in self?.lastUpdated = Date() }
        }
    }
    
    // MARK: - CSV Operations
    
    private func saveSessionToCSV(_ sessionData: SessionData, mood: Int? = nil, completion: @escaping (Bool) -> Void) {
        // Format the CSV row using full Date objects (new format)
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let id = UUID().uuidString
        let startDateStr = dateTimeFormatter.string(from: sessionData.startTime)
        let endDateStr = dateTimeFormatter.string(from: sessionData.endTime)
        let moodStr = mood.map { String($0) } ?? ""
        
        // Build CSV row with NEW format (without projectName field)
        let projectID = csvManager.csvEscape(sessionData.projectID)
        let activityTypeID = sessionData.activityTypeID.map { csvManager.csvEscape($0) } ?? ""
        let projectPhaseID = sessionData.projectPhaseID.map { csvManager.csvEscape($0) } ?? ""
        let milestoneText = sessionData.milestoneText.map { csvManager.csvEscape($0) } ?? ""
        
        // NEW FORMAT: id,start_date,end_date,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
        let csvRow = "\(id),\(startDateStr),\(endDateStr),\(projectID),\(activityTypeID),\(projectPhaseID),\(milestoneText),\(csvManager.csvEscape(sessionData.notes)),\(moodStr)\n"
        
        // Determine year from session start date
        let year = Calendar.current.component(.year, from: sessionData.startTime)
        
        Task {
            do {
                try await csvManager.appendToYearFile(csvRow, for: year)
                
                await MainActor.run {
                    completion(true)
                }
            } catch {
                await MainActor.run {
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Utility Functions
    
    /// Combine a date with a time string to create a full Date object
    /// This method handles the date/time combination logic that was previously in SessionDataParser
    private func combineDateWithTimeString(_ date: Date, timeString: String) -> Date {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let paddedTimeString = timeString.count == 5 ? timeString + ":00" : timeString
        
        guard let timeDate = timeFormatter.date(from: paddedTimeString) else {
            return date
        }
        
        let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: timeDate)
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second
        
        return Calendar.current.date(from: combined) ?? date
    }
    
    // MARK: - Data Validation and Repair
    
    /// Run data validation and automatic repair if needed
    private func runDataValidationAndRepair() async {
        let validator = DataValidator.shared
        
        // Run integrity check
        let errors = validator.runIntegrityCheck()
        
        if !errors.isEmpty {
            for error in errors {
                print("  - \(error)")
            }
            
            // Attempt automatic repair
            let repairs = validator.autoRepairIssues()
            
            if !repairs.isEmpty {
                for repair in repairs {
                    print("  - \(repair)")
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
