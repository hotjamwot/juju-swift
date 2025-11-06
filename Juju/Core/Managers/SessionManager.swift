import Foundation

struct SessionData {
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int
    let projectName: String
    let notes: String
}

// MARK: - Data Structures
public struct SessionRecord: Identifiable {
    public let id: String
    let date: String
    let startTime: String
    let endTime: String
    let durationMinutes: Int
    let projectName: String
    let notes: String
    let mood: Int?

    // Computed startDateTime combining date and startTime
    var startDateTime: Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: date) else { return nil }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let paddedStartTime = startTime.count == 5 ? startTime + ":00" : startTime
        guard let time = timeFormatter.date(from: paddedStartTime) else { return nil }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second ?? 0

        return Calendar.current.date(from: components)
    }

    // Computed endDateTime combining date and endTime
    var endDateTime: Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: date) else { return nil }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let paddedEndTime = endTime.count == 5 ? endTime + ":00" : endTime
        guard let time = timeFormatter.date(from: paddedEndTime) else { return nil }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second ?? 0

        return Calendar.current.date(from: components)
    }

    // Helper to check if session overlaps with a date interval
    func overlaps(with interval: DateInterval) -> Bool {
        guard let start = startDateTime, let end = endDateTime else { return false }
        return start < interval.end && end > interval.start
    }
}

extension SessionRecord {
    func withUpdated(field: String, value: String) -> SessionRecord {
        let newMood: Int? = field == "mood" ? (Int(value) ?? nil) : mood
        let newDate = field == "date" ? value : date
        let newStartTime = field == "start_time" ? value : startTime
        let newEndTime = field == "end_time" ? value : endTime
        let newProject = field == "project" ? value : projectName
        let newNotes = field == "notes" ? value : notes
        
        return SessionRecord(
            id: id,
            date: newDate,
            startTime: newStartTime,
            endTime: newEndTime,
            durationMinutes: durationMinutes,
            projectName: newProject,
            notes: newNotes,
            mood: newMood
        )
    }
}

class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published var allSessions: [SessionRecord] = []
    
    // Session state
    public var isSessionActive = false
    public var currentProjectName: String?
    public var sessionStartTime: Date?
    
    // CSV file path
    private let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    private let jujuPath: URL?
    private let dataFile: URL?
    private var lastLoadedDate = Date.distantPast
    
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private init() {
        self.jujuPath = appSupportPath?.appendingPathComponent("Juju")
        self.dataFile = jujuPath?.appendingPathComponent("data.csv")
        if fileExists() {
            _ = loadAllSessions()
        }
    }
    
    // MARK: - Session State Management
    
    func startSession(for projectName: String) {
        guard !isSessionActive else {
            print("⚠️ Session already active")
            return
        }
        
        print("✅ Starting session for project: \(projectName)")
        isSessionActive = true
        currentProjectName = projectName
        sessionStartTime = Date()
    }
    
    func endSession(notes: String = "", mood: Int? = nil) {
        guard isSessionActive, let projectName = currentProjectName, let startTime = sessionStartTime else {
            print("⚠️ No active session to end")
            return
        }
        
        let endTime = Date()
        let durationMs = endTime.timeIntervalSince(startTime)
        let durationMinutes = Int(round(durationMs / 60))
        
        print("✅ Ending session for \(projectName) - Duration: \(durationMinutes) minutes")
        
        // Create session data
        let sessionData = SessionData(
            startTime: startTime,
            endTime: endTime,
            durationMinutes: durationMinutes,
            projectName: projectName,
            notes: notes
        )
        
        // Save to CSV
        saveSessionToCSV(sessionData, mood: mood)
        
        // Load sessions in background to update UI
        DispatchQueue.global(qos: .background).async {
            _ = self.loadAllSessions()
        }
        
        // Reset state
        isSessionActive = false
        currentProjectName = nil
        sessionStartTime = nil
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
    
    // MARK: - CSV Management
    
    private func saveSessionToCSV(_ sessionData: SessionData, mood: Int? = nil) {
        // Ensure directory exists
        if let jujuPath = jujuPath {
            try? FileManager.default.createDirectory(at: jujuPath, withIntermediateDirectories: true)
        }
        
        // Format the CSV row
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let date = dateFormatter.string(from: sessionData.startTime)
        let startTime = timeFormatter.string(from: sessionData.startTime)
        let endTime = timeFormatter.string(from: sessionData.endTime)
        let id = UUID().uuidString
        let moodStr = mood.map { String($0) } ?? ""
        
        let csvRow = "\(id),\(date),\(startTime),\(endTime),\(sessionData.durationMinutes),\(csvEscape(sessionData.projectName)),\(csvEscape(sessionData.notes)),\(moodStr)\n"
        
        // Check if file exists and needs header
        let needsHeader = !fileExists() || isFileEmpty()
        
        if needsHeader {
            let header = "id,date,start_time,end_time,duration_minutes,project,notes,mood\n"
            let fullContent = header + csvRow
            writeToFile(fullContent)
            print("✅ Created new CSV file with header and session data (with IDs and mood)")
        } else {
            appendToFile(csvRow)
            print("✅ Appended session data to existing CSV file (with ID and mood)")
        }
    }
    
    private func fileExists() -> Bool {
        guard let dataFile = dataFile else { return false }
        return FileManager.default.fileExists(atPath: dataFile.path)
    }
    
    private func isFileEmpty() -> Bool {
        guard let dataFile = dataFile else { return true }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: dataFile.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            return fileSize == 0
        } catch {
            return true
        }
    }
    
    private func writeToFile(_ content: String) {
        guard let dataFile = dataFile else { return }
        do {
            try content.write(to: dataFile, atomically: true, encoding: .utf8)
            print("✅ Successfully wrote to CSV file at: \(dataFile.path)")
        } catch {
            print("❌ Error writing to CSV file at \(dataFile.path): \(error)")
        }
    }
    
    private func appendToFile(_ content: String) {
        guard let dataFile = dataFile else { return }
        do {
            let fileHandle = try FileHandle(forWritingTo: dataFile)
            fileHandle.seekToEndOfFile()
            fileHandle.write(content.data(using: .utf8)!)
            fileHandle.closeFile()
            print("✅ Successfully appended to CSV file at: \(dataFile.path)")
        } catch {
            print("❌ Error appending to CSV file at \(dataFile.path): \(error)")
        }
    }
    
    // MARK: - CSV Parsing Helpers
    // Simple CSV parser that handles quoted fields
    private func splitCSVRows(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            let fields = parseCSVLine(line)
            if !fields.isEmpty {
                rows.append(fields)
            }
        }
        
        return rows
    }
    
    // Parse a single CSV line, handling quoted fields
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = 0
        
        while i < line.count {
            let char = line[line.index(line.startIndex, offsetBy: i)]
            
            if char == "\"" {
                if inQuotes {
                    // Check for escaped quote
                    if i + 1 < line.count && line[line.index(line.startIndex, offsetBy: i + 1)] == "\"" {
                        currentField += "\""
                        i += 1 // Skip next quote
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if char == "," && !inQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
                currentField = ""
            } else {
                currentField += String(char)
            }
            
            i += 1
        }
        
        // Add the last field
        fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
        
        return fields
    }
}

