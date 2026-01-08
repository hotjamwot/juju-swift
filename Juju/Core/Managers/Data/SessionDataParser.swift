import Foundation

// MARK: - Session Data Parser
class SessionDataParser {
    private let dateFormatter: DateFormatter
    private let dateTimeFormatter: DateFormatter
    
    init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
        
        self.dateTimeFormatter = DateFormatter()
        self.dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    // MARK: - CSV to SessionRecord Conversion
    
    func parseSessionsFromCSV(_ csvContent: String, hasIdColumn: Bool = true) -> ([SessionRecord], Bool) {
        let lines = parseCSVContentWithProperQuoting(csvContent)
        
        guard let headerLine = lines.first, !headerLine.isEmpty else {
            return ([], false)
        }
        
        let headerFields = parseCSVLineOptimized(headerLine)
        let hasNewFields = headerFields.contains("project_id") || headerFields.contains("activity_type_id")
        let hasStartDate = headerFields.contains("start_date")
        let expectedColumnCount = headerFields.count
        
        let dataLines = lines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var sessions: [SessionRecord] = []
        var needsRewrite = false
        
        for (index, line) in dataLines.enumerated() {
            let fields = parseCSVLineOptimized(line)
            var safeFields = fields
            
            if safeFields.count < expectedColumnCount {
                safeFields += Array(repeating: "", count: expectedColumnCount - safeFields.count)
            }
            
            var id: String
            if hasIdColumn {
                id = cleanField(safeFields[0])
            } else {
                id = UUID().uuidString
                needsRewrite = true
            }
            
            while safeFields.count < expectedColumnCount {
                safeFields.append("")
            }
            
            // Handle new format with start_date and end_date
            if hasStartDate {
                let startDateStr = cleanField(safeFields[1])
                let endDateStr = cleanField(safeFields[2])
                
                guard !startDateStr.isEmpty && !endDateStr.isEmpty,
                      let (startDate, _) = parseDate(startDateStr),
                      let endDate = parseDate(endDateStr)?.date else {
                    continue
                }
                
                let projectID: String
                if hasNewFields {
                    // Check if we have the legacy format with projectName field
                    if headerFields.contains("project") && headerFields.firstIndex(of: "project") == 3 {
                        // Legacy format: id,start_date,end_date,project,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        projectID = cleanField(safeFields[4]) // project_id is at index 4
                    } else {
                        // New format: id,start_date,end_date,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        projectID = cleanField(safeFields[3]) // project_id is at index 3
                    }
                } else {
                    projectID = resolveProjectID(fromProjectName: cleanField(safeFields[3]))
                }
                
                guard !projectID.isEmpty else { continue }
                
                let activityTypeID: String?
                let projectPhaseID: String?
                let milestoneText: String?
                let notes: String
                let mood: Int?
                
                if hasNewFields {
                    if headerFields.contains("project") && headerFields.firstIndex(of: "project") == 3 {
                        // Legacy format: id,start_date,end_date,project,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        activityTypeID = cleanField(safeFields[5]).nilIfEmpty // activity_type_id is at index 5
                        projectPhaseID = cleanField(safeFields[6]).nilIfEmpty // project_phase_id is at index 6
                        milestoneText = cleanField(safeFields[7]).nilIfEmpty // milestone_text is at index 7
                        notes = cleanField(safeFields[8]) // notes is at index 8
                        mood = parseMood(safeFields[9]) // mood is at index 9
                    } else {
                        // New format: id,start_date,end_date,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        activityTypeID = cleanField(safeFields[4]).nilIfEmpty // activity_type_id is at index 4
                        projectPhaseID = cleanField(safeFields[5]).nilIfEmpty // project_phase_id is at index 5
                        milestoneText = cleanField(safeFields[6]).nilIfEmpty // milestone_text is at index 6
                        notes = cleanField(safeFields[7]) // notes is at index 7
                        mood = parseMood(safeFields[8]) // mood is at index 8
                    }
                } else {
                    activityTypeID = nil
                    projectPhaseID = nil
                    milestoneText = nil
                    notes = cleanField(safeFields.count > 4 ? safeFields[4] : "")
                    mood = parseMood(safeFields.count > 5 ? safeFields[5] : "")
                }
                
                let record = SessionRecord(
                    id: id,
                    startDate: startDate,
                    endDate: endDate,
                    projectID: projectID,
                    activityTypeID: activityTypeID,
                    projectPhaseID: projectPhaseID,
                    milestoneText: milestoneText,
                    notes: notes,
                    mood: mood
                )
                
                sessions.append(record)
            } else {
                // Handle old format
                let dateStr = cleanField(safeFields[1])
                guard !dateStr.isEmpty, let (date, _) = parseDate(dateStr) else {
                    continue
                }
                
                let projectID: String
                if hasNewFields {
                    projectID = cleanField(safeFields[6])
                } else {
                    projectID = resolveProjectID(fromProjectName: cleanField(safeFields[5]))
                }
                
                guard !projectID.isEmpty else { continue }
                
                let startTime = cleanField(safeFields[2])
                let endTime = cleanField(safeFields[3])
                let startDate = combineDateWithTimeString(date, timeString: startTime)
                let endDate = combineDateWithTimeString(date, timeString: endTime)
                
                let activityTypeID = hasNewFields ? cleanField(safeFields[7]).nilIfEmpty : nil
                let projectPhaseID = hasNewFields ? cleanField(safeFields[8]).nilIfEmpty : nil
                let milestoneText = hasNewFields ? cleanField(safeFields[9]).nilIfEmpty : nil
                let notes = cleanField(hasNewFields ? safeFields[10] : safeFields[6])
                let mood = parseMood(hasNewFields ? safeFields[11] : safeFields[7])
                
                let record = SessionRecord(
                    id: id,
                    startDate: startDate,
                    endDate: endDate,
                    projectID: projectID,
                    activityTypeID: activityTypeID,
                    projectPhaseID: projectPhaseID,
                    milestoneText: milestoneText,
                    notes: notes,
                    mood: mood
                )
                
                sessions.append(record)
            }
        }
        
        return (sessions, needsRewrite)
    }
    
