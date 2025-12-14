import Foundation

// MARK: - Session Data Manager
class SessionDataManager: ObservableObject {
    @Published var allSessions: [SessionRecord] = []
    @Published var lastUpdated = Date()
    
    private let sessionFileManager: SessionFileManager
    private let csvManager: SessionCSVManager
    private let parser: SessionDataParser
    private let jujuPath: URL
    private let dataFileURL: URL? // Kept for backward compatibility during migration
    private var lastLoadedDate = Date.distantPast
    
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    init(sessionFileManager: SessionFileManager, dataFileURL: URL) {
        self.sessionFileManager = sessionFileManager
        self.jujuPath = dataFileURL.deletingLastPathComponent()
        self.dataFileURL = dataFileURL // Keep for backward compatibility
        
        // Initialize CSV manager with jujuPath for year-based file support
        self.csvManager = SessionCSVManager(fileManager: sessionFileManager, jujuPath: jujuPath)
        self.parser = SessionDataParser()
        
        // Load only current year sessions by default for dashboard performance
        Task {
            await loadCurrentYearSessions()
        }
        
        // Observe project changes to refresh projects data when projects change (e.g., phases added)
        NotificationCenter.default.addObserver(
            forName: .projectsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Projects have changed, but we don't need to do anything here
            // The ProjectManager cache will be cleared automatically
        }
    }
    
    // MARK: - Session Loading
    
    func loadAllSessions() async -> [SessionRecord] {
        print("[SessionDataManager] loadAllSessions called")
        let availableYears = csvManager.getAvailableYears()
        print("[SessionDataManager] Available years: \(availableYears)")
        
        var allSessions: [SessionRecord] = []
        
        if !availableYears.isEmpty {
            for year in availableYears {
                do {
                    print("[SessionDataManager] Loading sessions from \(year)")
                    let content = try await csvManager.readFromYearFile(for: year)
                    let lines = content.components(separatedBy: .newlines)
                    guard let headerLine = lines.first, !headerLine.isEmpty else {
                        print("[SessionDataManager] No header line found for \(year)")
                        continue
                    }
                    
                    let hasIdColumn = headerLine.lowercased().contains("id")
                    let (sessions, needsRewrite) = parser.parseSessionsFromCSV(content, hasIdColumn: hasIdColumn)
                    
                    print("[SessionDataManager] Parsed \(sessions.count) sessions from \(year)")
                    allSessions.append(contentsOf: sessions)
                    
                    // If rewrite needed, save back to the year file
                    if needsRewrite {
                        let csvContent = parser.convertSessionsToCSV(sessions)
                        try await csvManager.writeToYearFile(csvContent, for: year)
                    }
                } catch {
                    print("❌ Error loading sessions from \(year)-data.csv: \(error)")
                }
            }
            
            // Sort by date descending
            allSessions.sort { ($0.startDateTime ?? Date.distantPast) > ($1.startDateTime ?? Date.distantPast) }
            
            print("[SessionDataManager] Total sessions loaded: \(allSessions.count)")
            self.allSessions = allSessions
            self.lastUpdated = Date()
            return allSessions
        }
    
        // Fallback to legacy data.csv file if it exists
        if let legacyURL = dataFileURL, FileManager.default.fileExists(atPath: legacyURL.path) {
            print("[SessionDataManager] Falling back to legacy file")
            let sessions = loadSessionsFromLegacyFile(legacyURL)
            self.allSessions = sessions
            self.lastUpdated = Date()
            return sessions
        }
    
        print("[SessionDataManager] No sessions found")
        self.allSessions = []
        self.lastUpdated = Date()
        return []
    }
    
