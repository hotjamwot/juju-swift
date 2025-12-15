import Foundation

// MARK: - Core Session Data Models
public struct SessionRecord: Identifiable {
    public let id: String
    let date: String
    let startTime: String
    let endTime: String
    let durationMinutes: Int
    let projectName: String  // Kept for backward compatibility; use projectID for new sessions
    let projectID: String?  // Updated: Project identifier (required for new sessions, optional for legacy)
    let activityTypeID: String?  // New: Activity Type identifier (nil during active session, set at end)
    let projectPhaseID: String?  // New: Project Phase identifier (optional)
    let milestoneText: String?  // New: Milestone text (optional)
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

        var endDate = Calendar.current.date(from: components)
        
        // Fix for sessions that cross midnight: if end time is between midnight and 4 AM,
        // add 24 hours to properly calculate duration across days
        // Special handling for 12:xx AM which appears as 00:xx in 24-hour format
        let endHour: Int
        if endTime.hasPrefix("12:") {
            // 12:xx in the CSV could be 12:xx AM (which is 00:xx) or 12:xx PM (which is 12:xx)
            // We need to check if this is likely a midnight-crossing session
            endHour = 0 // Treat 12:xx as 0 (midnight) for midnight-crossing detection
        } else {
            endHour = timeComponents.hour ?? -1
        }
        
        if endHour >= 0 && endHour < 4 {
            endDate = Calendar.current.date(byAdding: .day, value: 1, to: endDate ?? date)
        }
        
        return endDate
    }

    // Helper to check if session overlaps with a date interval
    func overlaps(with interval: DateInterval) -> Bool {
        guard let start = startDateTime, let end = endDateTime else { return false }
        return start < interval.end && end > interval.start
    }
    
    // Convenience initializer for backward compatibility (legacy sessions without new fields)
    init(id: String, date: String, startTime: String, endTime: String, durationMinutes: Int, projectName: String, notes: String, mood: Int?) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.projectName = projectName
        self.projectID = nil  // Legacy sessions don't have projectID
        self.activityTypeID = nil
        self.projectPhaseID = nil
        self.milestoneText = nil
        self.notes = notes
        self.mood = mood
    }
    
    // Full initializer with all fields
    init(id: String, date: String, startTime: String, endTime: String, durationMinutes: Int, projectName: String, projectID: String?, activityTypeID: String?, projectPhaseID: String?, milestoneText: String?, notes: String, mood: Int?) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.projectName = projectName
        self.projectID = projectID
        self.activityTypeID = activityTypeID
        self.projectPhaseID = projectPhaseID
        self.milestoneText = milestoneText
        self.notes = notes
        self.mood = mood
    }
}

extension SessionRecord {
    func withUpdated(field: String, value: String) -> SessionRecord {
        let newMood: Int? = field == "mood" ? (Int(value) ?? nil) : mood
        let newDate = field == "date" ? value : date
        let newStartTime = field == "start_time" ? value : startTime
        let newEndTime = field == "end_time" ? value : endTime
        let newProject = field == "project" ? value : projectName
        let newProjectID = field == "project_id" ? value : projectID
        let newActivityTypeID = field == "activity_type_id" ? value : activityTypeID
        let newProjectPhaseID = field == "project_phase_id" ? value : projectPhaseID
        let newMilestoneText = field == "milestone_text" ? value : milestoneText
        let newNotes = field == "notes" ? value : notes
        
        return SessionRecord(
            id: id,
            date: newDate,
            startTime: newStartTime,
            endTime: newEndTime,
            durationMinutes: durationMinutes,
            projectName: newProject,
            projectID: newProjectID,
            activityTypeID: newActivityTypeID,
            projectPhaseID: newProjectPhaseID,
            milestoneText: newMilestoneText,
            notes: newNotes,
            mood: newMood
        )
    }
    
    // MARK: - Legacy Data Handling Helpers
    
    /// Get activity type display info with fallback to "Uncategorized" for legacy sessions
    func getActivityTypeDisplay() -> (name: String, emoji: String) {
        return ActivityTypeManager.shared.getActivityTypeDisplay(id: activityTypeID)
    }
    
    /// Get project phase display name with fallback for legacy sessions
    /// Note: This method should be used with caution as it loads projects directly.
    /// For better performance, use the version in SessionsRowView that accepts projects as parameter.
    func getProjectPhaseDisplay() -> String? {
        guard let projectPhaseID = projectPhaseID,
              let projectID = projectID else {
            return nil
        }
        
        let projects = ProjectManager.shared.loadProjects()
        guard let project = projects.first(where: { $0.id == projectID }),
              let phase = project.phases.first(where: { $0.id == projectPhaseID && !$0.archived }) else {
            return nil
        }
        
        return phase.name
    }
    
