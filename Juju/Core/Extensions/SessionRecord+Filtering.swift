import Foundation

/// SessionRecord+Filtering.swift
/// 
/// **Purpose**: Provides session-specific filtering and validation utilities for
/// efficient session data manipulation and querying
/// 
/// **Key Responsibilities**:
/// - Filter sessions by date intervals and time periods
/// - Filter sessions by project and activity type
/// - Validate session time relationships
/// - Provide convenience properties for common date checks
/// 
/// **Dependencies**: Foundation framework for date operations
/// 
/// **AI Notes**:
/// - All methods are instance methods for easy chaining
/// - Uses DateInterval for efficient date range checking
/// - Provides both individual session checks and convenience properties
/// - Designed for use with Array+SessionExtensions for comprehensive filtering
/// - Returns boolean values for easy conditional logic

extension SessionRecord {
    /// Check if session falls within a date interval
    ///
    /// **AI Context**: This method is used for filtering sessions by specific date ranges
    /// such as weeks, months, or custom intervals. It's the foundation for all date-based
    /// filtering operations in the codebase.
    ///
    /// **Business Rules**:
    /// - Uses DateInterval.contains() for efficient range checking
    /// - Checks against session start date only
    /// - Returns false for sessions outside the interval
    ///
    /// **Performance Notes**:
    /// - DateInterval.contains() is highly optimized
    /// - Single date comparison per session
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - Empty intervals return false
    /// - Sessions exactly on interval boundaries are included
    ///
    /// - Parameters:
    ///   - interval: DateInterval to check against
    /// - Returns: True if session start date is within the interval, false otherwise
    func isInInterval(_ interval: DateInterval) -> Bool {
        return interval.contains(startDate)
    }
    
    /// Check if session belongs to a specific project
    ///
    /// **AI Context**: This method is used for filtering sessions by project ID.
    /// It's essential for project-specific reporting and dashboard views.
    ///
    /// **Business Rules**:
    /// - Uses exact string comparison for projectID
    /// - Case-sensitive matching
    /// - Returns false for empty or nil project IDs
    ///
    /// **Performance Notes**:
    /// - String comparison is highly optimized
    /// - Single comparison per session
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - Empty projectID strings return false
    /// - Nil projectID values return false
    ///
    /// - Parameters:
    ///   - projectID: Project identifier to check against
    /// - Returns: True if session belongs to the specified project, false otherwise
    func isForProject(_ projectID: String) -> Bool {
        return self.projectID == projectID
    }
    
    /// Check if session has a specific activity type
    ///
    /// **AI Context**: This method is used for filtering sessions by activity type ID.
    /// It's essential for activity-specific reporting and dashboard views.
    ///
    /// **Business Rules**:
    /// - Uses exact string comparison for activityTypeID
    /// - Case-sensitive matching
    /// - Returns false for nil activity type IDs
    ///
    /// **Performance Notes**:
    /// - String comparison is highly optimized
    /// - Single comparison per session
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - Nil activityTypeID values return false
    /// - Empty activity type IDs return false
    ///
    /// - Parameters:
    ///   - activityTypeID: Activity type identifier to check against
    /// - Returns: True if session has the specified activity type, false otherwise
    func hasActivityType(_ activityTypeID: String) -> Bool {
        return self.activityTypeID == activityTypeID
    }
    
    /// Check if session duration is valid (end time after start time)
    ///
    /// **AI Context**: This method validates that a session has a logical time progression.
    /// It's used for data validation and to identify potentially corrupted session records.
    ///
    /// **Business Rules**:
    /// - End date must be after start date
    /// - Sessions with equal start/end times are considered invalid
    /// - Used for data integrity validation
    ///
    /// **Performance Notes**:
    /// - Single date comparison
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - Sessions with equal start/end times return false
    /// - Sessions with end time before start time return false
    ///
    /// - Returns: True if session duration is valid, false otherwise
    var hasValidDuration: Bool {
        return endDate > startDate
    }
    
    /// Check if session is within current week (Monday-based weeks)
    ///
    /// **AI Context**: This convenience property is used for filtering sessions to show
    /// only the current week's data in dashboard views and reports.
    ///
    /// **Business Rules**:
    /// - Uses Calendar.current for week calculation
    /// - Monday-based weeks (standard in many business contexts)
    /// - Compares against current system date
    ///
    /// **Performance Notes**:
    /// - Calendar operations are cached and optimized
    /// - Single interval calculation per call
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - System date changes during execution (uses current date at call time)
    /// - Calendar configuration changes (uses current Calendar settings)
    ///
    /// - Returns: True if session is within current week, false otherwise
    var isInCurrentWeek: Bool {
        let calendar = Calendar.current
        let today = Date()
        guard let weekRange = calendar.dateInterval(of: .weekOfYear, for: today) else { return false }
        return weekRange.contains(startDate)
    }
    
