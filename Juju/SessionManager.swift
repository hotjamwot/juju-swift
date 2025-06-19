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
    let id: Int
    let date: String
    let startTime: String
    let endTime: String
    let durationMinutes: Int
    let projectName: String
    let notes: String
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
    
    func endSession(notes: String = "") {
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
        saveSessionToCSV(sessionData)
        
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
    
    private func saveSessionToCSV(_ sessionData: SessionData) {
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
        
        let csvRow = "\(date),\(startTime),\(endTime),\(sessionData.durationMinutes),\"\(sessionData.projectName)\",\"\(sessionData.notes)\"\n"
        
        // Check if file exists and needs header
        let needsHeader = !fileExists() || isFileEmpty()
        
        if needsHeader {
            let header = "date,start_time,end_time,duration_minutes,project,notes\n"
            let fullContent = header + csvRow
            writeToFile(fullContent)
            print("✅ Created new CSV file with header and session data")
        } else {
            appendToFile(csvRow)
            print("✅ Appended session data to existing CSV file")
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
            let dataRows = rows.dropFirst()
            print("🔍 Processing \(dataRows.count) data rows")
            var sessions: [SessionRecord] = []
            for (idx, fields) in dataRows.enumerated() {
                if fields.count >= 4 { // allow notes to be optional
                    let safeFields = fields + Array(repeating: "", count: max(0, 6 - fields.count))
                    let record = SessionRecord(
                        id: idx,
                        date: cleanField(safeFields[0]),
                        startTime: cleanField(safeFields[1]),
                        endTime: cleanField(safeFields[2]),
                        durationMinutes: Int(cleanField(safeFields[3])) ?? 0,
                        projectName: cleanField(safeFields[4]),
                        notes: cleanField(safeFields[5])
                    )
                    sessions.append(record)
                    if idx < 3 { // Debug first few records
                        print("🔍 Record \(idx): date=\(record.date), project=\(record.projectName), duration=\(record.durationMinutes)")
                    }
                } else {
                    print("❌ Skipping row \(idx+2) due to insufficient fields: \(fields)")
                }
            }
            print("🔍 Successfully loaded \(sessions.count) sessions")
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
} 