    /// Check if this is a legacy session (missing activity type or phase)
    var isLegacySession: Bool {
        return activityTypeID == nil && projectPhaseID == nil
    }
    
    /// Check if this session has a valid projectID (required for new sessions)
    var hasValidProjectID: Bool {
        return projectID != nil && !projectID!.isEmpty
    }
    
    /// Create a new session with required projectID validation
    /// - Throws: SessionError.invalidProjectID if projectID is nil or empty
    static func createNewSession(
        id: String = UUID().uuidString,
        date: String,
        startTime: String,
        endTime: String,
        durationMinutes: Int,
        projectName: String,
        projectID: String,
        activityTypeID: String? = nil,
        projectPhaseID: String? = nil,
        milestoneText: String? = nil,
        notes: String = "",
        mood: Int? = nil
    ) throws -> SessionRecord {
        guard !projectID.isEmpty else {
            throw SessionError.invalidProjectID
        }
        
        return SessionRecord(
            id: id,
            date: date,
            startTime: startTime,
            endTime: endTime,
            durationMinutes: durationMinutes,
            projectName: projectName,
            projectID: projectID,
            activityTypeID: activityTypeID,
            projectPhaseID: projectPhaseID,
            milestoneText: milestoneText,
            notes: notes,
            mood: mood
        )
    }
    
    /// Fix sessions that cross midnight by adjusting end time if it's between midnight and 4 AM
    /// This ensures proper duration calculation for sessions that span across days
    /// - Returns: Fixed session record with corrected end time and duration
    func fixMidnightCrossingSession() -> SessionRecord {
        // Parse end time to check if it's between midnight and 4 AM
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let paddedEndTime = endTime.count == 5 ? endTime + ":00" : endTime
        
        guard let endTimeDate = timeFormatter.date(from: paddedEndTime) else {
            return self
        }
        
        // Check if end time is between midnight and 4 AM
        // Special handling for 12:xx AM which appears as 00:xx in 24-hour format
        let endHour: Int
        if endTime.hasPrefix("12:") {
            // 12:xx in the CSV could be 12:xx AM (which is 00:xx) or 12:xx PM (which is 12:xx)
            // We need to check if this is likely a midnight-crossing session
            endHour = 0 // Treat 12:xx as 0 (midnight) for midnight-crossing detection
        } else {
            endHour = Calendar.current.dateComponents([.hour], from: endTimeDate).hour ?? -1
        }
        
        guard endHour >= 0 && endHour < 4 else {
            // End time is not between midnight and 4 AM, no fix needed
            return self
        }
        
        // Check if this session likely crosses midnight by comparing start and end times
        let paddedStartTime = startTime.count == 5 ? startTime + ":00" : startTime
        guard let startTimeDate = timeFormatter.date(from: paddedStartTime) else {
            return self
        }
        
        // If end time is earlier than start time, it likely crosses midnight
        if endTimeDate < startTimeDate {
            // Calculate the actual duration by treating end time as next day
            let nextDayEndTime = Calendar.current.date(byAdding: .day, value: 1, to: endTimeDate)
            let startDateTime = startDateTime ?? Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date()))!
            
            guard let actualEndDateTime = nextDayEndTime else {
                return self
            }
            
            let durationMinutes = Int(round(actualEndDateTime.timeIntervalSince(startDateTime) / 60))
            
            // Only fix if the calculated duration is significantly different from stored duration
            // This prevents fixing sessions that were already correctly calculated
            let durationDifference = abs(durationMinutes - self.durationMinutes)
            if durationDifference > 60 { // Only fix if difference is more than 1 hour
                print("🔧 Fixed midnight-crossing session \(id): \(startTime) -> \(endTime) (next day), duration: \(durationMinutes) minutes (was \(self.durationMinutes))")
                
                // Return fixed session with corrected duration
                return SessionRecord(
                    id: id,
                    date: date,
                    startTime: startTime,
                    endTime: endTime,
                    durationMinutes: durationMinutes,
                    projectName: projectName,
                    projectID: projectID,
                    activityTypeID: activityTypeID,
                    projectPhaseID: projectPhaseID,
                    milestoneText: milestoneText,
                    notes: notes,
                    mood: mood
                )
            } else {
                print("✅ Session \(id) already has correct duration: \(durationMinutes) minutes")
            }
        }
        
        return self
    }
}

enum SessionError: Error {
    case invalidProjectID
    case invalidDate
    case invalidTimeRange
}

// MARK: - Session Data Transfer Object
struct SessionData {
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int
    let projectName: String  // Kept for backward compatibility
    let projectID: String   // Updated: Project identifier (required for new sessions)
    let activityTypeID: String?  // New: Activity Type identifier
    let projectPhaseID: String?  // New: Project Phase identifier
    let milestoneText: String?  // New: Milestone text
    let notes: String
}
