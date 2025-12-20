import Foundation
import SwiftUI

// MARK: - Core Session Data Models
public struct SessionRecord: Identifiable {
    public let id: String
    let startDate: Date  // Full timestamp: 2024-12-15 22:30:00
    let endDate: Date    // Full timestamp: 2024-12-16 00:02:00
    let projectName: String  // Kept for backward compatibility; use projectID for new sessions
    let projectID: String?  // Updated: Project identifier (required for new sessions, optional for legacy)
    let activityTypeID: String?  // New: Activity Type identifier (nil during active session, set at end)
    let projectPhaseID: String?  // New: Project Phase identifier (optional)
    let milestoneText: String?  // New: Milestone text (optional)
    let notes: String
    let mood: Int?

    

    // Helper to check if session overlaps with a date interval
    func overlaps(with interval: DateInterval) -> Bool {
        return startDate < interval.end && endDate > interval.start
    }
    
    // Convenience initializer for backward compatibility (legacy sessions without new fields)
    init(id: String, date: String, startTime: String, endTime: String, durationMinutes: Int, projectName: String, notes: String, mood: Int?) {
        // Parse date and time strings into full Date objects
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let parsedDate = dateFormatter.date(from: date) else {
            fatalError("Invalid date format: \(date)")
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let paddedStartTime = startTime.count == 5 ? startTime + ":00" : startTime
        let paddedEndTime = endTime.count == 5 ? endTime + ":00" : endTime
        guard let parsedStartTime = timeFormatter.date(from: paddedStartTime),
              let parsedEndTime = timeFormatter.date(from: paddedEndTime) else {
            fatalError("Invalid time format: \(startTime) or \(endTime)")
        }
        
        // Combine date with time components
        var startComponents = Calendar.current.dateComponents([.year, .month, .day], from: parsedDate)
        let startHour = Calendar.current.component(.hour, from: parsedStartTime)
        let startMinute = Calendar.current.component(.minute, from: parsedStartTime)
        let startSecond = Calendar.current.component(.second, from: parsedStartTime)
        startComponents.hour = startHour
        startComponents.minute = startMinute
        startComponents.second = startSecond ?? 0
        
        var endComponents = Calendar.current.dateComponents([.year, .month, .day], from: parsedDate)
        let endHour = Calendar.current.component(.hour, from: parsedEndTime)
        let endMinute = Calendar.current.component(.minute, from: parsedEndTime)
        let endSecond = Calendar.current.component(.second, from: parsedEndTime)
        endComponents.hour = endHour
        endComponents.minute = endMinute
        endComponents.second = endSecond ?? 0
        
        guard let startDate = Calendar.current.date(from: startComponents),
              let endDate = Calendar.current.date(from: endComponents) else {
            fatalError("Failed to create Date objects from components")
        }
        
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
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
        // Parse date and time strings into full Date objects
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let parsedDate = dateFormatter.date(from: date) else {
            fatalError("Invalid date format: \(date)")
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let paddedStartTime = startTime.count == 5 ? startTime + ":00" : startTime
        let paddedEndTime = endTime.count == 5 ? endTime + ":00" : endTime
        guard let parsedStartTime = timeFormatter.date(from: paddedStartTime),
              let parsedEndTime = timeFormatter.date(from: paddedEndTime) else {
            fatalError("Invalid time format: \(startTime) or \(endTime)")
        }
        
        // Combine date with time components
        var startComponents = Calendar.current.dateComponents([.year, .month, .day], from: parsedDate)
        let startHour = Calendar.current.component(.hour, from: parsedStartTime)
        let startMinute = Calendar.current.component(.minute, from: parsedStartTime)
        let startSecond = Calendar.current.component(.second, from: parsedStartTime)
        startComponents.hour = startHour
        startComponents.minute = startMinute
        startComponents.second = startSecond ?? 0
        
        var endComponents = Calendar.current.dateComponents([.year, .month, .day], from: parsedDate)
        let endHour = Calendar.current.component(.hour, from: parsedEndTime)
        let endMinute = Calendar.current.component(.minute, from: parsedEndTime)
        let endSecond = Calendar.current.component(.second, from: parsedEndTime)
        endComponents.hour = endHour
        endComponents.minute = endMinute
        endComponents.second = endSecond ?? 0
        
        guard let startDate = Calendar.current.date(from: startComponents),
              let endDate = Calendar.current.date(from: endComponents) else {
            fatalError("Failed to create Date objects from components")
        }
        
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.projectName = projectName
        self.projectID = projectID
        self.activityTypeID = activityTypeID
        self.projectPhaseID = projectPhaseID
        self.milestoneText = milestoneText
        self.notes = notes
        self.mood = mood
    }
    
    // New initializer for creating sessions with full Date objects (preferred for new sessions)
    init(id: String = UUID().uuidString, startDate: Date, endDate: Date, projectName: String, projectID: String, activityTypeID: String? = nil, projectPhaseID: String? = nil, milestoneText: String? = nil, notes: String = "", mood: Int? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
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
        let newProject = field == "project" ? value : projectName
        let newProjectID = field == "project_id" ? value : projectID ?? ""
        let newActivityTypeID = field == "activity_type_id" ? value : activityTypeID
        let newProjectPhaseID = field == "project_phase_id" ? value : projectPhaseID
        let newMilestoneText = field == "milestone_text" ? value : milestoneText
        let newNotes = field == "notes" ? value : notes
        
        // For date/time updates, we now require full Date objects
        // These fields should be handled by dedicated methods that accept Date parameters
        var newStartDate = startDate
        var newEndDate = endDate
        
        // Handle date field updates
        if field == "date" {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let newDate = dateFormatter.date(from: value) {
                // Update start date
                let startComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: startDate)
                var newStartComponents = Calendar.current.dateComponents([.year, .month, .day], from: newDate)
                newStartComponents.hour = startComponents.hour
                newStartComponents.minute = startComponents.minute
                newStartComponents.second = startComponents.second
                if let updatedStartDate = Calendar.current.date(from: newStartComponents) {
                    newStartDate = updatedStartDate
                }
                
                // Update end date
                let endComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: endDate)
                var newEndComponents = Calendar.current.dateComponents([.year, .month, .day], from: newDate)
                newEndComponents.hour = endComponents.hour
                newEndComponents.minute = endComponents.minute
                newEndComponents.second = endComponents.second
                if let updatedEndDate = Calendar.current.date(from: newEndComponents) {
                    newEndDate = updatedEndDate
                }
            }
        }
        
        // Handle start time field updates
        if field == "startTime" {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            let paddedStartTime = value.count == 5 ? value + ":00" : value
            if let newStartTime = timeFormatter.date(from: paddedStartTime) {
                let startHour = Calendar.current.component(.hour, from: newStartTime)
                let startMinute = Calendar.current.component(.minute, from: newStartTime)
                let startSecond = Calendar.current.component(.second, from: newStartTime)
                
                var newStartComponents = Calendar.current.dateComponents([.year, .month, .day], from: startDate)
                newStartComponents.hour = startHour
                newStartComponents.minute = startMinute
                newStartComponents.second = startSecond ?? 0
                
                if let updatedStartDate = Calendar.current.date(from: newStartComponents) {
                    newStartDate = updatedStartDate
                }
            }
        }
        
        // Handle end time field updates
        if field == "endTime" {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            let paddedEndTime = value.count == 5 ? value + ":00" : value
            if let newEndTime = timeFormatter.date(from: paddedEndTime) {
                let endHour = Calendar.current.component(.hour, from: newEndTime)
                let endMinute = Calendar.current.component(.minute, from: newEndTime)
                let endSecond = Calendar.current.component(.second, from: newEndTime)
                
                var newEndComponents = Calendar.current.dateComponents([.year, .month, .day], from: endDate)
                newEndComponents.hour = endHour
                newEndComponents.minute = endMinute
                newEndComponents.second = endSecond ?? 0
                
                if let updatedEndDate = Calendar.current.date(from: newEndComponents) {
                    newEndDate = updatedEndDate
                }
            }
        }
        
        // Validate and fix end date if it's earlier than start date
        // This handles sessions that cross midnight
        if newEndDate < newStartDate {
            // End date is earlier than start date, assume session crosses midnight
            // Add one day to end date
            if let nextDayEndDate = Calendar.current.date(byAdding: .day, value: 1, to: newEndDate) {
                newEndDate = nextDayEndDate
            }
        }
        
        return SessionRecord(
            id: id,
            startDate: newStartDate,
            endDate: newEndDate,
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
        startDate: Date,
        endDate: Date,
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
            startDate: startDate,
            endDate: endDate,
            projectName: projectName,
            projectID: projectID,
            activityTypeID: activityTypeID,
            projectPhaseID: projectPhaseID,
            milestoneText: milestoneText,
            notes: notes,
            mood: mood
        )
    }
}