    func parseSessionsFromCSVForDateRange(_ csvContent: String, hasIdColumn: Bool, dateInterval: DateInterval) -> [SessionRecord] {
        let lines = parseCSVContentWithProperQuoting(csvContent)
        
        guard let headerLine = lines.first, !headerLine.isEmpty else {
            return []
        }
        
        let headerFields = parseCSVLineOptimized(headerLine)
        let hasNewFields = headerFields.contains("project_id") || headerFields.contains("activity_type_id")
        let hasStartDate = headerFields.contains("start_date")
        
        let dataLines = lines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var sessions: [SessionRecord] = []
        
        for line in dataLines {
            let fields = parseCSVLineOptimized(line)
            let fieldCount = fields.count
            
            if hasStartDate {
                let startDateIndex = hasIdColumn ? 1 : 0
                let endDateIndex = hasIdColumn ? 2 : 1
                let startDateStr = (startDateIndex < fieldCount) ? cleanField(fields[startDateIndex]) : ""
                let endDateStr = (endDateIndex < fieldCount) ? cleanField(fields[endDateIndex]) : ""
                
                guard !startDateStr.isEmpty && !endDateStr.isEmpty,
                      let (startDate, _) = parseDate(startDateStr),
                      let endDate = parseDate(endDateStr)?.date,
                      startDate >= dateInterval.start && startDate < dateInterval.end else {
                    continue
                }
                
                let id = hasIdColumn ? ((0 < fieldCount) ? cleanField(fields[0]) : UUID().uuidString) : UUID().uuidString
                
                let projectID: String
                if hasNewFields {
                    // Check if we have the legacy format with projectName field
                    if headerFields.contains("project") && headerFields.firstIndex(of: "project") == 3 {
                        // Legacy format: id,start_date,end_date,project,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        projectID = cleanField(fields[4]) // project_id is at index 4
                    } else {
                        // New format: id,start_date,end_date,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        projectID = cleanField(fields[3]) // project_id is at index 3
                    }
                } else {
                    projectID = resolveProjectID(fromProjectName: (hasIdColumn && fieldCount > 3) ? cleanField(fields[3]) : "")
                }
                
                guard !projectID.isEmpty else { continue }
                
                let activityTypeID: String?
                let projectPhaseID: String?
                let milestoneText: String?
                let notes: String
                let mood: Int?
                
                if hasNewFields {
                    if headerFields.contains("project") && headerFields.firstIndex(of: "project") == 3 {
                        // Legacy format: id,start_date,end_date,project,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        activityTypeID = cleanField(fields[5]).nilIfEmpty // activity_type_id is at index 5
                        projectPhaseID = cleanField(fields[6]).nilIfEmpty // project_phase_id is at index 6
                        milestoneText = cleanField(fields[7]).nilIfEmpty // milestone_text is at index 7
                        notes = cleanField(fields[8]) // notes is at index 8
                        mood = parseMood(fields[9]) // mood is at index 9
                    } else {
                        // New format: id,start_date,end_date,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        activityTypeID = cleanField(fields[4]).nilIfEmpty // activity_type_id is at index 4
                        projectPhaseID = cleanField(fields[5]).nilIfEmpty // project_phase_id is at index 5
                        milestoneText = cleanField(fields[6]).nilIfEmpty // milestone_text is at index 6
                        notes = cleanField(fields[7]) // notes is at index 7
                        mood = parseMood(fields[8]) // mood is at index 8
                    }
                } else {
                    activityTypeID = nil
                    projectPhaseID = nil
                    milestoneText = nil
                    notes = cleanField(fieldCount > 4 ? fields[4] : "")
                    mood = parseMood(fieldCount > 5 ? fields[5] : "")
                }
                
                let record = SessionRecord(
                    id: id,
                    startDate: startDate,
                    endDate: endDate,
                    projectID: projectID,
                    activityTypeID: activityTypeID,
                    projectPhaseID: projectPhaseID,
                    milestoneText: milestoneText,
                    notes: notes,
                    mood: mood
                )
                
                sessions.append(record)
            } else {
                let dateIndex = hasIdColumn ? 1 : 0
                let dateStr = (dateIndex < fieldCount) ? cleanField(fields[dateIndex]) : ""
                
                guard !dateStr.isEmpty, let (date, _) = parseDate(dateStr),
                      date >= dateInterval.start && date < dateInterval.end else {
                    continue
                }
                
                let id = hasIdColumn ? ((0 < fieldCount) ? cleanField(fields[0]) : UUID().uuidString) : UUID().uuidString
                
                let projectID: String
                if hasNewFields && fieldCount > 6 {
                    projectID = cleanField(fields[6])
                } else {
                    projectID = resolveProjectID(fromProjectName: (hasIdColumn && fieldCount > 5) ? cleanField(fields[5]) : "")
                }
                
                guard !projectID.isEmpty else { continue }
                
                let activityTypeID = (hasNewFields && fieldCount > 7) ? cleanField(fields[7]).nilIfEmpty : nil
                let projectPhaseID = (hasNewFields && fieldCount > 8) ? cleanField(fields[8]).nilIfEmpty : nil
                let milestoneText = (hasNewFields && fieldCount > 9) ? cleanField(fields[9]).nilIfEmpty : nil
                
                let notesIndex = hasNewFields ? 10 : 6
                let moodIndex = hasNewFields ? 11 : 7
                let notes = (notesIndex < fieldCount) ? cleanField(fields[notesIndex]) : ""
                let mood = (moodIndex < fieldCount) ? parseMood(fields[moodIndex]) : nil
                
                let startTime = (hasIdColumn && fieldCount > 2) ? cleanField(fields[2]) : ""
                let endTime = (hasIdColumn && fieldCount > 3) ? cleanField(fields[3]) : ""
                let startDate = combineDateWithTimeString(date, timeString: startTime)
                let endDate = combineDateWithTimeString(date, timeString: endTime)
                
                let record = SessionRecord(
                    id: id,
                    startDate: startDate,
                    endDate: endDate,
                    projectID: projectID,
                    activityTypeID: activityTypeID,
                    projectPhaseID: projectPhaseID,
                    milestoneText: milestoneText,
                    notes: notes,
                    mood: mood
                )
                
                sessions.append(record)
            }
        }
        
        return sessions
    }
    