private extension String.Iterator {
    mutating func peek() -> Character? {
        var copy = self
        return copy.next()
    }
}

extension SessionManager {
    func loadAllSessions() -> [SessionRecord] {
        guard let dataFile = dataFile, FileManager.default.fileExists(atPath: dataFile.path) else {
            print("❌ No session data file found at \(dataFile?.path ?? "nil")")
            return []
        }
        
        do {
            // Optimized: Read file in chunks for better performance
            let content = try String(contentsOf: dataFile, encoding: .utf8)
            print("🔍 CSV Content length: \(content.count)")
            
            // Optimized: Direct string manipulation instead of complex CSV parsing
            let lines = content.components(separatedBy: .newlines)
            print("🔍 Processed \(lines.count) lines")
            
            // Find header and validate
            guard let headerLine = lines.first, !headerLine.isEmpty else { 
                print("❌ No header found")
                return [] 
            }
            
            let hasIdColumn = headerLine.lowercased().contains("id")
            print("🔍 Has ID column: \(hasIdColumn)")
            
            // Pre-filter empty lines
            let dataLines = lines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let numberOfDataRows = dataLines.count
            print("🔍 Processing \(numberOfDataRows) data rows")
            
            var sessions: [SessionRecord] = []
            var needsRewrite = false
            
            // Optimized batch processing
            let batchSize = 2000  // Increased batch size for better performance
            for batchStart in stride(from: 0, to: numberOfDataRows, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, numberOfDataRows)
                let batch = Array(dataLines[batchStart..<batchEnd])
                
                for (batchIndex, line) in batch.enumerated() {
                    let rowIndex = batchStart + batchIndex + 1  // +1 to skip header
                    
                    // Optimized CSV parsing - split by comma and handle quotes
                    let fields = parseCSVLineOptimized(line)
                    
                    // Ensure minimum fields
                    var safeFields = fields + Array(repeating: "", count: max(0, 8 - fields.count))
                    
                    var id: String
                    if hasIdColumn {
                        id = cleanField(safeFields[0])
                    } else {
                        // No ID column, generate one
                        id = UUID().uuidString
                        needsRewrite = true
                        print("[SessionManager] Assigned new ID \(id) to row \(rowIndex)")
                        safeFields.insert(id, at: 0)
                    }
                    
                    // Ensure all required fields exist after potential ID insertion
                    while safeFields.count < 8 {
                        safeFields.append("")
                    }
                    
                    let dateStr = cleanField(safeFields[1])
                    guard !dateStr.isEmpty, dateFormatter.date(from: dateStr) != nil else {
                        print("⚠️ Skipping invalid date in row \(rowIndex): \(dateStr)")
                        continue
                    }
                    
                    // Optimized field extraction
                    let record = SessionRecord(
                        id: id,
                        date: dateStr,
                        startTime: cleanField(safeFields[2]),
                        endTime: cleanField(safeFields[3]),
                        durationMinutes: Int(cleanField(safeFields[4])) ?? 0,
                        projectName: cleanField(safeFields[5]),
                        notes: cleanField(safeFields[6]),
                        mood: safeFields[7].isEmpty ? nil : Int(cleanField(safeFields[7]))
                    )
                    sessions.append(record)
                }
                
                // Update published property periodically for UI feedback
                DispatchQueue.main.async {
                    self.allSessions = sessions
                }
            }
            
            print("🔍 Successfully loaded \(sessions.count) sessions")
            // If any IDs were assigned, rewrite the CSV with IDs
            if needsRewrite {
                print("[SessionManager] Rewriting CSV to add IDs to all rows...")
                saveAllSessions(sessions)
            }
            self.allSessions = sessions
            return sessions
        } catch {
            print("❌ Error loading sessions: \(error)")
            self.allSessions = []
            return []
        }
    }
    
    // Optimized CSV line parser - much faster than the original
    private func parseCSVLineOptimized(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = 0
        
        while i < line.count {
            let char = line[line.index(line.startIndex, offsetBy: i)]
            
            if char == "\"" {
                if inQuotes && i + 1 < line.count && line[line.index(line.startIndex, offsetBy: i + 1)] == "\"" {
                    // Escaped quote
                    currentField += "\""
                    i += 1
                } else {
                    inQuotes = !inQuotes
                }
            } else if char == "," && !inQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
                currentField = ""
            } else {
                currentField += String(char)
            }
            
            i += 1
        }
        
        fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
        return fields
    }
    
    // Clean field by removing quotes and trimming whitespace
    private func cleanField(_ field: String) -> String {
        return field.trimmingCharacters(in: CharacterSet(charactersIn: "\"")).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func minutesBetween(start: String, end: String) -> Int {
    // Accept “HH:mm” or “HH:mm:ss”; if seconds are missing we’ll pad them.
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

    
// Update a session field
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
        saveAllSessions(allSessions)          // writes the CSV
        print("✅ Updated session \(id) field \(field) to \(value)")
        return true
    }

    return false
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
        print("✅ Deleted session \(id)")
        return true
    }
    
    // Export sessions to file
    func exportSessions(_ sessions: [SessionRecord], format: String, fileName: String? = nil) -> URL? {
        let exporter = SessionExporter(sessions: sessions, format: format)
        guard let exportPath = exporter.export(to: fileName) else {
            print("❌ Export failed")
            return nil
        }
        print("✅ Exported to \(exportPath)")
        return exportPath
    }
    
    // Update session with all fields at once
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