enum SessionError: Error {
    case invalidProjectID
    case invalidDate
    case invalidTimeRange
}

// MARK: - Unified Duration Calculator
// This provides a single source of truth for duration calculations across the entire app
struct DurationCalculator {
    
    /// Calculate duration between two full Date objects
    /// - Parameters:
    ///   - start: Start date and time
    ///   - end: End date and time
    /// - Returns: Duration in minutes
    static func calculateDuration(start: Date, end: Date) -> Int {
        let diff = end.timeIntervalSince(start)
        let duration = Int(round(diff / 60))
        
        return duration
    }
    
    /// Calculate duration between two time strings for the same date
    /// - Parameters:
    ///   - startTime: Start time string (HH:mm:ss or HH:mm)
    ///   - endTime: End time string (HH:mm:ss or HH:mm)
    ///   - date: The date for both times
    /// - Returns: Duration in minutes
    static func calculateDuration(startTime: String, endTime: String, on date: String) -> Int {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let parsedDate = dateFormatter.date(from: date) else {
            return 0
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let paddedStartTime = startTime.count == 5 ? startTime + ":00" : startTime
        let paddedEndTime = endTime.count == 5 ? endTime + ":00" : endTime
        guard let parsedStartTime = timeFormatter.date(from: paddedStartTime),
              let parsedEndTime = timeFormatter.date(from: paddedEndTime) else {
            return 0
        }
        
        // Combine date with time components
        var startComponents = Calendar.current.dateComponents([.year, .month, .day], from: parsedDate)
        let startHour = Calendar.current.component(.hour, from: parsedStartTime)
        let startMinute = Calendar.current.component(.minute, from: parsedStartTime)
        let startSecond = Calendar.current.component(.second, from: parsedStartTime)
        startComponents.hour = startHour
        startComponents.minute = startMinute
        startComponents.second = startSecond ?? 0
        
        var endComponents = Calendar.current.dateComponents([.year, .month, .day], from: parsedDate)
        let endHour = Calendar.current.component(.hour, from: parsedEndTime)
        let endMinute = Calendar.current.component(.minute, from: parsedEndTime)
        let endSecond = Calendar.current.component(.second, from: parsedEndTime)
        endComponents.hour = endHour
        endComponents.minute = endMinute
        endComponents.second = endSecond ?? 0
        
        guard let startDate = Calendar.current.date(from: startComponents),
              let endDate = Calendar.current.date(from: endComponents) else {
            return 0
        }
        
        return calculateDuration(start: startDate, end: endDate)
    }
}

// MARK: - Unified Chart Data Model
struct ChartEntry: Identifiable {
    let id = UUID()
    let startDate: Date  // Full timestamp: 2024-12-15 22:30:00
    let endDate: Date    // Full timestamp: 2024-12-16 00:02:00
    let projectName: String
    let projectColor: String
    let projectEmoji: String
    let notes: String
    let mood: Int?
    