    func parseSessionsFromCSVForCurrentWeek(_ csvContent: String, hasIdColumn: Bool, weekInterval: DateInterval) -> ([SessionRecord], Bool) {
        let lines = parseCSVContentWithProperQuoting(csvContent)
        
        guard let headerLine = lines.first, !headerLine.isEmpty else {
            return ([], false)
        }
        
        let headerFields = parseCSVLineOptimized(headerLine)
        let hasNewFields = headerFields.contains("project_id") || headerFields.contains("activity_type_id")
        let hasStartDate = headerFields.contains("start_date")
        let expectedColumnCount = headerFields.count
        
        let dataLines = lines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var sessions: [SessionRecord] = []
        var needsRewrite = false
        
        for (index, line) in dataLines.enumerated() {
            let fields = parseCSVLineOptimized(line)
            var safeFields = fields
            
            if safeFields.count < expectedColumnCount {
                safeFields += Array(repeating: "", count: expectedColumnCount - safeFields.count)
            }
            
            var id: String
            if hasIdColumn {
                id = cleanField(safeFields[0])
            } else {
                id = UUID().uuidString
                needsRewrite = true
            }
            
            while safeFields.count < expectedColumnCount {
                safeFields.append("")
            }
            
            if hasStartDate {
                let startDateStr = cleanField(safeFields[1])
                let endDateStr = cleanField(safeFields[2])
                
                guard !startDateStr.isEmpty && !endDateStr.isEmpty,
                      let (startDate, _) = parseDate(startDateStr),
                      let endDate = parseDate(endDateStr)?.date else {
                    continue
                }
                
                guard weekInterval.contains(startDate) else { continue }
                
                let projectID: String
                if hasNewFields {
                    // Check if we have the legacy format with projectName field
                    if headerFields.contains("project") && headerFields.firstIndex(of: "project") == 3 {
                        // Legacy format: id,start_date,end_date,project,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        projectID = cleanField(safeFields[4]) // project_id is at index 4
                    } else {
                        // New format: id,start_date,end_date,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        projectID = cleanField(safeFields[3]) // project_id is at index 3
                    }
                } else {
                    projectID = resolveProjectID(fromProjectName: cleanField(safeFields[3]))
                }
                
                guard !projectID.isEmpty else { continue }
                
                let activityTypeID: String?
                let projectPhaseID: String?
                let milestoneText: String?
                let notes: String
                let mood: Int?
                
                if hasNewFields {
                    if headerFields.contains("project") && headerFields.firstIndex(of: "project") == 3 {
                        // Legacy format: id,start_date,end_date,project,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        activityTypeID = cleanField(safeFields[5]).nilIfEmpty // activity_type_id is at index 5
                        projectPhaseID = cleanField(safeFields[6]).nilIfEmpty // project_phase_id is at index 6
                        milestoneText = cleanField(safeFields[7]).nilIfEmpty // milestone_text is at index 7
                        notes = cleanField(safeFields[8]) // notes is at index 8
                        mood = parseMood(safeFields[9]) // mood is at index 9
                    } else {
                        // New format: id,start_date,end_date,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        activityTypeID = cleanField(safeFields[4]).nilIfEmpty // activity_type_id is at index 4
                        projectPhaseID = cleanField(safeFields[5]).nilIfEmpty // project_phase_id is at index 5
                        milestoneText = cleanField(safeFields[6]).nilIfEmpty // milestone_text is at index 6
                        notes = cleanField(safeFields[7]) // notes is at index 7
                        mood = parseMood(safeFields[8]) // mood is at index 8
                    }
                } else {
                    activityTypeID = nil
                    projectPhaseID = nil
                    milestoneText = nil
                    notes = cleanField(safeFields.count > 4 ? safeFields[4] : "")
                    mood = parseMood(safeFields.count > 5 ? safeFields[5] : "")
                }
                
                let record = SessionRecord(
                    id: id,
                    startDate: startDate,
                    endDate: endDate,
                    projectID: projectID,
                    activityTypeID: activityTypeID,
                    projectPhaseID: projectPhaseID,
                    milestoneText: milestoneText,
                    notes: notes,
                    mood: mood
                )
                
                sessions.append(record)
            } else {
                let dateStr = cleanField(safeFields[1])
                guard !dateStr.isEmpty, let (date, _) = parseDate(dateStr) else {
                    continue
                }
                
                guard date >= weekInterval.start && date <= weekInterval.end else {
                    continue
                }
                
                let projectID: String
                if hasNewFields {
                    projectID = cleanField(safeFields[6])
                } else {
                    projectID = resolveProjectID(fromProjectName: cleanField(safeFields[5]))
                }
                
                guard !projectID.isEmpty else { continue }
                
                let startTime = cleanField(safeFields[2])
                let endTime = cleanField(safeFields[3])
                let startDate = combineDateWithTimeString(date, timeString: startTime)
                let endDate = combineDateWithTimeString(date, timeString: endTime)
                
                let activityTypeID = hasNewFields ? cleanField(safeFields[7]).nilIfEmpty : nil
                let projectPhaseID = hasNewFields ? cleanField(safeFields[8]).nilIfEmpty : nil
                let milestoneText = hasNewFields ? cleanField(safeFields[9]).nilIfEmpty : nil
                let notes = cleanField(hasNewFields ? safeFields[10] : safeFields[6])
                let mood = parseMood(hasNewFields ? safeFields[11] : safeFields[7])
                
                let record = SessionRecord(
                    id: id,
                    startDate: startDate,
                    endDate: endDate,
                    projectID: projectID,
                    activityTypeID: activityTypeID,
                    projectPhaseID: projectPhaseID,
                    milestoneText: milestoneText,
                    notes: notes,
                    mood: mood
                )
                
                sessions.append(record)
            }
        }
        
        return (sessions, needsRewrite)
    }
    
