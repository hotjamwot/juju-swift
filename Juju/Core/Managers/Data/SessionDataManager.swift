import Foundation

// MARK: - Session Data Manager
class SessionDataManager: ObservableObject {
    @Published var allSessions: [SessionRecord] = []
    @Published var lastUpdated = Date()
    
    private let sessionFileManager: SessionFileManager
    private let csvManager: SessionCSVManager
    private let parser: SessionDataParser
    private let dataFileURL: URL
    private var lastLoadedDate = Date.distantPast
    
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    init(sessionFileManager: SessionFileManager, dataFileURL: URL) {
        self.sessionFileManager = sessionFileManager
        self.dataFileURL = dataFileURL
        self.csvManager = SessionCSVManager(fileManager: sessionFileManager, dataFileURL: dataFileURL)
        self.parser = SessionDataParser()
        
        // Load recent sessions by default for performance
        loadRecentSessions(limit: 40)
    }
    
    // MARK: - Session Loading
    
    func loadAllSessions() -> [SessionRecord] {
        guard FileManager.default.fileExists(atPath: dataFileURL.path) else {
            print("❌ No session data file found at \(dataFileURL.path)")
            return []
        }
        
        do {
            let content = try String(contentsOf: dataFileURL, encoding: .utf8)
            print("🔍 CSV Content length: \(content.count)")
            
            // Find header and validate
            let lines = content.components(separatedBy: .newlines)
            guard let headerLine = lines.first, !headerLine.isEmpty else { 
                print("❌ No header found")
                return [] 
            }
            
            let hasIdColumn = headerLine.lowercased().contains("id")
            print("🔍 Has ID column: \(hasIdColumn)")
            
            // Parse sessions using the dedicated parser
            let (sessions, needsRewrite) = parser.parseSessionsFromCSV(content, hasIdColumn: hasIdColumn)
            
            print("🔍 Successfully loaded \(sessions.count) sessions")
            
            // If any IDs were assigned, rewrite the CSV with IDs
            if needsRewrite {
                print("[SessionManager] Rewriting CSV to add IDs to all rows...")
                saveAllSessions(sessions)
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.allSessions = sessions
                self?.lastUpdated = Date()
            }
            
            return sessions
        } catch {
            print("❌ Error loading sessions: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.allSessions = []
                self?.lastUpdated = Date()
            }
            return []
        }
    }
    
    func loadSessions(in dateInterval: DateInterval?) -> [SessionRecord] {
        guard FileManager.default.fileExists(atPath: dataFileURL.path) else {
            return []
        }
        
        if dateInterval == nil {
            return loadAllSessions()
        }
        
        let interval = dateInterval!
        
        do {
            let content = try String(contentsOf: dataFileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            guard let headerLine = lines.first, !headerLine.isEmpty else {
                return []
            }
            let hasIdColumn = headerLine.lowercased().contains("id")
            
            // Parse sessions for date range using dedicated parser
            let sessions = parser.parseSessionsFromCSVForDateRange(content, hasIdColumn: hasIdColumn, dateInterval: interval)
            
            // Sort by date descending (string comparison works for yyyy-MM-dd)
            let sortedSessions = sessions.sorted { $0.date > $1.date }
            
            DispatchQueue.main.async { [weak self] in
                self?.allSessions = sortedSessions
                self?.lastUpdated = Date()
            }
            
            return sortedSessions
        } catch {
            print("❌ Error loading filtered sessions: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.allSessions = []
                self?.lastUpdated = Date()
            }
            return []
        }
    }
    
    /// Load only the most recent sessions for better performance
    func loadRecentSessions(limit: Int = 40) {
        let allSessions = loadAllSessions()
        let recentSessions = Array(allSessions.prefix(limit))
        DispatchQueue.main.async { [weak self] in
            self?.allSessions = recentSessions
            self?.lastUpdated = Date()
        }
        print("✅ Loaded only \(recentSessions.count) recent sessions (out of \(allSessions.count) total)")
    }
    
    // MARK: - Session Data Operations
    
    func updateSession(id: String, field: String, value: String) -> Bool {
        guard let session = allSessions.first(where: { $0.id == id }) else {
            print("❌ Session \(id) not found for update")
            return false
        }

        // 1️⃣  First produce a copy with the new field
        var updated = session.withUpdated(field: field, value: value)

        // 2️⃣  Re‑calculate duration if a time was changed
        if field == "start_time" || field == "end_time" {
            let newDuration = minutesBetween(start: updated.startTime, end: updated.endTime)
            // Replace the immutable durationMinutes field
            updated = SessionRecord(
                id: updated.id,
                date: updated.date,
                startTime: updated.startTime,
                endTime: updated.endTime,
                durationMinutes: newDuration,
                projectName: updated.projectName,
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
            
            print("✅ Updated session \(id) field \(field) to \(value)")
            return true
        }

        return false
    }
    
    func updateSessionFull(id: String, date: String, startTime: String, endTime: String, projectName: String, notes: String, mood: Int?) -> Bool {
        let moodValue = mood.map { String($0) } ?? ""
        let successes = [
            updateSession(id: id, field: "date", value: date),
            updateSession(id: id, field: "start_time", value: startTime),
            updateSession(id: id, field: "end_time", value: endTime),
            updateSession(id: id, field: "project", value: projectName),
            updateSession(id: id, field: "notes", value: notes),
            updateSession(id: id, field: "mood", value: moodValue)
        ]
        let allSuccess = successes.allSatisfy { $0 }
        if allSuccess {
            print("✅ Updated full session \(id)")
        } else {
            print("❌ Partial failure updating session \(id)")
        }
        return allSuccess
    }
    
    // Delete a session
    func deleteSession(id: String) -> Bool {
        let wasPresent = allSessions.contains { $0.id == id }
        if !wasPresent {
            print("❌ Session \(id) not found for delete")
            return false
        }
        
        allSessions.removeAll { $0.id == id }
        saveAllSessions(allSessions)
        
        // Update timestamp to trigger UI refresh
        lastUpdated = Date()
        
        print("✅ Deleted session \(id)")
        return true
    }
    
    // MARK: - Session Export
    
    func exportSessions(_ sessions: [SessionRecord], format: String, fileName: String? = nil) -> URL? {
        let exporter = SessionExporter(sessions: sessions, format: format)
        guard let exportPath = exporter.export(to: fileName) else {
            print("❌ Export failed")
            return nil
        }
        print("✅ Exported to \(exportPath)")
        return exportPath
    }
    
    // MARK: - Data Persistence
    
    func saveAllSessions(_ sessions: [SessionRecord]) {
        let csvContent = parser.convertSessionsToCSV(sessions)
        Task {
            do {
                try await csvManager.writeToFile(csvContent)
                await MainActor.run { [weak self] in
                    self?.lastUpdated = Date()
                }
                print("[SessionManager] Rewritten CSV with IDs for all sessions.")
            } catch {
                print("❌ Error saving sessions: \(error)")
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