    /// Load sessions from legacy data.csv file (backward compatibility)
    private func loadSessionsFromLegacyFile(_ url: URL) -> [SessionRecord] {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            
            let lines = content.components(separatedBy: .newlines)
            guard let headerLine = lines.first, !headerLine.isEmpty else {
                return []
            }
            
            let hasIdColumn = headerLine.lowercased().contains("id")
            let (sessions, needsRewrite) = parser.parseSessionsFromCSV(content, hasIdColumn: hasIdColumn)
            
            if needsRewrite {
                // Legacy file needs rewrite - consider migrating to year-based files
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.allSessions = sessions
                self?.lastUpdated = Date()
            }
            
            return sessions
        } catch {
            print("❌ Error loading legacy file: \(error)")
            return []
        }
    }
    
    func loadSessions(in dateInterval: DateInterval?) async -> [SessionRecord] {
        if dateInterval == nil {
            return await loadAllSessions()
        }
        
        let interval = dateInterval!
        
        // Determine which years to load based on date interval
        let startYear = Calendar.current.component(.year, from: interval.start)
        let endYear = Calendar.current.component(.year, from: interval.end)
        let availableYears = csvManager.getAvailableYears()
        let yearsToLoad = availableYears.filter { $0 >= startYear && $0 <= endYear }
        
        if yearsToLoad.isEmpty {
            // Fallback to legacy file if no year files found
            if let legacyURL = dataFileURL, FileManager.default.fileExists(atPath: legacyURL.path) {
                return loadSessionsFromLegacyFileForDateRange(legacyURL, dateInterval: interval)
            }
            return []
        }
        
        // Load sessions from relevant year files
        var allSessions: [SessionRecord] = []
        
        // Use TaskGroup for concurrent loading
        let loadedSessions = await withTaskGroup(of: [SessionRecord].self) { group in
            for year in yearsToLoad {
                group.addTask { [weak self] in
                    guard let self = self else { return [] }
                    
                    do {
                        let content = try await self.csvManager.readFromYearFile(for: year)
                        let lines = content.components(separatedBy: .newlines)
                        guard let headerLine = lines.first, !headerLine.isEmpty else {
                            return []
                        }
                        let hasIdColumn = headerLine.lowercased().contains("id")
                        
                        // Parse sessions for date range
                        return self.parser.parseSessionsFromCSVForDateRange(content, hasIdColumn: hasIdColumn, dateInterval: interval)
                    } catch {
                        print("❌ Error loading \(year)-data.csv: \(error)")
                        return []
                    }
                }
            }
            
            var allLoaded: [SessionRecord] = []
            for await sessions in group {
                allLoaded.append(contentsOf: sessions)
            }
            return allLoaded
        }
        
        // Sort by date descending
        let sortedSessions = loadedSessions.sorted { ($0.startDateTime ?? Date.distantPast) > ($1.startDateTime ?? Date.distantPast) }
        
        // Update the UI on main thread
        await MainActor.run { [weak self] in
            self?.allSessions = sortedSessions
            self?.lastUpdated = Date()
        }
        
        // Trigger background session counting for all projects
        // This will cache the results so the Projects tab loads instantly
        ProjectManager.shared.updateAllProjectStatistics()
        
        // Also warm the cache directly for immediate availability
        ProjectStatisticsCache.shared.warmCache(for: ProjectManager.shared.loadProjects())
        
        return sortedSessions
    }
    
    /// Load sessions from legacy file for a specific date range
    private func loadSessionsFromLegacyFileForDateRange(_ url: URL, dateInterval: DateInterval) -> [SessionRecord] {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            guard let headerLine = lines.first, !headerLine.isEmpty else {
                return []
            }
            let hasIdColumn = headerLine.lowercased().contains("id")
            
            let sessions = parser.parseSessionsFromCSVForDateRange(content, hasIdColumn: hasIdColumn, dateInterval: dateInterval)
            let sortedSessions = sessions.sorted { ($0.startDateTime ?? Date.distantPast) > ($1.startDateTime ?? Date.distantPast) }
            
            DispatchQueue.main.async { [weak self] in
                self?.allSessions = sortedSessions
                self?.lastUpdated = Date()
            }
            
            return sortedSessions
        } catch {
            print("❌ Error loading filtered sessions from legacy file: \(error)")
            return []
        }
    }
    
    /// Load only current year sessions for dashboard performance
    func loadCurrentYearSessions() async -> [SessionRecord] {
        let currentYear = Calendar.current.component(.year, from: Date())
        print("[SessionDataManager] Loading sessions for current year: \(currentYear)")
        
        var allSessions: [SessionRecord] = []
        
        // Only load current year sessions
        do {
            print("[SessionDataManager] Loading sessions from \(currentYear)")
            let content = try await csvManager.readFromYearFile(for: currentYear)
            let lines = content.components(separatedBy: .newlines)
            guard let headerLine = lines.first, !headerLine.isEmpty else {
                print("[SessionDataManager] No header line found for \(currentYear)")
                return []
            }
            
            let hasIdColumn = headerLine.lowercased().contains("id")
            let (sessions, needsRewrite) = parser.parseSessionsFromCSV(content, hasIdColumn: hasIdColumn)
            
            print("[SessionDataManager] Parsed \(sessions.count) sessions from \(currentYear)")
            allSessions.append(contentsOf: sessions)
            
            // If rewrite needed, save back to the year file
            if needsRewrite {
                let csvContent = parser.convertSessionsToCSV(sessions)
                try await csvManager.writeToYearFile(csvContent, for: currentYear)
            }
            
            // Sort by date descending
            allSessions.sort { ($0.startDateTime ?? Date.distantPast) > ($1.startDateTime ?? Date.distantPast) }
            
            print("[SessionDataManager] Current year sessions loaded: \(allSessions.count)")
            self.allSessions = allSessions
            self.lastUpdated = Date()
            return allSessions
        } catch {
            print("❌ Error loading sessions from \(currentYear)-data.csv: \(error)")
            return []
        }
    }
    
    /// Load only current week sessions for dashboard performance
    func loadCurrentWeekSessions() async {
        let currentYear = Calendar.current.component(.year, from: Date())
        print("[SessionDataManager] Loading sessions for current week from year: \(currentYear)")
        
        var allSessions: [SessionRecord] = []
        
        // Load current year sessions and filter to current week
        do {
            print("[SessionDataManager] Loading sessions from \(currentYear)")
            let content = try await csvManager.readFromYearFile(for: currentYear)
            let lines = content.components(separatedBy: .newlines)
            guard let headerLine = lines.first, !headerLine.isEmpty else {
                print("[SessionDataManager] No header line found for \(currentYear)")
                return
            }
            
            let hasIdColumn = headerLine.lowercased().contains("id")
            let (sessions, needsRewrite) = parser.parseSessionsFromCSV(content, hasIdColumn: hasIdColumn)
            
            // Filter to current week only
            let currentWeekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), end: Date())
            let weekSessions = sessions.filter { session in
                guard let sessionDate = DateFormatter.cachedYYYYMMDD.date(from: session.date) else { return false }
                return currentWeekInterval.contains(sessionDate)
            }
            
            print("[SessionDataManager] Parsed \(sessions.count) sessions from \(currentYear), filtered to \(weekSessions.count) current week sessions")
            allSessions.append(contentsOf: weekSessions)
            
            // If rewrite needed, save back to the year file
            if needsRewrite {
                let csvContent = parser.convertSessionsToCSV(sessions)
                try await csvManager.writeToYearFile(csvContent, for: currentYear)
            }
            
            // Sort by date descending
            allSessions.sort { ($0.startDateTime ?? Date.distantPast) > ($1.startDateTime ?? Date.distantPast) }
            
            print("[SessionDataManager] Current week sessions loaded: \(allSessions.count)")
            self.allSessions = allSessions
            self.lastUpdated = Date()
        } catch {
            print("❌ Error loading sessions from \(currentYear)-data.csv: \(error)")
        }
    }
    
    // MARK: - Session Data Operations
    
    func updateSession(id: String, field: String, value: String) -> Bool {
        guard let session = allSessions.first(where: { $0.id == id }) else {
            return false
        }

        // 1️⃣  First produce a copy with the new field
        var updated = session.withUpdated(field: field, value: value)

        // 2️⃣  Re‑calculate duration if a time was changed
        if field == "start_time" || field == "end_time" {
            let newDuration = minutesBetween(start: updated.startTime, end: updated.endTime)
            // Replace the immutable durationMinutes field, preserving all fields
            updated = SessionRecord(
                id: updated.id,
                date: updated.date,
                startTime: updated.startTime,
                endTime: updated.endTime,
                durationMinutes: newDuration,
                projectName: updated.projectName,
                projectID: updated.projectID,
                activityTypeID: updated.activityTypeID,
                projectPhaseID: updated.projectPhaseID,
                milestoneText: updated.milestoneText,
                notes: updated.notes,
                mood: updated.mood
            )
        }

        // 3️⃣  Persist the change
        if let index = allSessions.firstIndex(where: { $0.id == id }) {
            allSessions[index] = updated
            saveAllSessions(allSessions)
            
            // Update timestamp to trigger UI refresh
            lastUpdated = Date()
            
            return true
        }

        return false
    }
    
    func updateSessionFull(id: String, date: String, startTime: String, endTime: String, projectName: String, notes: String, mood: Int?, activityTypeID: String? = nil, projectPhaseID: String? = nil, milestoneText: String? = nil) -> Bool {
        guard let session = allSessions.first(where: { $0.id == id }) else {
            return false
        }

        // Get the projectID for the new project name
        let projects = ProjectManager.shared.loadProjects()
        let newProjectID = projects.first { $0.name == projectName }?.id
        
        // Validate that the projectPhaseID belongs to the correct project
        var validatedProjectPhaseID = projectPhaseID
        var validatedProjectID = newProjectID ?? session.projectID  // Use new projectID if found, otherwise keep old
        
        if let phaseID = projectPhaseID {
            var phaseBelongsToCorrectProject = false
            
            // Check if the phase exists in the new project
            if let newProject = projects.first(where: { $0.id == validatedProjectID }) {
                if newProject.phases.contains(where: { $0.id == phaseID && !$0.archived }) {
                    // Phase exists in the new project - validation passed
                    phaseBelongsToCorrectProject = true
                }
            }
            
            if !phaseBelongsToCorrectProject {
                // Phase doesn't exist in the new project
                validatedProjectPhaseID = nil
            }
        }

        // Create updated session with all fields
        var updated = SessionRecord(
            id: session.id,
            date: date,
            startTime: startTime,
            endTime: endTime,
            durationMinutes: minutesBetween(start: startTime, end: endTime),
            projectName: projectName,
            projectID: validatedProjectID,
            activityTypeID: activityTypeID ?? session.activityTypeID,
            projectPhaseID: validatedProjectPhaseID,
            milestoneText: milestoneText ?? session.milestoneText,
            notes: notes,
            mood: mood
        )

        // Persist the change
        if let index = allSessions.firstIndex(where: { $0.id == id }) {
            allSessions[index] = updated
            
            // Save to file first
            saveAllSessions(allSessions)
            
            // Update timestamp to trigger UI refresh
            lastUpdated = Date()
            
            // Post notification that session was updated
            // Use a dedicated notification name for session updates to avoid conflicts
            NotificationCenter.default.post(
                name: .sessionDidEnd,
                object: nil,
                userInfo: ["sessionID": id]
            )
            
            // Also post a general session update notification for broader listeners
            NotificationCenter.default.post(
                name: NSNotification.Name("sessionDidUpdate"),
                object: nil,
                userInfo: ["sessionID": id]
            )
            
            return true
        }

        return false
    }
    
    // Delete a session
    func deleteSession(id: String) -> Bool {
        let wasPresent = allSessions.contains { $0.id == id }
        if !wasPresent {
            return false
        }
        
        allSessions.removeAll { $0.id == id }
        saveAllSessions(allSessions)
        
        // Update timestamp to trigger UI refresh
        lastUpdated = Date()
        
        return true
    }
    
    // MARK: - Session Export
    
    func exportSessions(_ sessions: [SessionRecord], format: String, fileName: String? = nil) -> URL? {
        let exporter = SessionExporter(sessions: sessions, format: format)
        guard let exportPath = exporter.export(to: fileName) else {
            return nil
        }
        return exportPath
    }
    
    // MARK: - Data Persistence
    
    func saveAllSessions(_ sessions: [SessionRecord]) {
        // Validate all sessions before saving
        let validator = DataValidator.shared
        let errorHandler = ErrorHandler.shared
        
        var validSessions: [SessionRecord] = []
        var invalidSessions: [(SessionRecord, String)] = []
        
        for session in sessions {
            switch validator.validateSession(session) {
            case .valid:
                validSessions.append(session)
            case .invalid(let reason):
                invalidSessions.append((session, reason))
                errorHandler.handleValidationError(
                    NSError(domain: "DataValidation", code: 1001, userInfo: [NSLocalizedDescriptionKey: reason]),
                    dataType: "Session"
                )
            }
        }
        
        if !invalidSessions.isEmpty {
            print("⚠️ Found \(invalidSessions.count) invalid sessions. Skipping them.")
            for (session, reason) in invalidSessions {
                print("  - Session \(session.id): \(reason)")
            }
        }
        
        // Group valid sessions by year (based on start date)
        var sessionsByYear: [Int: [SessionRecord]] = [:]
        
        for session in validSessions {
            guard let startDate = session.startDateTime else { continue }
            let year = Calendar.current.component(.year, from: startDate)
            if sessionsByYear[year] == nil {
                sessionsByYear[year] = []
            }
            sessionsByYear[year]?.append(session)
        }
        
        // Create a local copy to avoid capturing the mutable dictionary
        let yearsToSave = sessionsByYear.keys.sorted()
        let sessionsCopy = sessionsByYear
        
        // Save each year's sessions to its respective file
        Task {
            for year in yearsToSave {
                guard let yearSessions = sessionsCopy[year] else { continue }
                do {
                    let csvContent = SessionDataParser().convertSessionsToCSV(yearSessions)
                    try await csvManager.writeToYearFile(csvContent, for: year)
                    print("✅ Saved \(yearSessions.count) sessions to \(year)-data.csv")
                    print("🔍 CSV Header: \(csvContent.components(separatedBy: "\n").first ?? "No header")")
                } catch {
                    errorHandler.handleFileError(error, operation: "write", filePath: "\(year)-data.csv")
                }
            }
            
            await MainActor.run { [weak self] in
                self?.lastUpdated = Date()
            }
        }
    }
    
    // MARK: - Utility Functions
    
    private func minutesBetween(start: String, end: String) -> Int {
        // Accept "HH:mm" or "HH:mm:ss"; if seconds are missing we'll pad them.
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        // Pad missing seconds so the formatter can parse it
        let paddedStart = start.count == 5 ? start + ":00" : start
        let paddedEnd   = end.count   == 5 ? end   + ":00" : end

        guard
            let startDate = formatter.date(from: paddedStart),
            let endDate   = formatter.date(from: paddedEnd)
        else { return 0 }

        let diff = endDate.timeIntervalSince(startDate)
        return Int(round(diff / 60))   // minutes
    }
    
    // MARK: - Session Export Helper
    
    private class SessionExporter {
        let sessions: [SessionRecord]
        let format: String
        
        init(sessions: [SessionRecord], format: String) {
            self.sessions = sessions
            self.format = format
        }
        
        func export(to fileName: String? = nil) -> URL? {
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            let baseName = fileName ?? "juju_sessions"
            let path: URL
            
            let exportContent = parser.convertSessionsToCSVForExport(sessions, format: format)
            
            switch format {
            case "csv", "txt", "md":
                path = downloads?.appendingPathComponent("\(baseName).\(format)") ?? URL(fileURLWithPath: "\(baseName).\(format)")
                try? exportContent.write(to: path, atomically: true, encoding: .utf8)
            default:
                return nil
            }
            return path
        }
        
        private var parser: SessionDataParser {
            SessionDataParser()
        }
    }
}
