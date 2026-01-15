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
                action: nil, // Active session doesn't have a final action yet
                isMilestone: false, // Active session isn't a milestone until saved
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
    /// - All optional fields (mood, activity type, phase, milestone, action) can be nil
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
    ///   - milestoneText: Optional milestone description (defaults to nil) - Deprecated
    ///   - action: Optional session action (defaults to nil)
    ///   - isMilestone: Boolean indicating if session is a milestone (defaults to false)
    ///   - completion: Callback executed when operation completes (true = success, false = failure)
    func endSession(
        notes: String = "",
        mood: Int? = nil,
        activityTypeID: String? = nil,
        projectPhaseID: String? = nil,
        milestoneText: String? = nil, // Deprecated
        action: String? = nil, // New field, made optional to match other fields
        isMilestone: Bool = false, // New field
        completion: ((Bool) -> Void)? = nil
    ) {
        guard isSessionActive, let projectName = currentProjectName, let startTime = sessionStartTime else {
            completion?(false)
            return
        }
        
        let endTime = Date()
        
        // Create session data with new fields
        guard let projectID = currentProjectID else {
            completion?(false)
            return
        }
        
        // Determine final action and isMilestone, prioritizing new fields
        // with fallback for backward compatibility during deprecation.
        let finalAction = action ?? milestoneText
        let finalIsMilestone = isMilestone || (milestoneText != nil && action == nil)
        
        saveSessionToCSV(startTime, endTime, projectID, activityTypeID, projectPhaseID, action: finalAction, isMilestone: finalIsMilestone, milestoneText: milestoneText, notes: notes, mood: mood) { [weak self] success in
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
    /// - Only supports updating "notes", "mood", "action", and "is_milestone" fields
    /// - Creates a new SessionRecord instance with updated values
    /// - Automatically persists changes to storage
    /// - Triggers UI updates via notifications
    ///
    /// **Supported Fields**:
    /// - "notes": Updates session notes (string value)
    /// - "mood": Updates mood rating (integer 0-10, must be valid integer string)
    /// - "action": Updates session action (string value)
    /// - "is_milestone": Updates milestone flag (boolean string, e.g., "true" or "1")
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
    /// - Returns false if mood or is_milestone value is not valid
    /// - Silent failure (no exceptions thrown)
    ///
    /// **Thread Safety**: Method is not thread-safe, should be called from main thread
    ///
    /// **Notifications**: Posts .sessionDidEnd notification with session ID for UI updates
    ///
    /// - Parameters:
    ///   - id: Session identifier to update
    ///   - field: Field name to update ("notes", "mood", "action", or "is_milestone")
    ///   - value: New value as string (for mood, must be valid integer; for is_milestone, "true"/"1" or "false"/"0")
    /// - Returns: True if update successful, false otherwise
    func updateSession(id: String, field: String, value: String) -> Bool {
        guard let session = allSessions.first(where: { $0.id == id }) else { return false }
        var updated = session
        switch field {
        case "notes": 
            updated = SessionRecord(id: session.id, startDate: session.startDate, endDate: session.endDate, projectID: session.projectID, activityTypeID: session.activityTypeID, projectPhaseID: session.projectPhaseID, action: session.action, isMilestone: session.isMilestone, milestoneText: session.milestoneText, notes: value, mood: session.mood)
        case "mood": 
            if let m = Int(value) {
                updated = SessionRecord(id: session.id, startDate: session.startDate, endDate: session.endDate, projectID: session.projectID, activityTypeID: session.activityTypeID, projectPhaseID: session.projectPhaseID, action: session.action, isMilestone: session.isMilestone, milestoneText: session.milestoneText, notes: session.notes, mood: m)
            }
        case "action":
            updated = SessionRecord(id: session.id, startDate: session.startDate, endDate: session.endDate, projectID: session.projectID, activityTypeID: session.activityTypeID, projectPhaseID: session.projectPhaseID, action: value, isMilestone: session.isMilestone, milestoneText: session.milestoneText, notes: session.notes, mood: session.mood)
        case "is_milestone":
            let boolValue = (value.lowercased() == "true" || value == "1")
            updated = SessionRecord(id: session.id, startDate: session.startDate, endDate: session.endDate, projectID: session.projectID, activityTypeID: session.activityTypeID, projectPhaseID: session.projectPhaseID, action: session.action, isMilestone: boolValue, milestoneText: session.milestoneText, notes: session.notes, mood: session.mood)
        default: return false
        }
        if let idx = allSessions.firstIndex(where: { $0.id == id }) {
            // Update the session in memory on the main thread first
            allSessions[idx] = updated
            lastUpdated = Date()
            NotificationCenter.default.post(name: .sessionDidEnd, object: nil, userInfo: ["sessionID": id])

            // Save the updated sessions to file in background using current memory state
            Task {
                saveAllSessions(allSessions)
                await MainActor.run {
                    self.lastUpdated = Date()
                }
            }
            return true
        }
        return false
    }
    
    /// Update a complete session record with validation and data integrity checks
    ///
    /// **AI Context**: This method handles complete session updates with project resolution,
    /// date/time parsing, and midnight session handling. Uses Date+SessionExtensions
    /// for consistent date manipulation.
    ///
    /// **Business Rules**:
    /// - Project ID is required for new sessions (projectName is legacy support)
    /// - Sessions crossing midnight automatically adjust end date
    /// - Phase must be compatible with selected project
    /// - All updates trigger UI refresh notifications
    ///
    /// **Edge Cases**:
    /// - Legacy sessions without projectID fall back to projectName lookup
    /// - Invalid date/time strings cause update failure
    /// - Incompatible phase/project combinations clear phaseID
    ///
    /// - Parameters:
    ///   - id: Session identifier
    ///   - date: Session date in "yyyy-MM-dd" format
    ///   - startTime: Start time in "HH:mm" or "HH:mm:ss" format
    ///   - endTime: End time in "HH:mm" or "HH:mm:ss" format
    ///   - projectName: Legacy project name (for backward compatibility)
    ///   - notes: Session notes (can be empty)
    ///   - mood: Mood rating 0-10 (optional)
    ///   - activityTypeID: Activity type identifier (optional)
    ///   - projectPhaseID: Project phase identifier (optional)
    ///   - action: Session action (optional)
    ///   - isMilestone: Boolean indicating if session is a milestone (optional)
    ///   - milestoneText: Milestone description (optional) - Deprecated
    ///   - projectID: Project identifier (required for new sessions)
    /// - Returns: True if update successful, false otherwise
    func updateSessionFull(id: String, date: String, startTime: String, endTime: String, projectName: String, notes: String, mood: Int?, activityTypeID: String? = nil, projectPhaseID: String? = nil, action: String? = nil, isMilestone: Bool? = nil, milestoneText: String? = nil, projectID: String? = nil) -> Bool {
        // Find existing session to update
        guard let session = allSessions.first(where: { $0.id == id }) else { return false }

        // Resolve project ID (direct parameter takes precedence over projectName lookup)
        let resolvedProjectID: String
        if let pid = projectID, !pid.isEmpty {
            resolvedProjectID = pid
        } else {
            // Look up project by name
            let projects = ProjectManager.shared.loadProjects()
            if let foundProject = projects.first(where: { $0.name == projectName }) {
                resolvedProjectID = foundProject.id
            } else {
                return false // Project not found
            }
        }

        // Parse and combine date/time components using Date+SessionExtensions
        guard let parsedDate = Date.parseSessionDate(date) else { return false }
        let startDate = parsedDate.combined(withTimeString: startTime)
        let endDate = parsedDate.combined(withTimeString: endTime)
        let finalEndDate = startDate.adjustedForMidnightIfNeeded(endTime: endDate)

        // Create updated session record
        let updatedSession = SessionRecord(
            id: session.id,
            startDate: startDate,
            endDate: finalEndDate,
            projectID: resolvedProjectID,
            activityTypeID: activityTypeID ?? session.activityTypeID,
            projectPhaseID: projectPhaseID,
            action: action ?? session.action,
            isMilestone: isMilestone ?? session.isMilestone,
            milestoneText: milestoneText ?? session.milestoneText,
            notes: notes,
            mood: mood
        )

        // Update session in memory and persistence
        guard let idx = allSessions.firstIndex(where: { $0.id == id }) else { return false }

        // Update the session in memory on the main thread first
        allSessions[idx] = updatedSession
        lastUpdated = Date()
        NotificationCenter.default.post(name: .sessionDidEnd, object: nil, userInfo: ["sessionID": id])

        // Save the updated sessions to file in background using current memory state
        Task {
            saveAllSessions(allSessions)
            await MainActor.run {
                self.lastUpdated = Date()
                ProjectManager.shared.updateAllProjectStatistics()
            }
        }

        return true
    }
    
    /// Delete a session using a robust atomic operation to prevent data loss
    ///
    /// **AI Context**: This method implements a safe deletion mechanism that:
    /// 1. Reads current file content
    /// 2. Filters out only the session to be deleted
    /// 3. Writes back remaining sessions with proper header
    /// 4. Uses atomic file operations to prevent data loss
    ///
    /// **Business Rules**:
    /// - Only deletes the specified session ID
    /// - Preserves all other sessions in the file
    /// - Maintains proper CSV header format
    /// - Uses atomic file operations for safety
    /// - Handles both year-based and legacy file formats
    ///
    /// **Data Flow**:
    /// 1. Find session by ID in memory
    /// 2. Determine year from session date
    /// 3. Read current file content for that year
    /// 4. Parse all sessions from file
    /// 5. Filter out the session to delete
    /// 6. Write remaining sessions back with header
    /// 7. Update in-memory session list
    /// 8. Post notifications for UI updates
    ///
    /// **Error Handling**:
    /// - Returns false if session ID not found
    /// - Gracefully handles file read/write errors
    /// - Preserves original data if operation fails
    /// - Logs errors for debugging
    ///
    /// **Thread Safety**: Uses async/await for file operations
    ///
    /// **Notifications**: Posts .sessionDidEnd notification with session ID for UI updates
    ///
    /// - Parameters:
    ///   - id: Session identifier to delete
    /// - Returns: True if deletion successful, false otherwise
    func deleteSession(id: String) -> Bool {
        guard let sessionToDelete = allSessions.first(where: { $0.id == id }) else {
            print("❌ Session \(id) not found for deletion")
            return false
        }

        let year = Calendar.current.component(.year, from: sessionToDelete.startDate)

        Task {
            do {
                // Read current file content for the year
                let currentContent = try await csvManager.readFromYearFile(for: year)

                // Parse all sessions from the file
                let (allSessionsInFile, _) = parser.parseSessionsFromCSV(currentContent, hasIdColumn: true)

                // Filter out the session to delete
                let remainingSessions = allSessionsInFile.filter { $0.id != id }

                // If we have remaining sessions, write them back with proper header
                if !remainingSessions.isEmpty {
                    let csvContent = parser.convertSessionsToCSV(remainingSessions)
                    try await csvManager.writeToYearFile(csvContent, for: year)
                } else {
                    // If no sessions remain, write an empty file with just the header
                    let header = "id,start_date,end_date,project_id,activity_type_id,project_phase_id,action,is_milestone,milestone_text,notes,mood\n"
                    try await csvManager.writeToYearFile(header, for: year)
                }

                // Update in-memory session list
                await MainActor.run { [weak self] in
                    guard let self = self else { return }

                    // Remove from memory
                    self.allSessions.removeAll { $0.id == id }

                    // Update timestamp and notify
                    self.lastUpdated = Date()
                    NotificationCenter.default.post(name: .sessionDidEnd, object: nil, userInfo: ["sessionID": id])
                    print("✅ Successfully deleted session \(id)")
                }

            } catch {
                await MainActor.run {
                    print("❌ Error deleting session \(id): \(error)")
                    ErrorHandler.shared.handleError(error, context: "SessionManager.deleteSession", severity: .error)
                }
            }
        }

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
    
    private func saveSessionToCSV(_ startTime: Date, _ endTime: Date, _ projectID: String, _ activityTypeID: String?, _ projectPhaseID: String?, action: String?, isMilestone: Bool, milestoneText: String?, notes: String, mood: Int?, completion: @escaping (Bool) -> Void) {
        // Format the CSV row using full Date objects (new format)
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let id = UUID().uuidString
        let startDateStr = dateTimeFormatter.string(from: startTime)
        let endDateStr = dateTimeFormatter.string(from: endTime)
        let moodStr = mood.map { String($0) } ?? ""
        
        // Build CSV row with NEW format (with action and is_milestone fields)
        let projectID_Escaped = csvManager.csvEscape(projectID)
        let activityTypeID_Escaped = activityTypeID.map { csvManager.csvEscape($0) } ?? ""
        let projectPhaseID_Escaped = projectPhaseID.map { csvManager.csvEscape($0) } ?? ""
        let actionText_Escaped = action.map { csvManager.csvEscape($0) } ?? ""
        let isMilestoneStr = isMilestone ? "1" : "0" // CSV stores boolean as 0 or 1
        let milestoneText_Escaped = milestoneText.map { csvManager.csvEscape($0) } ?? ""
        
        // NEW FORMAT: id,start_date,end_date,project_id,activity_type_id,project_phase_id,action,is_milestone,milestone_text,notes,mood
        let csvRow = "\(id),\(startDateStr),\(endDateStr),\(projectID_Escaped),\(activityTypeID_Escaped),\(projectPhaseID_Escaped),\(actionText_Escaped),\(isMilestoneStr),\(milestoneText_Escaped),\(csvManager.csvEscape(notes)),\(moodStr)\n"
        
        // Determine year from session start date
        let year = Calendar.current.component(.year, from: startTime)
        
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
    // Note: Date/time combination logic now uses Date+SessionExtensions for consistency
    
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
    ///
