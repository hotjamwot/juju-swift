import Foundation

// MARK: - Core Session Data Models
public struct SessionRecord: Identifiable {
    public let id: String
    let date: String
    let startTime: String
    let endTime: String
    let durationMinutes: Int
    let projectName: String  // Kept for backward compatibility; use projectID for new sessions
    let projectID: String?  // New: Project identifier (optional to support interim state)
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

        return Calendar.current.date(from: components)
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
}

// MARK: - Session Data Transfer Object
struct SessionData {
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int
    let projectName: String  // Kept for backward compatibility
    let projectID: String?  // New: Project identifier
    let activityTypeID: String?  // New: Activity Type identifier
    let projectPhaseID: String?  // New: Project Phase identifier
    let milestoneText: String?  // New: Milestone text
    let notes: String
}
