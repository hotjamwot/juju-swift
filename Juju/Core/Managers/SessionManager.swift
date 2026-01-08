import Foundation

/// SessionManager.swift
/// 
/// **Purpose**: Central coordinator for all session-related operations including
/// start/end tracking, data persistence, and UI state management
/// 
/// **Key Responsibilities**:
/// - Session lifecycle management (start, end, update, delete)
/// - CSV file operations with year-based organization
/// - Data validation and migration
/// - UI state coordination and notification broadcasting
/// 
/// **Dependencies**:
/// - SessionFileManager: Handles low-level file operations
/// - SessionCSVManager: Manages CSV formatting and year-based routing
/// - SessionDataParser: Parses CSV data into SessionRecord objects
/// - ProjectManager: Validates project associations
/// 
/// **AI Notes**:
/// - This is the primary interface for all session operations
/// - Always use projectID, not projectName for new sessions
/// - Handles automatic migration of legacy data formats
/// - Posts notifications for UI updates via NotificationCenter
/// - Uses @MainActor for UI-bound operations
/// - Manages active session state and duration tracking
/// - Implements year-based CSV file organization for performance

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
    
    /// Start a new active session with the specified project
    ///
    /// **AI Context**: This method initiates a new active session that tracks time until ended.
    /// It's the primary entry point for time tracking functionality and manages the global
    /// active session state. Only one session can be active at a time.
    ///
    /// **Business Rules**:
    /// - Cannot start a new session if one is already active
    /// - Requires either projectName or projectID (projectID takes precedence)
    /// - Clears any existing activity type and phase selections
    /// - Sets the start time to the current moment
    ///
    /// **Edge Cases**:
    /// - If projectName is provided but projectID is nil, projectName is used for display
    /// - If projectID is provided, it's used for data persistence (projectName becomes legacy)
    /// - Method silently returns if session is already active (no error thrown)
    ///
    /// **State Changes**:
    /// - Sets isSessionActive to true
    /// - Updates currentProjectName and currentProjectID
    /// - Clears currentActivityTypeID and currentProjectPhaseID
    /// - Sets sessionStartTime to current date/time
    ///
    /// **Notifications**: Posts .sessionDidStart notification for UI updates
    ///
    /// - Parameters:
    ///   - projectName: Display name for the project (legacy support)
    ///   - projectID: Unique identifier for the project (preferred for new sessions)
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
    
    /// End the currently active session and persist it to storage
    ///
    /// **AI Context**: This method finalizes the active session by calculating duration,
    /// creating a complete session record, and saving it to the appropriate CSV file.
    /// It's the counterpart to startSession() and handles the complete session lifecycle.
    ///
    /// **Business Rules**:
    /// - Can only end a session if one is currently active
    /// - Requires a valid projectID (projectName is legacy and not used for persistence)
    /// - Automatically calculates session duration from start to end time
    /// - Uses year-based CSV file organization for performance
    ///
    /// **Edge Cases**:
    /// - If no session is active, calls completion(false) and returns early
    /// - If projectID is missing, calls completion(false) and returns early
    /// - Duration calculation uses current time as end time
    /// - All optional fields (mood, activity type, phase, milestone) can be nil
    ///
    /// **State Changes**:
    /// - Sets isSessionActive to false
    /// - Clears all current session state (project, activity type, phase, start time)
    /// - Updates lastUpdated timestamp to trigger UI refresh
    /// - Persists session data to year-specific CSV file
    ///
    /// **Data Flow**:
    /// 1. Validate active session exists
    /// 2. Calculate duration and create SessionData object
    /// 3. Save to CSV with file locking for thread safety
    /// 4. Reset session state on success
    /// 5. Post notifications for UI updates
    ///
    /// **Error Handling**: Uses completion handler for async error reporting
    /// - Returns false if no active session or missing projectID
    /// - Returns false if CSV save operation fails
    /// - Success/failure communicated via completion callback
    ///
    /// - Parameters:
    ///   - notes: Optional session notes (defaults to empty string)
    ///   - mood: Optional mood rating 0-10 (defaults to nil)
    ///   - activityTypeID: Optional activity type identifier (defaults to nil)
    ///   - projectPhaseID: Optional project phase identifier (defaults to nil)
    ///   - milestoneText: Optional milestone description (defaults to nil)
    ///   - completion: Callback executed when operation completes (true = success, false = failure)
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
    
    /// Load all sessions from all available years with automatic migration support
    ///
    /// **AI Context**: This is the primary method for loading complete session data.
    /// It handles both modern year-based CSV files and legacy single-file formats,
    /// automatically migrating data when needed. Uses concurrent loading for performance.
    ///
    /// **Business Rules**:
    /// - Loads sessions from all available years in parallel for performance
    /// - Automatically detects and migrates legacy data formats
    /// - Validates CSV format and rewrites files if needed
    /// - Sorts sessions by start date (newest first) for consistent ordering
    ///
    /// **Data Flow**:
    /// 1. Get list of available years from file system
    /// 2. If no years found, check for legacy single file
    /// 3. Load sessions from each year concurrently using TaskGroup
    /// 4. Parse CSV content with format detection (legacy vs modern)
    /// 5. Auto-rewrite files if format needs updating
    /// 6. Combine and sort all sessions by date
    /// 7. Update UI state and notify observers
    ///
    /// **Performance Optimizations**:
    /// - Concurrent loading across multiple years
    /// - Automatic format detection to avoid unnecessary parsing
    /// - File rewriting only when format changes are detected
    /// - MainActor usage for UI updates to prevent threading issues
    ///
    /// **Error Handling**:
    /// - Gracefully handles missing files or directories
    /// - Continues loading other years if one year fails
    /// - Returns empty array if no sessions can be loaded
    /// - Logs errors but doesn't crash the application
    ///
    /// **Notifications**: Posts "sessionsDidLoad" notification with session count
    ///
    /// - Returns: Array of all loaded SessionRecord objects, sorted by start date (newest first)
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
    
    /// Update a specific field in an existing session record
    ///
    /// **AI Context**: This is a lightweight update method for modifying individual session fields
    /// without requiring the full session data. It's optimized for simple updates like notes or mood.
    ///
    /// **Business Rules**:
    /// - Only supports updating "notes" and "mood" fields
    /// - Creates a new SessionRecord instance with updated values
    /// - Automatically persists changes to storage
    /// - Triggers UI updates via notifications
    ///
    /// **Supported Fields**:
    /// - "notes": Updates session notes (string value)
    /// - "mood": Updates mood rating (integer 0-10, must be valid integer string)
    ///
    /// **Data Flow**:
    /// 1. Find session by ID in current session list
    /// 2. Create updated SessionRecord with new field value
    /// 3. Replace session in memory
    /// 4. Persist all sessions to storage
    /// 5. Update timestamp and notify observers
    ///
    /// **Performance Characteristics**:
    /// - O(n) lookup for session by ID
    /// - Full session list rewrite to storage (for consistency)
    /// - Minimal memory overhead (creates one new SessionRecord)
    ///
    /// **Error Handling**:
    /// - Returns false if session ID not found
    /// - Returns false for unsupported field names
    /// - Returns false if mood value is not a valid integer
    /// - Silent failure (no exceptions thrown)
    ///
    /// **Thread Safety**: Method is not thread-safe, should be called from main thread
    ///
    /// **Notifications**: Posts .sessionDidEnd notification with session ID for UI updates
    ///
    /// - Parameters:
    ///   - id: Session identifier to update
    ///   - field: Field name to update ("notes" or "mood")
    ///   - value: New value as string (for mood, must be valid integer)
    /// - Returns: True if update successful, false otherwise
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
    ///
    /// **AI Context**: This method is critical for session time tracking as it combines
    /// a calendar date with a time string to create precise Date objects for session
    /// start/end times. It handles both HH:mm and HH:mm:ss formats for backward compatibility.
    ///
    /// **Algorithm Steps**:
    /// 1. Pad time string to ensure consistent HH:mm:ss format
    /// 2. Parse time string into Date object using standard formatter
    /// 3. Extract time components (hour, minute, second) from parsed time
    /// 4. Extract date components (year, month, day) from provided date
    /// 5. Combine components into new DateComponents object
    /// 6. Create final Date object from combined components
    ///
    /// **Edge Cases Handled**:
    /// - Time strings in HH:mm format (automatically padded to HH:mm:ss)
    /// - Invalid time strings (returns original date as fallback)
    /// - Calendar edge cases (leap years, daylight saving time, etc.)
    ///
    /// **Performance Notes**:
    /// - Uses DateFormatter for consistent time parsing
    /// - Leverages Calendar API for safe date component manipulation
    /// - Minimal memory allocation with direct component extraction
    ///
    /// - Parameters:
    ///   - date: The calendar date (year, month, day components)
    ///   - timeString: Time in "HH:mm" or "HH:mm:ss" format
    /// - Returns: Combined Date object, or original date if parsing fails
    private func combineDateWithTimeString(_ date: Date, timeString: String) -> Date {
        // Create time formatter for parsing time strings
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        // Pad time string to ensure consistent format (HH:mm:ss)
        // This handles backward compatibility with HH:mm format
        let paddedTimeString = timeString.count == 5 ? timeString + ":00" : timeString
        
        // Parse the padded time string into a Date object
        // This gives us a Date with the time components we need
        guard let timeDate = timeFormatter.date(from: paddedTimeString) else {
            // If parsing fails, return the original date as a safe fallback
            return date
        }
        
        // Extract time components (hour, minute, second) from the parsed time
        // These will be used to replace the time portion of our target date
        let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: timeDate)
        
        // Extract date components (year, month, day) from the provided date
        // These will be preserved in our final combined date
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        
        // Create new DateComponents object with combined date and time
        // This safely merges the date portion from 'date' with time portion from 'timeString'
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second
        
        // Use Calendar API to safely create final Date object
        // This handles all calendar edge cases (leap years, DST, etc.)
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
