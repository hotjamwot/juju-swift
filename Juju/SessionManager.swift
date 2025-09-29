import Foundation

struct SessionData {
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int
    let projectName: String
    let notes: String
}

// MARK: - Data Structures
struct SessionRecord: Identifiable {
    let id: String
    let date: String
    let startTime: String
    let endTime: String
    let durationMinutes: Int
    let projectName: String
    let notes: String
    let mood: Int?
}

class SessionManager {
    static let shared = SessionManager()
    
    // Session state
    private(set) var isSessionActive = false
    private(set) var currentProjectName: String?
    private(set) var sessionStartTime: Date?
    
    // CSV file path
    private let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    private let jujuPath: URL?
    private let dataFile: URL?
    
    private init() {
        self.jujuPath = appSupportPath?.appendingPathComponent("Juju")
        self.dataFile = jujuPath?.appendingPathComponent("data.csv")
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
            let content = try String(contentsOf: dataFile, encoding: .utf8)
            print("🔍 CSV Content length: \(content.count)")
            let rows = splitCSVRows(content)
            print("🔍 Parsed \(rows.count) rows from CSV")
            guard rows.count > 1 else { print("❌ No session data lines"); return [] }
            let header = rows[0]
            let hasIdColumn = header.first?.lowercased() == "id"
            let dataRows = rows.dropFirst()
            print("🔍 Processing \(dataRows.count) data rows (ID column: \(hasIdColumn))")
            var sessions: [SessionRecord] = []
            var needsRewrite = false
            for (idx, fields) in dataRows.enumerated() {
                var safeFields = fields + Array(repeating: "", count: max(0, 8 - fields.count))
                var id: String
                if hasIdColumn {
                    id = cleanField(safeFields[0])
                } else {
                    // No ID column, generate one
                    id = UUID().uuidString
                    needsRewrite = true
                    print("[SessionManager] Assigned new ID \(id) to row \(idx+2)")
                    safeFields.insert(id, at: 0)
                }
                let record = SessionRecord(
                    id: id,
                    date: cleanField(safeFields[1]),
                    startTime: cleanField(safeFields[2]),
                    endTime: cleanField(safeFields[3]),
                    durationMinutes: Int(cleanField(safeFields[4])) ?? 0,
                    projectName: cleanField(safeFields[5]),
                    notes: cleanField(safeFields[6]),
                    mood: safeFields[7].isEmpty ? nil : Int(cleanField(safeFields[7]))
                )
                sessions.append(record)
                if idx < 3 { // Debug first few records
                    print("🔍 Record \(idx): id=\(record.id), date=\(record.date), project=\(record.projectName), duration=\(record.durationMinutes)")
                }
            }
            print("🔍 Successfully loaded \(sessions.count) sessions")
            // If any IDs were assigned, rewrite the CSV with IDs
            if needsRewrite {
                print("[SessionManager] Rewriting CSV to add IDs to all rows...")
                saveAllSessions(sessions)
            }
            return sessions
        } catch {
            print("❌ Error loading sessions: \(error)")
            return []
        }
    }
    
    // Clean field by removing quotes and trimming whitespace
    private func cleanField(_ field: String) -> String {
        return field.trimmingCharacters(in: CharacterSet(charactersIn: "\"")).trimmingCharacters(in: .whitespacesAndNewlines)
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
} 

// MARK: - CSV helpers
private extension SessionManager {
    func csvEscape(_ s: String) -> String {
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}