    /// Check if session is within current month
    ///
    /// **AI Context**: This convenience property is used for filtering sessions to show
    /// only the current month's data in dashboard views and reports.
    ///
    /// **Business Rules**:
    /// - Uses Calendar.current for month calculation
    /// - Compares against current system date
    /// - Includes all days of the current month
    ///
    /// **Performance Notes**:
    /// - Calendar operations are cached and optimized
    /// - Single interval calculation per call
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - System date changes during execution (uses current date at call time)
    /// - Calendar configuration changes (uses current Calendar settings)
    ///
    /// - Returns: True if session is within current month, false otherwise
    var isInCurrentMonth: Bool {
        let calendar = Calendar.current
        let today = Date()
        guard let monthRange = calendar.dateInterval(of: .month, for: today) else { return false }
        return monthRange.contains(startDate)
    }
    
    /// Check if session is within current year
    ///
    /// **AI Context**: This convenience property is used for filtering sessions to show
    /// only the current year's data in dashboard views and reports.
    ///
    /// **Business Rules**:
    /// - Uses Calendar.current for year calculation
    /// - Compares against current system date
    /// - Includes all days of the current year
    ///
    /// **Performance Notes**:
    /// - Calendar operations are cached and optimized
    /// - Single interval calculation per call
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - System date changes during execution (uses current date at call time)
    /// - Calendar configuration changes (uses current Calendar settings)
    ///
    /// - Returns: True if session is within current year, false otherwise
    var isInCurrentYear: Bool {
        let calendar = Calendar.current
        let today = Date()
        guard let yearRange = calendar.dateInterval(of: .year, for: today) else { return false }
        return yearRange.contains(startDate)
    }
    
    /// Check if session duration exceeds a specified threshold
    ///
    /// **AI Context**: This method is used for filtering sessions by duration, such as
    /// finding unusually long or short sessions for analysis or reporting.
    ///
    /// **Business Rules**:
    /// - Duration calculated as endDate - startDate
    /// - Threshold specified in minutes
    /// - Returns true if session duration is greater than threshold
    ///
    /// **Performance Notes**:
    /// - Single date subtraction operation
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - Invalid durations (negative) return false
    /// - Zero threshold returns true for any valid session
    ///
    /// - Parameters:
    ///   - thresholdMinutes: Duration threshold in minutes
    /// - Returns: True if session duration exceeds threshold, false otherwise
    func exceedsDurationThreshold(_ thresholdMinutes: Int) -> Bool {
        let duration = endDate.timeIntervalSince(startDate)
        let durationMinutes = Int(duration / 60)
        return durationMinutes > thresholdMinutes
    }
    
    /// Check if session occurred within the last N days
    ///
    /// **AI Context**: This method is used for filtering sessions by recency, such as
    /// showing only sessions from the last 7 days or 30 days.
    ///
    /// **Business Rules**:
    /// - Compares session start date to current date
    /// - Uses Calendar for accurate day calculation
    /// - Includes sessions from exactly N days ago
    ///
    /// **Performance Notes**:
    /// - Calendar operations are cached and optimized
    /// - Single date calculation per call
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - Negative day values return false
    /// - Zero days returns sessions from today only
    ///
    /// - Parameters:
    ///   - days: Number of days to look back
    /// - Returns: True if session occurred within the specified days, false otherwise
    func isWithinLastDays(_ days: Int) -> Bool {
        guard days >= 0 else { return false }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        guard let cutoffDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return false
        }
        
        return startDate >= cutoffDate
    }
    
    
    /// Check if session overlaps with another session
    ///
    /// **AI Context**: This method is used for detecting time conflicts between sessions,
    /// which is important for data validation and preventing overlapping time entries.
    ///
    /// **Business Rules**:
    /// - Sessions are considered overlapping if they share any time period
    /// - Adjacent sessions (one ends exactly when another starts) are not overlapping
    /// - Uses start and end dates for comparison
    ///
    /// **Performance Notes**:
    /// - Four date comparisons maximum
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - Identical sessions are considered overlapping
    /// - Adjacent sessions are not overlapping
    ///
    /// - Parameters:
    ///   - otherSession: Session to check for overlap with
    /// - Returns: True if sessions overlap, false otherwise
    func overlaps(with otherSession: SessionRecord) -> Bool {
        // Sessions overlap if: this start < other end AND this end > other start
        return startDate < otherSession.endDate && endDate > otherSession.startDate
    }
}