    // Calculate duration from startDate and endDate
    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }
    
    var durationHours: Double {
        Double(durationMinutes) / 60.0
    }
    
    // Helper properties for UI formatting when needed
    var date: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: startDate)
    }
    
    var startTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: startDate)
    }
    
    var endTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: endDate)
    }
    
    var projectColorSwiftUI: Color {
        Color(hex: projectColor)
    }
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
    
    /// Create SessionData with automatic duration calculation
    /// - Parameters:
    ///   - startTime: Start date and time
    ///   - endTime: End date and time
    ///   - projectName: Project name (for backward compatibility)
    ///   - projectID: Project identifier
    ///   - activityTypeID: Activity type identifier (optional)
    ///   - projectPhaseID: Project phase identifier (optional)
    ///   - milestoneText: Milestone text (optional)
    ///   - notes: Session notes
    init(
        startTime: Date,
        endTime: Date,
        projectName: String,
        projectID: String,
        activityTypeID: String? = nil,
        projectPhaseID: String? = nil,
        milestoneText: String? = nil,
        notes: String = ""
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.projectName = projectName
        self.projectID = projectID
        self.activityTypeID = activityTypeID
        self.projectPhaseID = projectPhaseID
        self.milestoneText = milestoneText
        self.notes = notes
        
        // Calculate duration using unified calculator
        self.durationMinutes = DurationCalculator.calculateDuration(start: startTime, end: endTime)
    }
}
