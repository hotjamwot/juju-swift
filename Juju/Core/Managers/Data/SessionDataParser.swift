import Foundation

// MARK: - Session Data Parser
class SessionDataParser {
    private let dateFormatter: DateFormatter
    
    init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
    }
    
    // MARK: - CSV to SessionRecord Conversion
    
    func parseSessionsFromCSV(_ csvContent: String, hasIdColumn: Bool = true) -> ([SessionRecord], Bool) {
        let lines = parseCSVContentWithProperQuoting(csvContent)
        
        guard let headerLine = lines.first, !headerLine.isEmpty else {
            return ([], false)
        }
        
        let dataLines = lines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var sessions: [SessionRecord] = []
        var needsRewrite = false
        
        for (index, line) in dataLines.enumerated() {
            let rowIndex = index + 1  // +1 to skip header
            
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
        
        return (sessions, needsRewrite)
    }
    
    func parseSessionsFromCSVForDateRange(_ csvContent: String, hasIdColumn: Bool, dateInterval: DateInterval) -> [SessionRecord] {
        let lines = parseCSVContentWithProperQuoting(csvContent)
        
        guard let headerLine = lines.first, !headerLine.isEmpty else {
            return []
        }
        
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
                  date >= dateInterval.start && date < dateInterval.end else {
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
        
        return sessions
    }
    
    // MARK: - CSV Parsing Optimizations
    
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
    
    private func cleanField(_ field: String) -> String {
        return field.trimmingCharacters(in: CharacterSet(charactersIn: "\"")).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Parse CSV content properly, handling quoted fields that contain line breaks
    private func parseCSVContentWithProperQuoting(_ content: String) -> [String] {
        var lines: [String] = []
        var currentLine = ""
        var inQuotes = false
        
        for char in content {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "\n" && !inQuotes {
                lines.append(currentLine)
                currentLine = ""
                continue
            }
            currentLine.append(char)
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines
    }
    
    // MARK: - Session Record to CSV Conversion
    
    func convertSessionsToCSV(_ sessions: [SessionRecord]) -> String {
        let header = "id,date,start_time,end_time,duration_minutes,project,notes,mood\n"
        let rows = sessions.map { s in
            let project = csvEscape(s.projectName)
            let notes = csvEscape(s.notes)
            let moodStr = s.mood.map(String.init) ?? ""
            let start = ensureSeconds(s.startTime)
            let end = ensureSeconds(s.endTime)
            return "\(s.id),\(s.date),\(start),\(end),\(s.durationMinutes),\(project),\(notes),\(moodStr)"
        }
        return header + rows.joined(separator: "\n") + "\n"
    }
    
    func convertSessionsToCSVForExport(_ sessions: [SessionRecord], format: String) -> String {
        switch format {
        case "csv":
            return exportToCSVFormat(sessions)
        case "txt":
            return exportToTXTFormat(sessions)
        case "md":
            return exportToMarkdownFormat(sessions)
        default:
            return ""
        }
    }
    
    private func exportToCSVFormat(_ sessions: [SessionRecord]) -> String {
        var csv = "date,project,duration_minutes,start_time,end_time,notes,mood\n"
        for session in sessions {
            let duration = "\(session.durationMinutes)"
            let start = String(session.startTime.prefix(5)) // HH:mm
            let end = String(session.endTime.prefix(5))
            let mood = session.mood.map(String.init) ?? ""
            csv += "\"\(session.date)\",\"\(csvEscapeForExport(session.projectName))\",\(duration),\"\(start)\",\"\(end)\",\"\(csvEscapeForExport(session.notes))\",\(mood)\n"
        }
        return csv
    }
    
    private func exportToTXTFormat(_ sessions: [SessionRecord]) -> String {
        var txt = ""
        sessions.forEach { session in
            txt += "Date: \(session.date)\nProject: \(session.projectName)\nDuration: \(session.durationMinutes) minutes\nStart: \(String(session.startTime.prefix(5)))\nEnd: \(String(session.endTime.prefix(5)))\nNotes: \(session.notes)\nMood: \(session.mood?.description ?? "N/A")\n\n"
        }
        return txt
    }
    
    private func exportToMarkdownFormat(_ sessions: [SessionRecord]) -> String {
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
        return md
    }
    
    // MARK: - Utility Functions
    
    private func ensureSeconds(_ time: String) -> String {
        time.count == 5 ? time + ":00" : time
    }
    
    private func csvEscape(_ string: String) -> String {
        "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    
    private func csvEscapeForExport(_ string: String) -> String {
        string.replacingOccurrences(of: "\"", with: "\"\"")
    }
}