    // MARK: - Project ID Resolution
    
    private func resolveProjectID(fromProjectName projectName: String) -> String {
        guard !projectName.isEmpty else { return "unknown" }
        
        let projectManager = ProjectManager.shared
        let projects = projectManager.loadProjects()
        
        if let project = projects.first(where: { $0.name.lowercased() == projectName.lowercased() }) {
            return project.id
        }
        
        return "unknown"
    }
    
    // MARK: - CSV Parsing
    
    func parseCSVLineOptimized(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                let nextIndex = line.index(after: i)
                if inQuotes && nextIndex < line.endIndex && line[nextIndex] == "\"" {
                    currentField.append("\"")
                    i = nextIndex
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
                currentField = ""
            } else {
                currentField.append(char)
            }
            
            i = line.index(after: i)
        }
        
        fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
        return fields
    }
    
    private func cleanField(_ field: String) -> String {
        field.trimmingCharacters(in: CharacterSet(charactersIn: "\"")).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseDate(_ dateStr: String) -> (date: Date, datePart: String)? {
        let cleaned = cleanField(dateStr)
        if cleaned.isEmpty { return nil }
        
        if let dateTime = dateTimeFormatter.date(from: cleaned) {
            return (dateTime, String(cleaned.prefix(10)))
        }
        
        if let date = dateFormatter.date(from: cleaned) {
            return (date, cleaned)
        }
        
        return nil
    }
    
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
    
    private func formatTime(_ date: Date) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        return timeFormatter.string(from: date)
    }
    
    private func parseCSVContentWithProperQuoting(_ content: String) -> [String] {
        let rawLines = content.components(separatedBy: .newlines)
        var lines: [String] = []
        var currentLine = ""
        var inQuotes = false
        
        for rawLine in rawLines {
            var line = rawLine
            var i = line.startIndex
            
            while i < line.endIndex {
                let char = line[i]
                
                if char == "\"" {
                    let nextIndex = line.index(after: i)
                    if inQuotes && nextIndex < line.endIndex && line[nextIndex] == "\"" {
                        currentLine.append(char)
                        i = nextIndex
                    } else {
                        inQuotes.toggle()
                        currentLine.append(char)
                    }
                } else {
                    currentLine.append(char)
                }
                
                i = line.index(after: i)
            }
            
            if inQuotes {
                currentLine.append("\n")
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = ""
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines
    }
    
    // MARK: - Session Record to CSV Conversion
    
    func convertSessionsToCSV(_ sessions: [SessionRecord]) -> String {
        let header = "id,start_date,end_date,project,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood\n"
        let rows = sessions.map { s in
            let projectID = csvEscape(s.projectID)
            let activityTypeID = s.activityTypeID.map { csvEscape($0) } ?? ""
            let projectPhaseID = s.projectPhaseID.map { csvEscape($0) } ?? ""
            let milestoneText = s.milestoneText.map { csvEscape($0) } ?? ""
            let notes = csvEscape(s.notes)
            let moodStr = s.mood.map(String.init) ?? ""
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let startDateStr = dateFormatter.string(from: s.startDate)
            let endDateStr = dateFormatter.string(from: s.endDate)
            
            // Correct field order: id,start_date,end_date,project,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
            // Note: project field is kept for backward compatibility but should be empty
            return "\(s.id),\(startDateStr),\(endDateStr),,\(projectID),\(activityTypeID),\(projectPhaseID),\(milestoneText),\(notes),\(moodStr)"
        }
        return header + rows.joined(separator: "\n") + "\n"
    }
    
    func convertSessionsToCSVForExport(_ sessions: [SessionRecord], format: String) -> String {
        switch format {
        case "csv": return exportToCSVFormat(sessions)
        case "txt": return exportToTXTFormat(sessions)
        case "md": return exportToMarkdownFormat(sessions)
        default: return ""
        }
    }
    
    private func exportToCSVFormat(_ sessions: [SessionRecord]) -> String {
        var csv = "date,project,duration_minutes,start_time,end_time,notes,mood\n"
        let projectManager = ProjectManager.shared
        let projects = projectManager.loadProjects()
        
        for session in sessions {
            let duration = "\(session.durationMinutes)"
            let start = formatTime(session.startDate)
            let end = formatTime(session.endDate)
            let mood = session.mood.map(String.init) ?? ""
            let projectName = projects.first { $0.id == session.projectID }?.name ?? session.projectID
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStr = dateFormatter.string(from: session.startDate)
            csv += "\"\(dateStr)\",\"\(csvEscapeForExport(projectName))\",\(duration),\"\(start)\",\"\(end)\",\"\(csvEscapeForExport(session.notes))\",\(mood)\n"
        }
        return csv
    }
    
    private func exportToTXTFormat(_ sessions: [SessionRecord]) -> String {
        let projectManager = ProjectManager.shared
        let projects = projectManager.loadProjects()
        
        var txt = ""
        for session in sessions {
            let start = formatTime(session.startDate)
            let end = formatTime(session.endDate)
            let projectName = projects.first { $0.id == session.projectID }?.name ?? session.projectID
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStr = dateFormatter.string(from: session.startDate)
            txt += "Date: \(dateStr)\nProject: \(projectName)\nDuration: \(session.durationMinutes) minutes\nStart: \(String(start.prefix(5)))\nEnd: \(String(end.prefix(5)))\nNotes: \(session.notes)\nMood: \(session.mood?.description ?? "N/A")\n\n"
        }
        return txt
    }
    
    private func exportToMarkdownFormat(_ sessions: [SessionRecord]) -> String {
        let projectManager = ProjectManager.shared
        let projects = projectManager.loadProjects()
        
        var md = "# Juju Sessions\n\n"
        md += "| Date | Project | Duration | Start | End | Notes | Mood |\n|------|---------|----------|-------|-----|-------|------|\n"
        for session in sessions {
            let duration = "\(session.durationMinutes) min"
            let start = formatTime(session.startDate)
            let end = formatTime(session.endDate)
            let notesEsc = session.notes.replacingOccurrences(of: "|", with: "\\|")
            let mood = session.mood.map(String.init) ?? ""
            let projectName = projects.first { $0.id == session.projectID }?.name ?? session.projectID
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStr = dateFormatter.string(from: session.startDate)
            md += "| \(dateStr) | \(projectName) | \(duration) | \(String(start.prefix(5))) | \(String(end.prefix(5))) | \(notesEsc) | \(mood) |\n"
        }
        return md
    }
    
    // MARK: - Utility Functions
    
    private func csvEscape(_ string: String) -> String {
        let escapedQuotes = string.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"" + escapedQuotes + "\""
    }
    
    private func csvEscapeForExport(_ string: String) -> String {
        string.replacingOccurrences(of: "\"", with: "\"\"")
    }
    
    private func parseMood(_ value: String) -> Int? {
        let cleaned = cleanField(value)
        guard !cleaned.isEmpty else { return nil }
        return Int(cleaned)
    }
    
    // MARK: - Query-Based Loading
    
    /// Parse sessions from CSV content using a SessionQuery for efficient filtering
    func parseSessionsFromCSVWithQuery(_ csvContent: String, query: SessionQuery) -> [SessionRecord] {
        let lines = parseCSVContentWithProperQuoting(csvContent)
        
        guard let headerLine = lines.first, !headerLine.isEmpty else {
            return []
        }
        
        let headerFields = parseCSVLineOptimized(headerLine)
        let hasNewFields = headerFields.contains("project_id") || headerFields.contains("activity_type_id")
        let hasStartDate = headerFields.contains("start_date")
        let hasIdColumn = headerFields.contains("id")
        
        let dataLines = lines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var sessions: [SessionRecord] = []
        
        for line in dataLines {
            let fields = parseCSVLineOptimized(line)
            let fieldCount = fields.count
            
            // Early exit if we don't have enough fields
            if fieldCount < 4 { continue }
            
            // Parse session data based on format
            let session: SessionRecord?
            
            if hasStartDate {
                // New format with start_date and end_date
                let startDateIndex = hasIdColumn ? 1 : 0
                let endDateIndex = hasIdColumn ? 2 : 1
                let startDateStr = (startDateIndex < fieldCount) ? cleanField(fields[startDateIndex]) : ""
                let endDateStr = (endDateIndex < fieldCount) ? cleanField(fields[endDateIndex]) : ""
                
                guard !startDateStr.isEmpty && !endDateStr.isEmpty,
                      let (startDate, _) = parseDate(startDateStr),
                      let endDate = parseDate(endDateStr)?.date else {
                    continue
                }
                
                let id = hasIdColumn ? ((0 < fieldCount) ? cleanField(fields[0]) : UUID().uuidString) : UUID().uuidString
                
                let projectID: String
                if hasNewFields {
                    // Check if we have the legacy format with projectName field
                    if headerFields.contains("project") && headerFields.firstIndex(of: "project") == 3 {
                        // Legacy format: id,start_date,end_date,project,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        projectID = cleanField(fields[4]) // project_id is at index 4
                    } else {
                        // New format: id,start_date,end_date,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        projectID = cleanField(fields[3]) // project_id is at index 3
                    }
                } else {
                    projectID = resolveProjectID(fromProjectName: (hasIdColumn && fieldCount > 3) ? cleanField(fields[3]) : "")
                }
                
                guard !projectID.isEmpty else { continue }
                
                let activityTypeID: String?
                let projectPhaseID: String?
                let milestoneText: String?
                let notes: String
                let mood: Int?
                
                if hasNewFields {
                    if headerFields.contains("project") && headerFields.firstIndex(of: "project") == 3 {
                        // Legacy format: id,start_date,end_date,project,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        activityTypeID = cleanField(fields[5]).nilIfEmpty // activity_type_id is at index 5
                        projectPhaseID = cleanField(fields[6]).nilIfEmpty // project_phase_id is at index 6
                        milestoneText = cleanField(fields[7]).nilIfEmpty // milestone_text is at index 7
                        notes = cleanField(fields[8]) // notes is at index 8
                        mood = parseMood(fields[9]) // mood is at index 9
                    } else {
                        // New format: id,start_date,end_date,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood
                        activityTypeID = cleanField(fields[4]).nilIfEmpty // activity_type_id is at index 4
                        projectPhaseID = cleanField(fields[5]).nilIfEmpty // project_phase_id is at index 5
                        milestoneText = cleanField(fields[6]).nilIfEmpty // milestone_text is at index 6
                        notes = cleanField(fields[7]) // notes is at index 7
                        mood = parseMood(fields[8]) // mood is at index 8
                    }
                } else {
                    activityTypeID = nil
                    projectPhaseID = nil
                    milestoneText = nil
                    notes = cleanField(fieldCount > 4 ? fields[4] : "")
                    mood = parseMood(fieldCount > 5 ? fields[5] : "")
                }
                
                session = SessionRecord(
                    id: id,
                    startDate: startDate,
                    endDate: endDate,
                    projectID: projectID,
                    activityTypeID: activityTypeID,
                    projectPhaseID: projectPhaseID,
                    milestoneText: milestoneText,
                    notes: notes,
                    mood: mood
                )
            } else {
                // Old format with date, start_time, end_time
                let dateIndex = hasIdColumn ? 1 : 0
                let dateStr = (dateIndex < fieldCount) ? cleanField(fields[dateIndex]) : ""
                
                guard !dateStr.isEmpty, let (date, _) = parseDate(dateStr) else {
                    continue
                }
                
                let id = hasIdColumn ? ((0 < fieldCount) ? cleanField(fields[0]) : UUID().uuidString) : UUID().uuidString
                
                let projectID: String
                if hasNewFields && fieldCount > 6 {
                    projectID = cleanField(fields[6])
                } else {
                    projectID = resolveProjectID(fromProjectName: (hasIdColumn && fieldCount > 5) ? cleanField(fields[5]) : "")
                }
                
                guard !projectID.isEmpty else { continue }
                
                let activityTypeID = (hasNewFields && fieldCount > 7) ? cleanField(fields[7]).nilIfEmpty : nil
                let projectPhaseID = (hasNewFields && fieldCount > 8) ? cleanField(fields[8]).nilIfEmpty : nil
                let milestoneText = (hasNewFields && fieldCount > 9) ? cleanField(fields[9]).nilIfEmpty : nil
                
                let notesIndex = hasNewFields ? 10 : 6
                let moodIndex = hasNewFields ? 11 : 7
                let notes = (notesIndex < fieldCount) ? cleanField(fields[notesIndex]) : ""
                let mood = (moodIndex < fieldCount) ? parseMood(fields[moodIndex]) : nil
                
                let startTime = (hasIdColumn && fieldCount > 2) ? cleanField(fields[2]) : ""
                let endTime = (hasIdColumn && fieldCount > 3) ? cleanField(fields[3]) : ""
                let startDate = combineDateWithTimeString(date, timeString: startTime)
                let endDate = combineDateWithTimeString(date, timeString: endTime)
                
                session = SessionRecord(
                    id: id,
                    startDate: startDate,
                    endDate: endDate,
                    projectID: projectID,
                    activityTypeID: activityTypeID,
                    projectPhaseID: projectPhaseID,
                    milestoneText: milestoneText,
                    notes: notes,
                    mood: mood
                )
            }
            
            // Apply query filtering
            if let session = session, query.matches(session) {
                sessions.append(session)
            }
        }
        
        // Apply pagination
        return query.applyPagination(to: sessions)
    }
}

// MARK: - String Extension
private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
    
    var isEmptyOrWhitespace: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
    
