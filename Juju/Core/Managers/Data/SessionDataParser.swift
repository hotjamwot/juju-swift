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
        
        // Detect format based on header
        let headerFields = parseCSVLineOptimized(headerLine)
        let hasNewFields = headerFields.contains("project_id") || headerFields.contains("activity_type_id")
        let hasStartDate = headerFields.contains("start_date")
        let expectedColumnCount = headerFields.count
        
        let dataLines = lines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var sessions: [SessionRecord] = []
        var needsRewrite = false
        
        for (index, line) in dataLines.enumerated() {
            let rowIndex = index + 1  // +1 to skip header
            
            let fields = parseCSVLineOptimized(line)
            
            // Ensure we have at least the expected number of fields
            var safeFields = fields
            
            // Pad with empty strings if we have fewer fields than expected
            if safeFields.count < expectedColumnCount {
                safeFields += Array(repeating: "", count: expectedColumnCount - safeFields.count)
            }
            // DO NOT truncate if we have more fields than expected - this was causing data loss
            // Keep all fields to preserve data integrity
            
            var id: String
            if hasIdColumn {
                id = cleanField(safeFields[0])
            } else {
                // No ID column, generate one
                id = UUID().uuidString
                needsRewrite = true
                safeFields.insert(id, at: 0)
                // After inserting ID, we need to ensure we still have the right count
                if safeFields.count > expectedColumnCount + 1 {
                    safeFields = Array(safeFields.prefix(expectedColumnCount + 1))
                }
            }
            
            // Ensure all required fields exist after potential ID insertion
            while safeFields.count < expectedColumnCount {
                safeFields.append("")
            }
            
            // Handle new migrated format with start_date and end_date
            if hasStartDate {
                let startDateStr = cleanField(safeFields[1])
                let endDateStr = cleanField(safeFields[2])
                
                guard !startDateStr.isEmpty && !endDateStr.isEmpty else {
                    continue
                }
                
                guard let (startDate, _) = parseDate(startDateStr) else {
                    continue
                }
                
                guard let endDate = parseDate(endDateStr)?.date else {
                    continue
                }
                
                // Extract fields based on new format
                // Note: projectName is kept for backward compatibility, projectID is source of truth
                let projectName = safeFields.count > 3 ? (safeFields[3].isEmpty ? "" : cleanField(safeFields[3])) : ""
                let projectID = hasNewFields && safeFields.count > 4 ? (safeFields[4].isEmpty ? nil : cleanField(safeFields[4])) : nil
                let activityTypeID = hasNewFields && safeFields.count > 5 ? (safeFields[5].isEmpty ? nil : cleanField(safeFields[5])) : nil
                let projectPhaseID = hasNewFields && safeFields.count > 6 ? (safeFields[6].isEmpty ? nil : cleanField(safeFields[6])) : nil
                let milestoneText = hasNewFields && safeFields.count > 7 ? (safeFields[7].isEmpty ? nil : cleanField(safeFields[7])) : nil
                let notesIndex = hasNewFields ? 8 : 4
                let moodIndex = hasNewFields ? 9 : 5
                let notes = safeFields.count > notesIndex ? cleanField(safeFields[notesIndex]) : ""
                let mood = safeFields.count > moodIndex ? (safeFields[moodIndex].isEmpty ? nil : Int(cleanField(safeFields[moodIndex]))) : nil
                
                // Resolve project ID from project name if projectID is missing
                let resolvedProjectID = resolveProjectID(from: projectID, projectName: projectName)
                
                // Calculate duration from start and end dates
                let durationMinutes = Int(endDate.timeIntervalSince(startDate) / 60)
                
                // Create session record with all fields using new Date-based initializer
                let record = SessionRecord(
                    id: id,
                    startDate: startDate,
                    endDate: endDate,
                    projectName: projectName,
                    projectID: resolvedProjectID,
                    activityTypeID: activityTypeID,
                    projectPhaseID: projectPhaseID,
                    milestoneText: milestoneText,
                    notes: notes,
                    mood: mood
                )
                
                sessions.append(record)
            } else {
                // Handle old format with separate date, start_time, end_time
                let dateStr = cleanField(safeFields[1])
                guard !dateStr.isEmpty, let (date, _) = parseDate(dateStr) else {
                    continue
                }
                
                // Extract fields based on format
                let projectName = safeFields.count > 5 ? cleanField(safeFields[5]) : ""
                let projectID = hasNewFields && safeFields.count > 6 ? (safeFields[6].isEmpty ? nil : cleanField(safeFields[6])) : nil
                let activityTypeID = hasNewFields && safeFields.count > 7 ? (safeFields[7].isEmpty ? nil : cleanField(safeFields[7])) : nil
                let projectPhaseID = hasNewFields && safeFields.count > 8 ? (safeFields[8].isEmpty ? nil : cleanField(safeFields[8])) : nil
                let milestoneText = hasNewFields && safeFields.count > 9 ? (safeFields[9].isEmpty ? nil : cleanField(safeFields[9])) : nil
                let notesIndex = hasNewFields ? 10 : 6
                let moodIndex = hasNewFields ? 11 : 7
                let notes = safeFields.count > notesIndex ? cleanField(safeFields[notesIndex]) : ""
                let mood = safeFields.count > moodIndex ? (safeFields[moodIndex].isEmpty ? nil : Int(cleanField(safeFields[moodIndex]))) : nil
                
                // Resolve project ID from project name if projectID is missing
                let resolvedProjectID = resolveProjectID(from: projectID, projectName: projectName)
                
                // For legacy format, we need to parse start and end times to create proper Date objects
                let startTime = cleanField(safeFields[2])
                let endTime = cleanField(safeFields[3])
                let durationMinutes = Int(cleanField(safeFields[4])) ?? 0
                
                // Parse start and end times to create full Date objects
                let startDate = combineDateWithTimeString(date, timeString: startTime)
                let endDate = combineDateWithTimeString(date, timeString: endTime)
                
                // Create session record with all fields using new Date-based initializer
                let record = SessionRecord(
                    id: id,
                    startDate: startDate,
                    endDate: endDate,
                    projectName: projectName,
                    projectID: resolvedProjectID,
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
        
        // Detect format based on header
        let headerFields = parseCSVLineOptimized(headerLine)
        let hasNewFields = headerFields.contains("project_id") || headerFields.contains("activity_type_id")
        let hasStartDate = headerFields.contains("start_date")
        
        let dataLines = lines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var sessions: [SessionRecord] = []
        
        for line in dataLines {
            let fields = parseCSVLineOptimized(line)
            let fieldCount = fields.count
            
            // Handle new migrated format with start_date and end_date
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
                let projIndex = hasIdColumn ? 3 : 2
                let projectName = (projIndex < fieldCount) ? cleanField(fields[projIndex]) : ""
                
                // Extract new fields if available
                let projectID = hasNewFields && fieldCount > 4 && fields.count > 4 ? (fields[4].isEmpty ? nil : cleanField(fields[4])) : nil
                let activityTypeID = hasNewFields && fieldCount > 5 && fields.count > 5 ? (fields[5].isEmpty ? nil : cleanField(fields[5])) : nil
                let projectPhaseID = hasNewFields && fieldCount > 6 && fields.count > 6 ? (fields[6].isEmpty ? nil : cleanField(fields[6])) : nil
                let milestoneText = hasNewFields && fieldCount > 7 && fields.count > 7 ? (fields[7].isEmpty ? nil : cleanField(fields[7])) : nil

                let notesIndex = hasNewFields ? 8 : 4
                let moodIndex = hasNewFields ? 9 : 5
                
                let notes = (notesIndex < fieldCount) ? cleanField(fields[notesIndex]) : ""
                let moodStr = (moodIndex < fieldCount) ? fields[moodIndex] : ""
                let mood = moodStr.isEmpty ? nil : Int(cleanField(moodStr))
                
                // Resolve project ID from project name if projectID is missing
                let resolvedProjectID = resolveProjectID(from: projectID, projectName: projectName)
                
                // Calculate duration from start and end dates
                let durationMinutes = Int(endDate.timeIntervalSince(startDate) / 60)
                
                // Create session record with all fields using new Date-based initializer
                let record = SessionRecord(
                    id: id,
                    startDate: startDate,
                    endDate: endDate,
                    projectName: projectName,
                    projectID: resolvedProjectID,
                    activityTypeID: activityTypeID,
                    projectPhaseID: projectPhaseID,
                    milestoneText: milestoneText,
                    notes: notes,
                    mood: mood
                )
                
                sessions.append(record)
            } else {
                // Handle old format with separate date, start_time, end_time
                let dateIndex = hasIdColumn ? 1 : 0
                let dateStr = (dateIndex < fieldCount) ? cleanField(fields[dateIndex]) : ""
                
                guard !dateStr.isEmpty, let (date, _) = parseDate(dateStr),
                      date >= dateInterval.start && date < dateInterval.end else {
                    continue
                }
                
                let id = hasIdColumn ? ((0 < fieldCount) ? cleanField(fields[0]) : UUID().uuidString) : UUID().uuidString
                let startIndex = hasIdColumn ? 2 : 1
                let endIndex = hasIdColumn ? 3 : 2
                let durIndex = hasIdColumn ? 4 : 3
                let projIndex = hasIdColumn ? 5 : 4
                
                let startTime = (startIndex < fieldCount) ? cleanField(fields[startIndex]) : ""
                let endTime = (endIndex < fieldCount) ? cleanField(fields[endIndex]) : ""
                let durationStr = (durIndex < fieldCount) ? cleanField(fields[durIndex]) : "0"
                let projectName = (projIndex < fieldCount) ? cleanField(fields[projIndex]) : ""
                
                // Extract new fields if available
                let projectID = hasNewFields && fieldCount > 6 ? (fields[6].isEmpty ? nil : cleanField(fields[6])) : nil
                let activityTypeID = hasNewFields && fieldCount > 7 ? (fields[7].isEmpty ? nil : cleanField(fields[7])) : nil
                let projectPhaseID = hasNewFields && fieldCount > 8 ? (fields[8].isEmpty ? nil : cleanField(fields[8])) : nil
                let milestoneText = hasNewFields && fieldCount > 9 ? (fields[9].isEmpty ? nil : cleanField(fields[9])) : nil
                let notesIndex = hasNewFields ? 10 : 6
                let moodIndex = hasNewFields ? 11 : 7
                
                let notes = (notesIndex < fieldCount) ? cleanField(fields[notesIndex]) : ""
                let moodStr = (moodIndex < fieldCount) ? fields[moodIndex] : ""
                let mood = moodStr.isEmpty ? nil : Int(cleanField(moodStr))
                let durationMinutes = Int(durationStr) ?? 0
                
                // Resolve project ID from project name if projectID is missing
                let resolvedProjectID = resolveProjectID(from: projectID, projectName: projectName)
                
                // For legacy format, parse start and end times to create proper Date objects
                let startDate = combineDateWithTimeString(date, timeString: startTime)
                let endDate = combineDateWithTimeString(date, timeString: endTime)
                
                // Create session record with all fields using new Date-based initializer
                let record = SessionRecord(
                    id: id,
                    startDate: startDate,
                    endDate: endDate,
                    projectName: projectName,
                    projectID: resolvedProjectID,
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
    
    /// Parse sessions from CSV content, filtering only those within the current week
    /// This is an optimized version that only processes sessions within the specified week interval
    func parseSessionsFromCSVForCurrentWeek(_ csvContent: String, hasIdColumn: Bool, weekInterval: DateInterval) -> ([SessionRecord], Bool) {
        let lines = parseCSVContentWithProperQuoting(csvContent)
        
        guard let headerLine = lines.first, !headerLine.isEmpty else {
            return ([], false)
        }
        
        // Detect format based on header
        let headerFields = parseCSVLineOptimized(headerLine)
        let hasNewFields = headerFields.contains("project_id") || headerFields.contains("activity_type_id")
        let hasStartDate = headerFields.contains("start_date")
        let expectedColumnCount = headerFields.count
        
        let dataLines = lines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var sessions: [SessionRecord] = []
        var needsRewrite = false
        
        for (index, line) in dataLines.enumerated() {
            let rowIndex = index + 1  // +1 to skip header
            
            let fields = parseCSVLineOptimized(line)
            
            // Ensure we have at least the expected number of fields
            var safeFields = fields
            
            // Pad with empty strings if we have fewer fields than expected
            if safeFields.count < expectedColumnCount {
                safeFields += Array(repeating: "", count: expectedColumnCount - safeFields.count)
            }
            // DO NOT truncate if we have more fields than expected - this was causing data loss
            // Keep all fields to preserve data integrity
            
            var id: String
            if hasIdColumn {
                id = cleanField(safeFields[0])
            } else {
                // No ID column, generate one
                id = UUID().uuidString
                needsRewrite = true
                safeFields.insert(id, at: 0)
                // After inserting ID, we need to ensure we still have the right count
                if safeFields.count > expectedColumnCount + 1 {
                    safeFields = Array(safeFields.prefix(expectedColumnCount + 1))
                }
            }
            
            // Ensure all required fields exist after potential ID insertion
            while safeFields.count < expectedColumnCount {
                safeFields.append("")
            }
            
            // Handle new migrated format with start_date and end_date
            if hasStartDate {
                let startDateStr = cleanField(safeFields[1])
                let endDateStr = cleanField(safeFields[2])
                
                guard !startDateStr.isEmpty && !endDateStr.isEmpty,
                      let (startDate, _) = parseDate(startDateStr),
                      let endDate = parseDate(endDateStr)?.date else {
                    continue
                }
                
                // Quick filter: only process sessions within the current week
                guard startDate >= weekInterval.start && startDate <= weekInterval.end else {
                    continue
                }
                
                // Extract fields based on new format
                let projectName = safeFields.count > 3 ? (safeFields[3].isEmpty ? "" : cleanField(safeFields[3])) : ""
                let projectID = hasNewFields && safeFields.count > 4 ? (safeFields[4].isEmpty ? nil : cleanField(safeFields[4])) : nil
                let activityTypeID = hasNewFields && safeFields.count > 5 ? (safeFields[5].isEmpty ? nil : cleanField(safeFields[5])) : nil
                let projectPhaseID = hasNewFields && safeFields.count > 6 ? (safeFields[6].isEmpty ? nil : cleanField(safeFields[6])) : nil
                let milestoneText = hasNewFields && safeFields.count > 7 ? (safeFields[7].isEmpty ? nil : cleanField(safeFields[7])) : nil
                let notesIndex = hasNewFields ? 8 : 4
                let moodIndex = hasNewFields ? 9 : 5
                let notes = safeFields.count > notesIndex ? cleanField(safeFields[notesIndex]) : ""
                let mood = safeFields.count > moodIndex ? (safeFields[moodIndex].isEmpty ? nil : Int(cleanField(safeFields[moodIndex]))) : nil
                
                // Resolve project ID from project name if projectID is missing
                let resolvedProjectID = resolveProjectID(from: projectID, projectName: projectName)
                
                // Calculate duration from start and end dates
                let durationMinutes = Int(endDate.timeIntervalSince(startDate) / 60)
                
                // Create session record with all fields using new Date-based initializer
                let record = SessionRecord(
                    id: id,
                    startDate: startDate,
                    endDate: endDate,
                    projectName: projectName,
                    projectID: resolvedProjectID,
                    activityTypeID: activityTypeID,
                    projectPhaseID: projectPhaseID,
                    milestoneText: milestoneText,
                    notes: notes,
                    mood: mood
                )
                
                sessions.append(record)
            } else {
                // Handle old format with separate date, start_time, end_time
                let dateStr = cleanField(safeFields[1])
                guard !dateStr.isEmpty, let (date, _) = parseDate(dateStr) else {
                    continue
                }
                
                // Quick filter: only process sessions within the current week
                guard date >= weekInterval.start && date <= weekInterval.end else {
                    continue
                }
                
                // Extract fields based on format
                let projectName = safeFields.count > 5 ? cleanField(safeFields[5]) : ""
                let projectID = hasNewFields && safeFields.count > 6 ? (safeFields[6].isEmpty ? nil : cleanField(safeFields[6])) : nil
                let activityTypeID = hasNewFields && safeFields.count > 7 ? (safeFields[7].isEmpty ? nil : cleanField(safeFields[7])) : nil
                let projectPhaseID = hasNewFields && safeFields.count > 8 ? (safeFields[8].isEmpty ? nil : cleanField(safeFields[8])) : nil
                let milestoneText = hasNewFields && safeFields.count > 9 ? (safeFields[9].isEmpty ? nil : cleanField(safeFields[9])) : nil
                let notesIndex = hasNewFields ? 10 : 6
                let moodIndex = hasNewFields ? 11 : 7
                let notes = safeFields.count > notesIndex ? cleanField(safeFields[notesIndex]) : ""
                let mood = safeFields.count > moodIndex ? (safeFields[moodIndex].isEmpty ? nil : Int(cleanField(safeFields[moodIndex]))) : nil
                
                // Resolve project ID from project name if projectID is missing
                let resolvedProjectID = resolveProjectID(from: projectID, projectName: projectName)
                
                // For legacy format, parse start and end times to create proper Date objects
                let startTime = cleanField(safeFields[2])
                let endTime = cleanField(safeFields[3])
                let startDate = combineDateWithTimeString(date, timeString: startTime)
                let endDate = combineDateWithTimeString(date, timeString: endTime)
                
                // Create session record with all fields using new Date-based initializer
                let record = SessionRecord(
                    id: id,
                    startDate: startDate,
                    endDate: endDate,
                    projectName: projectName,
                    projectID: resolvedProjectID,
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
    
    /// Resolve project ID from project name when projectID is missing or empty
    /// This prevents sessions from getting "unknown" project IDs during CSV parsing
    private func resolveProjectID(from projectID: String?, projectName: String) -> String {
        // If we already have a valid projectID, use it
        if let projectID = projectID, !projectID.isEmpty {
            return projectID
        }
        
        // If we have a project name but no projectID, try to resolve it
        if !projectName.isEmpty {
            let projectManager = ProjectManager.shared
            let projects = projectManager.loadProjects()
            
            // Find the project by name (case-insensitive)
            if let project = projects.first(where: { $0.name.lowercased() == projectName.lowercased() }) {
                return project.id
            }
        }
        
        // Fallback: return "unknown" for sessions that can't be resolved
        return "unknown"
    }
    
    // MARK: - CSV Parsing Optimizations
    
    func parseCSVLineOptimized(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                // Check if this is an escaped quote (two consecutive quotes)
                let nextIndex = line.index(after: i)
                if inQuotes && nextIndex < line.endIndex && line[nextIndex] == "\"" {
                    // This is an escaped quote - add one quote to current field
                    currentField.append("\"")
                    // Skip the second quote
                    i = nextIndex
                } else {
                    // This is a field quote - toggle inQuotes
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                // Only split on commas when NOT inside quotes
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
        return field.trimmingCharacters(in: CharacterSet(charactersIn: "\"")).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Parse a date string that could be either "yyyy-MM-dd" or "yyyy-MM-dd HH:mm:ss" format
    /// Returns the date and the extracted date part as a string
    private func parseDate(_ dateStr: String) -> (date: Date, datePart: String)? {
        let cleaned = cleanField(dateStr)
        if cleaned.isEmpty {
            return nil
        }
        
        // Try datetime format first (with time)
        if let dateTime = dateTimeFormatter.date(from: cleaned) {
            // Extract just the date part
            let datePart = String(cleaned.prefix(10)) // "yyyy-MM-dd"
            return (dateTime, datePart)
        }
        
        // Try date-only format
        if let date = dateFormatter.date(from: cleaned) {
            return (date, cleaned)
        }
        
        return nil
    }
    
    /// Combine a Date object with a time string to create a full Date object
    /// - Parameters:
    ///   - date: The date component (Date object)
    ///   - timeString: Time string in format "HH:mm:ss" or "HH:mm"
    /// - Returns: Full Date object combining date and time
    private func combineDateWithTimeString(_ date: Date, timeString: String) -> Date {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        // Pad time string if needed
        let paddedTimeString = timeString.count == 5 ? timeString + ":00" : timeString
        
        guard let timeDate = timeFormatter.date(from: paddedTimeString) else {
            // Fallback to original date if time parsing fails
            return date
        }
        
        // Extract time components
        let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: timeDate)
        let hour = timeComponents.hour ?? 0
        let minute = timeComponents.minute ?? 0
        let second = timeComponents.second ?? 0
        
        // Extract date components
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        
        // Combine date and time
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = hour
        combinedComponents.minute = minute
        combinedComponents.second = second
        
        return Calendar.current.date(from: combinedComponents) ?? date
    }
    
    /// Format a Date object as HH:mm:ss string
    private func formatTime(_ date: Date) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        return timeFormatter.string(from: date)
    }
    
    /// Parse CSV content properly, handling quoted fields that contain line breaks
    /// Uses proper Swift string indexing to avoid parsing errors
    private func parseCSVContentWithProperQuoting(_ content: String) -> [String] {
        // First, split by line endings (handles \n, \r\n, and \r)
        let rawLines = content.components(separatedBy: .newlines)
        
        // Now we need to handle quoted fields that contain line breaks
        var lines: [String] = []
        var currentLine = ""
        var inQuotes = false
        
        for rawLine in rawLines {
            var line = rawLine
            var i = line.startIndex
            
            while i < line.endIndex {
                let char = line[i]
                
                if char == "\"" {
                    // Check if this is an escaped quote (two consecutive quotes)
                    let nextIndex = line.index(after: i)
                    if inQuotes && nextIndex < line.endIndex && line[nextIndex] == "\"" {
                        // This is an escaped quote - just continue, it's part of the content
                        currentLine.append(char)
                        i = nextIndex
                    } else {
                        // This is a field quote - toggle inQuotes
                        inQuotes.toggle()
                        currentLine.append(char)
                    }
                } else {
                    currentLine.append(char)
                }
                
                i = line.index(after: i)
            }
            
            // If we're still in quotes, this line continues on the next line
            if inQuotes {
                currentLine.append("\n")
            } else {
                // Line is complete
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = ""
            }
        }
        
        // Add any remaining content
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines
    }
    
    // MARK: - Session Record to CSV Conversion
    
    func convertSessionsToCSV(_ sessions: [SessionRecord]) -> String {
        let header = "id,start_date,end_date,project,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood\n"
        let rows = sessions.map { s in
            let project = csvEscape(s.projectName)
            let projectID = s.projectID.map { csvEscape($0) } ?? ""
            let activityTypeID = s.activityTypeID.map { csvEscape($0) } ?? ""
            let projectPhaseID = s.projectPhaseID.map { csvEscape($0) } ?? ""
            let milestoneText = s.milestoneText.map { csvEscape($0) } ?? ""
            let notes = csvEscape(s.notes)
            let moodStr = s.mood.map(String.init) ?? ""
            // Use the full startDate and endDate from the SessionRecord (which are Date objects)
            let startDateFormatter = DateFormatter()
            startDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let endDateFormatter = DateFormatter()
            endDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            let startDateStr = startDateFormatter.string(from: s.startDate)
            let endDateStr = endDateFormatter.string(from: s.endDate)
            
            return "\(s.id),\(startDateStr),\(endDateStr),\(project),\(projectID),\(activityTypeID),\(projectPhaseID),\(milestoneText),\(notes),\(moodStr)"
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
            let duration = "\(DurationCalculator.calculateDuration(start: session.startDate, end: session.endDate))"
            let start = formatTime(session.startDate)
            let end = formatTime(session.endDate)
            let mood = session.mood.map(String.init) ?? ""
            // Extract date from startDate
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStr = dateFormatter.string(from: session.startDate)
            csv += "\"\(dateStr)\",\"\(csvEscapeForExport(session.projectName))\",\(duration),\"\(start)\",\"\(end)\",\"\(csvEscapeForExport(session.notes))\",\(mood)\n"
        }
        return csv
    }
    
    private func exportToTXTFormat(_ sessions: [SessionRecord]) -> String {
        var txt = ""
        sessions.forEach { session in
            let start = formatTime(session.startDate)
            let end = formatTime(session.endDate)
            let duration = DurationCalculator.calculateDuration(start: session.startDate, end: session.endDate)
            // Extract date from startDate
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStr = dateFormatter.string(from: session.startDate)
            txt += "Date: \(dateStr)\nProject: \(session.projectName)\nDuration: \(duration) minutes\nStart: \(String(start.prefix(5)))\nEnd: \(String(end.prefix(5)))\nNotes: \(session.notes)\nMood: \(session.mood?.description ?? "N/A")\n\n"
        }
        return txt
    }
    
    private func exportToMarkdownFormat(_ sessions: [SessionRecord]) -> String {
        var md = "# Juju Sessions\n\n"
        md += "| Date | Project | Duration | Start | End | Notes | Mood |\n|------|---------|----------|-------|-----|-------|------|\n"
        for session in sessions {
            let duration = "\(DurationCalculator.calculateDuration(start: session.startDate, end: session.endDate)) min"
            let start = formatTime(session.startDate)
            let end = formatTime(session.endDate)
            let notesEsc = session.notes.replacingOccurrences(of: "|", with: "\\|")
            let mood = session.mood.map(String.init) ?? ""
            // Extract date from startDate
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStr = dateFormatter.string(from: session.startDate)
            md += "| \(dateStr) | \(session.projectName) | \(duration) | \(String(start.prefix(5))) | \(String(end.prefix(5))) | \(notesEsc) | \(mood) |\n"
        }
        return md
    }
    
    // MARK: - Utility Functions
    
    private func ensureSeconds(_ time: String) -> String {
        time.count == 5 ? time + ":00" : time
    }
    
    private func csvEscape(_ string: String) -> String {
        let escapedQuotes = string.replacingOccurrences(of: "\"", with: "\"\"")
        // Keep line breaks but ensure they're properly escaped in CSV format
        // CSV standard allows line breaks inside quoted fields
        return "\"" + escapedQuotes + "\""
    }
    
    private func csvEscapeForExport(_ string: String) -> String {
        string.replacingOccurrences(of: "\"", with: "\"\"")
    }
}