public func loadSessions(in dateInterval: DateInterval?) -> [SessionRecord] {
    guard let dataFile = self.dataFile, FileManager.default.fileExists(atPath: dataFile.path) else {
        return []
    }
    
    if dateInterval == nil {
        return loadAllSessions()
    }
    
    let interval = dateInterval!
    
    do {
        let content = try String(contentsOf: dataFile, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        guard let headerLine = lines.first, !headerLine.isEmpty else {
            return []
        }
        let hasIdColumn = headerLine.lowercased().contains("id")
        let dataLines = lines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var sessions: [SessionRecord] = []
        for line in dataLines {
            let fields = parseCSVLineOptimized(line)
            let fieldCount = fields.count
            let dateIndex = hasIdColumn ? 1 : 0
            let dateStr = (dateIndex < fieldCount) ? cleanField(fields[dateIndex]) : ""
            guard !dateStr.isEmpty,
                  dateFormatter.date(from: dateStr) != nil,
                  let date = dateFormatter.date(from: dateStr),
                  date >= interval.start && date < interval.end else {
                continue
            }
            let id = hasIdColumn ? ((0 < fieldCount) ? cleanField(fields[0]) : UUID().uuidString) : UUID().uuidString
            let startIndex = hasIdColumn ? 2 : 1
            let endIndex = hasIdColumn ? 3 : 2
            let durIndex = hasIdColumn ? 4 : 3
            let projIndex = hasIdColumn ? 5 : 4
            let notesIndex = hasIdColumn ? 6 : 5
            let moodIndex = hasIdColumn ? 7 : 6
            let startTime = (startIndex < fieldCount) ? cleanField(fields[startIndex]) : ""
            let endTime = (endIndex < fieldCount) ? cleanField(fields[endIndex]) : ""
            let durationStr = (durIndex < fieldCount) ? cleanField(fields[durIndex]) : "0"
            let projectName = (projIndex < fieldCount) ? cleanField(fields[projIndex]) : ""
            let notes = (notesIndex < fieldCount) ? cleanField(fields[notesIndex]) : ""
            let moodStr = (moodIndex < fieldCount) ? fields[moodIndex] : ""
            let mood = moodStr.isEmpty ? nil : Int(cleanField(moodStr))
            let durationMinutes = Int(durationStr) ?? 0
            let record = SessionRecord(
                id: id,
                date: dateStr,
                startTime: startTime,
                endTime: endTime,
                durationMinutes: durationMinutes,
                projectName: projectName,
                notes: notes,
                mood: mood
            )
            sessions.append(record)
        }
        // Sort by date descending (string comparison works for yyyy-MM-dd)
        sessions.sort { $0.date > $1.date }
        return sessions
    } catch {
        print("❌ Error loading filtered sessions: \(error)")
        return []
    }
}
    
    // Save all sessions (with IDs) to CSV
    func saveAllSessions(_ sessions: [SessionRecord]) {
        func ensureSeconds(_ time: String) -> String { time.count == 5 ? time + ":00" : time }
        let header = "id,date,start_time,end_time,duration_minutes,project,notes,mood\n"
        let rows = sessions.map { s in
            let project = csvEscape(s.projectName)
            let notes = csvEscape(s.notes)
            let moodStr = s.mood.map(String.init) ?? ""
            let start = ensureSeconds(s.startTime)
            let end = ensureSeconds(s.endTime)
            return "\(s.id),\(s.date),\(start),\(end),\(s.durationMinutes),\(project),\(notes),\(moodStr)"
        }
        let csv = header + rows.joined(separator: "\n") + "\n"
        writeToFile(csv)
        print("[SessionManager] Rewritten CSV with IDs for all sessions.")
    }
    
    // Helper class for export
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
            switch format {
            case "csv":
                path = downloads?.appendingPathComponent("\(baseName).csv") ?? URL(fileURLWithPath: "\(baseName).csv")
                var csv = "date,project,duration_minutes,start_time,end_time,notes,mood\n"
                for session in sessions {
                    let duration = "\(session.durationMinutes)"
                    let start = String(session.startTime.prefix(5)) // HH:mm
                    let end = String(session.endTime.prefix(5))
                    let mood = session.mood.map(String.init) ?? ""
                    csv += "\"\(session.date)\",\"\(csvEscape(session.projectName))\",\(duration),\"\(start)\",\"\(end)\",\"\(csvEscape(session.notes))\",\(mood)\n"
                }
                try? csv.write(to: path, atomically: true, encoding: .utf8)
            case "txt":
                path = downloads?.appendingPathComponent("\(baseName).txt") ?? URL(fileURLWithPath: "\(baseName).txt")
                    var txt = ""
                    sessions.forEach { session in
                        txt += "Date: \(session.date)\nProject: \(session.projectName)\nDuration: \(session.durationMinutes) minutes\nStart: \(String(session.startTime.prefix(5)))\nEnd: \(String(session.endTime.prefix(5)))\nNotes: \(session.notes)\nMood: \(session.mood?.description ?? "N/A")\n\n"
                    }
                try? txt.write(to: path, atomically: true, encoding: .utf8)
            case "md":
                path = downloads?.appendingPathComponent("\(baseName).md") ?? URL(fileURLWithPath: "\(baseName).md")
                var md = "# Juju Sessions\n\n"
                md += "| Date | Project | Duration | Start | End | Notes | Mood |\n|------|---------|----------|-------|-----|-------|------|\n"
                for session in sessions {
                    let duration = "\(session.durationMinutes) min"
                    let start = String(session.startTime.prefix(5))
                    let end = String(session.endTime.prefix(5))
                    let notesEsc = session.notes.replacingOccurrences(of: "|", with: "\\|")
                    let mood = session.mood.map(String.init) ?? ""
                    md += "| \(session.date) | \(session.projectName) | \(duration) | \(start) | \(end) | \(notesEsc) | \(mood) |\n"
                }
                try? md.write(to: path, atomically: true, encoding: .utf8)
            default:
                return nil
            }
            return path
        }
        
        private func csvEscape(_ str: String) -> String {
            return str.replacingOccurrences(of: "\"", with: "\"\"")
        }
    }
} 

// MARK: - CSV helpers
private extension SessionManager {
    func csvEscape(_ s: String) -> String {
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
