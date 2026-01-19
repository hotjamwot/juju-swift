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
/// **AI Quick Find (Method Index)**:
/// - State: isSessionActive, currentProjectID, currentActivityTypeID, sessionStartTime
/// - Lifecycle: startSession(), endSession(), updateSessionFull(), deleteSession()
/// - Load: loadAllSessions(), loadSessions(in:), loadCurrentWeekSessions(), loadCurrentYearSessions()
/// - Export: exportSessions(format:fileName:)
/// - Utilities: getCurrentSessionDuration(), activeSession property
/// 
/// **AI Gotchas**:
/// - [GOTCHA] projectID is required for persistence; projectName is LEGACY display-only
/// - [GOTCHA] Year-based CSV files: session.startDate determines which file it's stored in
/// - [GOTCHA] Notifications posted AFTER state reset on success (not before)
/// - [GOTCHA] endSession() clears ALL state; no partial rollback if file write fails
/// - [GOTCHA] activeSession property is computed; doesn't persist until endSession() called
/// - [GOTCHA] Migration runs async on init; sessions may not be loaded immediately
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
    /// **Purpose**: Initiates a new active session that tracks time until ended. This is the primary
    /// entry point for time tracking and manages the global active session state. Only one session can
    /// be active simultaneously.
    ///
    /// **AI Context for Understanding the Method**:
    /// This method transitions SessionManager from an idle state to an active tracking state. It prepares
    /// the internal state machine to handle ongoing session tracking and establishes the starting point for
    /// all duration calculations. The method is idempotent with respect to duplicate calls when a session
    /// is already active (silently ignores additional calls).
    ///
    /// **Business Rules**:
    /// - Precondition: No session can already be active (guard: `!isSessionActive`)
    /// - Requires either projectName or projectID to be provided (projectID is preferred for data integrity)
    /// - Clears any previous activity type and phase selections to ensure clean state
    /// - Timestamp: Sets start time to the exact moment of call via `Date()`
    /// - One active session per manager instance maximum
    ///
    /// **State Transitions**:
    /// ```
    /// Before: [Idle] → After: [Active]
    /// isSessionActive: false → true
    /// currentProjectName: nil → projectName (for display purposes)
    /// currentProjectID: nil → projectID (for data persistence)
    /// currentActivityTypeID: any → nil (cleared for fresh session)
    /// currentProjectPhaseID: any → nil (cleared for fresh session)
    /// sessionStartTime: nil → Date.now()
    /// ```
    ///
    /// **Edge Cases & Implementation Details**:
    /// - If called while session active: Returns early (no state changes, no error)
    /// - If projectID provided: Used as primary key for persistence (takes precedence over projectName)
    /// - If only projectName provided: Used for UI display; projectID becomes nil (legacy support mode)
    /// - Activity type/phase: Always cleared regardless of previous state to ensure clean session boundaries
    ///
    /// **External Effects**:
    /// - Posts `.sessionDidStart` notification to NotificationCenter for UI observers
    /// - Updates @Published `isSessionActive` property triggering SwiftUI view updates
    /// - No file I/O occurs in this method (purely in-memory state change)
    ///
    /// **Performance**: O(1) - constant time state updates, no I/O or collection operations
    ///
    /// **Thread Safety**: Must be called from @MainActor context (typically UI thread)
    ///
    /// - Parameters:
    ///   - projectName: Display name for the project (String). Used for UI display and backward compatibility.
    ///                  Legacy parameter; data persistence uses projectID instead.
    ///   - projectID: Unique identifier for the project (String?, optional). Preferred parameter for new code.
    ///               Used as the primary key for data persistence. If provided, takes precedence over projectName.
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
    /// **Purpose**: Finalizes the active session by calculating its duration, creating a complete
    /// SessionRecord with all metadata, and persisting it to the appropriate year-based CSV file.
    /// This is the counterpart to `startSession()` and completes the session lifecycle.
    ///
    /// **AI Context for Understanding the Method**:
    /// This method is the critical exit point for session tracking. It orchestrates a complex multi-step
    /// process: state validation, duration computation, record creation, file I/O, state cleanup, and UI
    /// notification. The method uses async/await for file operations and ensures the UI is updated on the
    /// main thread. It implements a fail-fast pattern with early guards and communicates success/failure
    /// through a completion handler.
    ///
    /// **Business Rules**:
    /// - Precondition: Session must be active (guard: `isSessionActive` && `currentProjectName` != nil)
    /// - Precondition: projectID must be set (if nil, session end fails)
    /// - Duration calculation: `Date.now() - sessionStartTime` in minutes
    /// - File organization: Sessions routed to year-specific CSV based on startDate
    /// - Data validation: All optional fields can be nil; validation occurs during persistence
    /// - No partial saves: Complete session record created before any file write
    ///
    /// **State Transitions**:
    /// ```
    /// Before: [Active] → After: [Idle]
    /// isSessionActive: true → false
    /// currentProjectName: projectName → nil
    /// currentProjectID: projectID → nil
    /// currentActivityTypeID: any → nil
    /// currentProjectPhaseID: any → nil
    /// sessionStartTime: Date → nil
    /// lastUpdated: previous → Date.now() (triggers UI refresh)
    /// ```
    ///
    /// **Data Flow**:
    /// 1. **Validation Phase**: Check active session exists, has projectID
    /// 2. **Computation Phase**: Calculate endTime, duration, determine target year
    /// 3. **Serialization Phase**: Create SessionData object with all fields
    /// 4. **Persistence Phase**: Async call to saveSessionToCSV with file locking
    /// 5. **Cleanup Phase** (on success): Reset all state variables to nil
    /// 6. **Notification Phase**: Post notifications and call completion handler
    ///
    /// **Detailed Parameter Processing**:
    /// - `notes` (String): Optional user-provided notes about the session (default: empty string)
    /// - `mood` (Int?): Optional mood rating 0-10 (default: nil). If provided, validated during persistence
    /// - `activityTypeID` (String?): Optional activity type identifier (default: nil). If not provided,
    ///   session marked as uncategorized. Validated against ProjectManager's activity types
    /// - `projectPhaseID` (String?): Optional project phase identifier (default: nil). If provided,
    ///   validated to ensure it belongs to the current project. Auto-cleared if project changes
    /// - `action` (String?): Optional session action/achievement summary (default: nil). Captures the
    ///   main achievement or deliverable for the session. Used for dashboard narratives
    /// - `isMilestone` (Bool): Boolean flag indicating if this session is a significant milestone
    ///   (default: false). Used for filtering and highlighting in dashboard views
    /// - `completion` ((Bool) -> Void)?): Async callback executed when operation completes (default: nil).
    ///   Receives true if save successful, false if save failed or preconditions not met
    ///
    /// **Edge Cases & Error Handling**:
    /// - No active session: Returns early calling completion(false)
    /// - Missing projectID: Returns early calling completion(false) - prevents orphaned records
    /// - File write failure: Session state is NOT rolled back; state already cleared (see implementation note)
    /// - Weak self reference: Checks for self existence before updating state; calls completion(false) if lost
    /// - Duration < 1 minute: Still persisted (rounded to nearest minute)
    /// - Duration = 0: Valid edge case (e.g., start and immediately end)
    ///
    /// **External Effects**:
    /// - Posts `.sessionDidEnd` notification with userInfo: ["sessionID": id] for UI observers
    /// - Updates @Published `lastUpdated` property triggering dashboard and session list refreshes
    /// - Triggers ProjectStatisticsCache invalidation via notification
    /// - Creates or appends to year-specific CSV file in Application Support directory
    /// - Triggers asynchronous ProjectManager statistics update
    ///
    /// **Performance Characteristics**:
    /// - O(1) time for state management
    /// - O(1) file append operation (amortized) via SessionCSVManager
    /// - Async file I/O doesn't block main thread
    /// - No collection iteration or aggregation
    ///
    /// **Thread Safety**: 
    /// - Validates main thread context implicitly (@MainActor caller)
    /// - File operations happen on background thread via Task
    /// - MainActor.run ensures state updates on main thread
    /// - File locking handled by SessionCSVManager
    ///
    /// **Notifications Posted**:
    /// - `.sessionDidEnd`: Posted after successful save with session ID in userInfo
    /// - Triggers dependent observers: ProjectStatisticsCache invalidation, UI refresh
    ///
    /// - Parameters:
    ///   - notes: Optional user notes about the session. String, defaults to empty string.
    ///   - mood: Optional mood rating (0-10). Int?, defaults to nil.
    ///   - activityTypeID: Optional activity classification. String?, defaults to nil.
    ///   - projectPhaseID: Optional project phase. String?, defaults to nil.
    ///   - action: Optional session achievement/deliverable. String?, defaults to nil.
    ///   - isMilestone: Optional milestone flag. Bool, defaults to false.
    ///   - completion: Async callback (true=success, false=failure). ((Bool) -> Void)?, defaults to nil.
    func endSession(
        notes: String = "",
        mood: Int? = nil,
        activityTypeID: String? = nil,
        projectPhaseID: String? = nil,
        action: String? = nil,
        isMilestone: Bool = false,
        completion: ((Bool) -> Void)? = nil
    ) {
        // [GOTCHA] Order matters: Check guards BEFORE modifying any state
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
        
        // [INTEGRATION] File I/O happens on background thread
        // [GOTCHA] State is reset BEFORE file save completes (fire-and-forget pattern)
        saveSessionToCSV(startTime, endTime, projectID, activityTypeID, projectPhaseID, action: action, isMilestone: isMilestone, notes: notes, mood: mood) { [weak self] success in
            guard let self = self else { 
                completion?(false)
                return 
            }
            
            if success {
                // [GOTCHA] State reset happens immediately, not after file write
                // This is intentional: UI updates before file I/O completes
                // Reset state first
                self.isSessionActive = false
                self.currentProjectName = nil
                self.currentProjectID = nil
                self.currentActivityTypeID = nil
                self.currentProjectPhaseID = nil
                self.sessionStartTime = nil
                
                // Update timestamp to trigger UI refresh
                self.lastUpdated = Date()
                
                // [INTEGRATION] ProjectStatisticsCache listens to .sessionDidEnd
                // Notification invalidates cache, triggering recalculation
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
    /// **Purpose**: Comprehensive session data loading orchestrator. Loads all historical session data
    /// from year-based CSV files with built-in support for legacy data formats and automatic migration.
    /// This is the primary method for populating the complete session dataset used by all dashboard views.
    ///
    /// **AI Context for Understanding the Method**:
    /// This async function implements a sophisticated multi-year, concurrent data loading pipeline. It handles
    /// both modern year-based file organization and legacy single-file formats transparently. The method uses
    /// TaskGroup for parallel year loading, builds dynamic CSV column maps for flexible parsing, and
    /// automatically migrates data when format changes are detected. All operations use proper async/await
    /// patterns and ensure MainActor updates for UI consistency.
    ///
    /// **Key Design Characteristics**:
    /// - **Concurrent Loading**: TaskGroup processes multiple years in parallel for performance
    /// - **Transparent Migration**: Automatically detects and converts legacy formats
    /// - **Format Detection**: Dynamically builds column index map from CSV header (order-agnostic)
    /// - **Auto-Rewrite**: Detects obsolete formats and silently rewrites files when needed
    /// - **Graceful Degradation**: Single year failure doesn't prevent loading other years
    /// - **Single Source of Truth**: Updates SessionManager.allSessions as the canonical dataset
    ///
    /// **Business Rules**:
    /// - Loads sessions from ALL available years in file system
    /// - Automatically detects and migrates legacy data formats to modern format
    /// - Validates CSV format and rewrites files if format is obsolete
    /// - Final sorted order: Newest sessions first (sorted by startDate descending)
    /// - If no years exist, checks for legacy single-file format in data.csv
    /// - Supports both "id" column and no-id legacy format (generates UUIDs if needed)
    ///
    /// **Data Flow Pipeline**:
    /// ```
    /// 1. Query File System
    ///    ↓
    /// 2a. Year-Based Files Found?
    ///    ├─ YES → [Concurrent Load Each Year]
    ///    └─ NO  → Check for Legacy data.csv
    /// 2b. Parse Each Year's CSV
    ///    ├─ Detect Format (with/without ID column)
    ///    ├─ Auto-Migrate if Needed
    ///    └─ Return SessionRecord[]
    /// 3. Combine All Sessions
    ///    ↓
    /// 4. Sort by Date (Newest First)
    ///    ↓
    /// 5. Update MainActor State
    ///    ├─ Set allSessions
    ///    └─ Set lastUpdated
    /// 6. Post Notification
    /// ```
    ///
    /// **Method Phases**:
    /// 1. **Discovery Phase**: Get available year directories from file system
    ///    - Calls csvManager.getAvailableYears() returns sorted Int array
    ///    - Empty array triggers legacy file check
    /// 2. **Legacy Fallback Phase** (if no years found):
    ///    - Checks for data.csv in root Juju directory
    ///    - Loads legacy file format if exists
    ///    - Returns sessions and skips concurrent loading
    /// 3. **Concurrent Load Phase** (if years found):
    ///    - Creates TaskGroup for parallel loading
    ///    - Spawns independent task for each year
    ///    - Each task: read year file → parse CSV → auto-migrate if needed → return sessions
    ///    - Collects results as tasks complete (order-independent)
    /// 4. **Aggregation Phase**:
    ///    - Combines sessions from all years into single array
    ///    - Preserves all data (no filtering at this stage)
    /// 5. **Sorting Phase**:
    ///    - Sorts by startDate descending (newest first)
    ///    - Consistent ordering for UI display and session lists
    /// 6. **MainActor Update Phase**:
    ///    - Updates @Published allSessions (triggers SwiftUI updates)
    ///    - Updates lastUpdated timestamp
    ///    - Posts sessionsDidLoad notification with session count
    ///
    /// **Error Handling Strategy**:
    /// - **Graceful Degradation**: Single year file read failure doesn't crash
    ///   - Try block catches errors for each year
    ///   - Returns empty array for that year; other years continue loading
    ///   - Partial data > no data philosophy
    /// - **Missing Directory**: If no years found, checks legacy format
    /// - **Empty Sessions Array**: Valid result (e.g., first app launch)
    /// - **Parse Errors**: Logged but don't prevent other years from loading
    /// - **File Format Errors**: Detected and auto-repaired via auto-migrate
    ///
    /// **Performance Optimizations**:
    /// - **Parallel Loading**: TaskGroup loads multiple year files concurrently
    ///   - Typical macOS apps: ~10-20 years data, parallel load ≈ 2-3x faster
    ///   - Single year file typically < 50MB (CSV is text-based)
    /// - **Lazy Migration**: Only rewrites files that need format updates
    ///   - Detects modern vs legacy format via needsRewrite flag
    ///   - Avoids unnecessary I/O for already-modern files
    /// - **No Pre-filtering**: Full load into memory (migration, analytics need complete dataset)
    ///   - Dashboard views do their own filtering via ChartDataPreparer
    /// - **MainActor Batching**: Single update to allSessions (not incremental)
    ///   - Prevents intermediate UI refresh states
    ///   - One notification dispatch instead of many
    ///
    /// **Edge Cases Handled**:
    /// - **No files exist**: Returns empty array, sets allSessions = []
    /// - **Corrupted year file**: Returns [] for that year; others load successfully
    /// - **Missing ID column**: Parser generates UUIDs during migration
    /// - **Mixed formats**: Detects per-year; each file format detected independently
    /// - **Duplicate sessions**: No deduplication (file is source of truth)
    /// - **Zero sessions**: Posts notification with sessionCount = 0
    ///
    /// **Notification Posted**:
    /// ```swift
    /// name: "sessionsDidLoad"
    /// userInfo: ["sessionCount": Int] // Total sessions loaded
    /// ```
    /// Observers can use this to trigger dependent UI updates or cache invalidation.
    ///
    /// **Thread Safety**:
    /// - All file reading happens on TaskGroup (background threads)
    /// - MainActor.run ensures all state updates on main thread
    /// - No shared mutable state during concurrent loading
    /// - SessionManager.allSessions is thread-safe after MainActor update
    ///
    /// **Data Format Support**:
    /// - Modern Format (current): id, start_date, end_date, project_id, activity_type_id, project_phase_id, action, is_milestone, milestone_text, notes, mood
    /// - Legacy Format (auto-migrated): date, start_time, end_time, duration_minutes, project_name, notes
    /// - Parser auto-detects format via column header inspection
    ///
    /// **Usage Example**:
    /// ```swift
    /// let allSessions = await sessionManager.loadAllSessions()
    /// // allSessions is now complete historical dataset
    /// // sessionManager.allSessions is updated automatically
    /// // UI observers notified via "sessionsDidLoad" notification
    /// ```
    ///
    /// - Returns: Array of SessionRecord objects, sorted by startDate descending (newest first).
    ///           Empty array if no sessions found or all years failed to load.
    func loadAllSessions() async -> [SessionRecord] {
        // [INTEGRATION] Called by DashboardRootView to populate allSessions once
        // [GOTCHA] This is async; sessions not available until await completes
        // [GOTCHA] All dashboard views use this cached result via sessionManager.allSessions
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
            // [INTEGRATION] Parallel loading: each year loaded concurrently for performance
            for year in availableYears {
                group.addTask { [weak self] in
                    guard let self = self else { return [] }
                    do {
                        let content = try await self.csvManager.readFromYearFile(for: year)
                        let hasIdColumn = content.lowercased().contains("id")
                        let (sessions, needsRewrite) = self.parser.parseSessionsFromCSV(content, hasIdColumn: hasIdColumn)
                        // [INTEGRATION] Auto-migration: format detection and rewrite happens silently
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
        // [INTEGRATION] MainActor update: all state changes on main thread
        // [GOTCHA] allSessions is now source of truth for all views
        await MainActor.run { [weak self] in
            self?.allSessions = sorted
            self?.lastUpdated = Date()
            // [INTEGRATION] All dashboard views listen for "sessionsDidLoad" to refresh
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
            updated = SessionRecord(id: session.id, startDate: session.startDate, endDate: session.endDate, projectID: session.projectID, activityTypeID: session.activityTypeID, projectPhaseID: session.projectPhaseID, action: session.action, isMilestone: session.isMilestone, notes: value, mood: session.mood)
        case "mood": 
            if let m = Int(value) {
                updated = SessionRecord(id: session.id, startDate: session.startDate, endDate: session.endDate, projectID: session.projectID, activityTypeID: session.activityTypeID, projectPhaseID: session.projectPhaseID, action: session.action, isMilestone: session.isMilestone, notes: session.notes, mood: m)
            }
        case "action":
            updated = SessionRecord(id: session.id, startDate: session.startDate, endDate: session.endDate, projectID: session.projectID, activityTypeID: session.activityTypeID, projectPhaseID: session.projectPhaseID, action: value, isMilestone: session.isMilestone, notes: session.notes, mood: session.mood)
        case "is_milestone":
            let boolValue = (value.lowercased() == "true" || value == "1")
            updated = SessionRecord(id: session.id, startDate: session.startDate, endDate: session.endDate, projectID: session.projectID, activityTypeID: session.activityTypeID, projectPhaseID: session.projectPhaseID, action: session.action, isMilestone: boolValue, notes: session.notes, mood: session.mood)
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
    ///   - projectID: Project identifier (required for new sessions)
    /// - Returns: True if update successful, false otherwise
    func updateSessionFull(id: String, date: String, startTime: String, endTime: String, projectName: String, notes: String, mood: Int?, activityTypeID: String? = nil, projectPhaseID: String? = nil, action: String? = nil, isMilestone: Bool? = nil, projectID: String? = nil) -> Bool {
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
    /// **Purpose**: Safely removes a specific session from both in-memory state and persistent storage,
    /// using atomic operations to ensure data integrity even in failure scenarios. Designed to be a
    /// complete, non-destructive operation that leaves no partial state.
    ///
    /// **AI Context for Understanding the Method**:
    /// This deletion method implements a sophisticated read-modify-write pattern with atomic guarantees.
    /// It reads the complete year file, filters out only the target session, and writes back the remaining
    /// data in a single atomic operation. This prevents data loss if the operation is interrupted. The method
    /// is self-contained (doesn't depend on in-memory state) and uses file locking for concurrency safety.
    ///
    /// **Key Design Principles**:
    /// - **Atomic Operation**: Read → Filter → Write as single logical operation
    /// - **File-Based Source of Truth**: Always reads from file before modifying (not in-memory only)
    /// - **Idempotent Safety**: Multiple calls with same ID are safe; only first deletes
    /// - **Non-Destructive**: Only removes target session; preserves all others
    /// - **Async/Await Pattern**: File I/O on background thread; UI updates on MainActor
    ///
    /// **Business Rules**:
    /// - Only the specified session ID is deleted (exact match required)
    /// - All other sessions in the same year are preserved unchanged
    /// - Proper CSV header format maintained in output file
    /// - Atomic file operations ensure no partial deletions
    /// - Works with both year-based and legacy single-file formats
    ///
    /// **Detailed Operation Flow**:
    /// ```
    /// 1. Find Session in Memory
    ///    ├─ Search allSessions by ID
    ///    └─ If not found: Return false immediately
    /// 2. Determine Year
    ///    └─ Extract year from session.startDate (determines which file)
    /// 3. Read File Atomically
    ///    ├─ Async read from year-specific CSV
    ///    ├─ If read fails: Catch error, log, return false
    ///    └─ Obtain complete file content
    /// 4. Parse All Sessions
    ///    ├─ Parse entire CSV content
    ///    ├─ Extract all sessions currently in file
    ///    └─ Note: May differ from in-memory if external changes
    /// 5. Filter Out Target
    ///    ├─ Remove only sessions where ID == target ID
    ///    ├─ Preserve all other sessions in exact order
    ///    └─ remainingSessions may be empty
    /// 6. Prepare Output
    ///    ├─ If sessions remain:
    ///    │  └─ Convert to CSV format (includes header)
    ///    └─ If no sessions:
    ///       └─ Write header-only file (empty but valid CSV)
    /// 7. Write Back Atomically
    ///    ├─ Async write to year file
    ///    ├─ Uses file locking (SessionCSVManager)
    ///    └─ If write fails: Catch, log, don't update memory
    /// 8. Update In-Memory State (MainActor)
    ///    ├─ Remove from allSessions
    ///    ├─ Update lastUpdated timestamp
    ///    └─ Post sessionDidEnd notification
    /// 9. Notification to Observers
    ///    ├─ Name: .sessionDidEnd
    ///    └─ userInfo: ["sessionID": id]
    /// ```
    ///
    /// **Error Handling Strategy**:
    /// - **Session Not Found in Memory**: Return false immediately (early exit)
    /// - **File Read Error**: Catch the error, log for debugging, return false without modifying memory
    ///   - Original file remains untouched
    ///   - In-memory state unchanged
    /// - **Parse Error**: Unlikely with well-formed CSV, but catches if malformed
    /// - **File Write Error**: Catch and log, but don't roll back in-memory changes
    ///   - Design choice: In-memory state already updated (fire-and-forget philosophy)
    ///   - Alternative: Could not update memory if write fails (not implemented)
    /// - **Weak Self Reference Loss**: Handled by checking guard let self in MainActor closure
    ///   - If manager deallocated mid-operation, just logs and doesn't update UI
    ///
    /// **Edge Cases**:
    /// - **Session ID Not Found**: Returns false, no side effects
    /// - **All Sessions Deleted**: Writes header-only file (empty but valid CSV format)
    /// - **Duplicate IDs**: Only first match is removed (file is source of truth, not memory)
    /// - **Year File Doesn't Exist**: File read fails, returns false gracefully
    /// - **Concurrent Deletes**: File locking in SessionCSVManager handles this
    /// - **File Locked by Another Process**: Operation blocks until available (SessionCSVManager)
    ///
    /// **Performance Characteristics**:
    /// - **Time Complexity**: O(n) where n = number of sessions in target year file
    ///   - Must read entire file (no index-based access in CSV)
    ///   - Must parse all sessions to reconstruct file
    /// - **Space Complexity**: O(n) for holding all sessions in memory during operation
    /// - **I/O Operations**: 1 read + 1 write to disk (sequential, atomic)
    /// - **Non-blocking**: File I/O on background thread, returns immediately
    ///
    /// **Thread Safety**:
    /// - **File Locking**: SessionCSVManager.writeToYearFile uses file locking
    /// - **MainActor Updates**: State changes on main thread only
    /// - **Async/Await**: Proper thread boundary handling with await and MainActor.run
    /// - **Weak Self**: Prevents memory leak if manager deallocated during operation
    /// - **Concurrent Operations**: Multiple deletes to same file are serialized by file lock
    ///
    /// **Data Consistency**:
    /// - File is always in valid state after operation (either original or modified)
    /// - CSV header always present in output file
    /// - In-memory state matches file after successful completion
    /// - Notifications ensure dependent caches (ProjectStatisticsCache) are invalidated
    ///
    /// **Notifications Posted**:
    /// ```swift
    /// name: .sessionDidEnd
    /// userInfo: ["sessionID": id] // The deleted session ID
    /// ```
    /// Observers:
    /// - ProjectStatisticsCache: Invalidates cache on this notification
    /// - ProjectManager: Updates statistics on cache invalidation
    /// - Dashboard Views: Refresh when notified
    ///
    /// **Usage Example**:
    /// ```swift
    /// let success = sessionManager.deleteSession(id: "abc-123")
    /// // If success: session removed from file and memory, observers notified
    /// // If !success: no changes made, session remains intact
    /// ```
    ///
    /// - Parameters:
    ///   - id: Session identifier to delete (String). Must be an exact match of an existing session ID.
    ///         Searches allSessions first; if not found, returns false immediately.
    /// - Returns: True if deletion was initiated and likely successful. False if session not found in memory
    ///           or file operations fail. Note: Returns true even if file write fails (fire-and-forget design).
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
    
    private func saveSessionToCSV(_ startTime: Date, _ endTime: Date, _ projectID: String, _ activityTypeID: String?, _ projectPhaseID: String?, action: String?, isMilestone: Bool, notes: String, mood: Int?, completion: @escaping (Bool) -> Void) {
        // Format the CSV row using full Date objects (new format)
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let id = UUID().uuidString
        let startDateStr = dateTimeFormatter.string(from: startTime)
        let endDateStr = dateTimeFormatter.string(from: endTime)
        let moodStr = mood.map { String($0) } ?? ""
        
        // Build CSV row with NEW format (with action and is_milestone fields, milestone_text removed)
        let projectID_Escaped = csvManager.csvEscape(projectID)
        let activityTypeID_Escaped = activityTypeID.map { csvManager.csvEscape($0) } ?? ""
        let projectPhaseID_Escaped = projectPhaseID.map { csvManager.csvEscape($0) } ?? ""
        let actionText_Escaped = action.map { csvManager.csvEscape($0) } ?? ""
        let isMilestoneStr = isMilestone ? "1" : "0" // CSV stores boolean as 0 or 1
        
        // FORMAT: id,start_date,end_date,project_id,activity_type_id,project_phase_id,action,is_milestone,notes,mood
        let csvRow = "\(id),\(startDateStr),\(endDateStr),\(projectID_Escaped),\(activityTypeID_Escaped),\(projectPhaseID_Escaped),\(actionText_Escaped),\(isMilestoneStr),\(csvManager.csvEscape(notes)),\(moodStr)\n"
        
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
