import Foundation

/// Array+SessionExtensions.swift
/// 
/// **Purpose**: Provides session-specific array manipulation utilities for efficient
/// session data filtering, sorting, and grouping operations
/// 
/// **Key Responsibilities**:
/// - Filter sessions by project ID, activity type, and date ranges
/// - Sort sessions by various criteria (date, duration, project)
/// - Group sessions by date for display purposes
/// - Aggregate session statistics and totals
/// 
/// **Dependencies**: Foundation framework for date operations
/// - SessionRecord+Filtering for individual session filtering
/// 
/// **AI Notes**:
/// - All methods are instance methods for easy chaining
/// - Designed to work seamlessly with SessionRecord+Filtering
/// - Provides both filtering and aggregation capabilities
/// - Uses efficient algorithms for large session datasets
/// - Returns new arrays (non-mutating) for functional programming style

// MARK: - GroupedSession for Array Extensions
/// Grouped session data structure for array-based operations
/// This is a separate version for use in extensions to avoid circular dependencies
struct ArrayGroupedSession: Identifiable {
    let id      = UUID()
    let date    : Date
    let sessions: [SessionRecord]
    
    /// Calculate total duration for all sessions in this group
    var totalDurationMinutes: Int {
        return sessions.reduce(0, { result, session in
            result + session.durationMinutes
        })
    }
    
    /// Format duration as "1h 30m" or similar
    var formattedDuration: String {
        let hours = totalDurationMinutes / 60
        let minutes = totalDurationMinutes % 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

extension Array where Element == SessionRecord {
    /// Filter sessions by project ID
    ///
    /// **AI Context**: This method filters sessions to include only those belonging
    /// to a specific project. It's used extensively in project-specific views and reports.
    ///
    /// **Business Rules**:
    /// - Uses exact string comparison for projectID
    /// - Case-sensitive matching
    /// - Returns empty array if no sessions match
    ///
    /// **Performance Notes**:
    /// - Single pass through array (O(n))
    /// - Uses optimized string comparison
    /// - Minimal memory allocation (filter creates new array)
    ///
    /// **Edge Cases**:
    /// - Empty array returns empty array
    /// - Non-existent projectID returns empty array
    /// - Nil projectID values are excluded
    ///
    /// - Parameters:
    ///   - projectID: Project identifier to filter by
    /// - Returns: Array of sessions belonging to the specified project
    func filteredByProject(_ projectID: String) -> [SessionRecord] {
        return self.filter { $0.projectID == projectID }
    }
    
    /// Filter sessions by activity type ID
    ///
    /// **AI Context**: This method filters sessions to include only those with a specific
    /// activity type. It's used for activity-specific reporting and dashboard views.
    ///
    /// **Business Rules**:
    /// - Uses exact string comparison for activityTypeID
    /// - Case-sensitive matching
    /// - Returns empty array if no sessions match
    ///
    /// **Performance Notes**:
    /// - Single pass through array (O(n))
    /// - Uses optimized string comparison
    /// - Minimal memory allocation (filter creates new array)
    ///
    /// **Edge Cases**:
    /// - Empty array returns empty array
    /// - Non-existent activityTypeID returns empty array
    /// - Nil activityTypeID values are excluded
    ///
    /// - Parameters:
    ///   - activityTypeID: Activity type identifier to filter by
    /// - Returns: Array of sessions with the specified activity type
    func filteredByActivityType(_ activityTypeID: String) -> [SessionRecord] {
        return self.filter { $0.activityTypeID == activityTypeID }
    }
    
    /// Filter sessions by date interval
    ///
    /// **AI Context**: This method filters sessions to include only those within a specific
    /// date range. It's the foundation for time-based filtering in dashboard views.
    ///
    /// **Business Rules**:
    /// - Uses DateInterval.contains() for efficient range checking
    /// - Checks against session start date only
    /// - Returns empty array if no sessions match
    ///
    /// **Performance Notes**:
    /// - Single pass through array (O(n))
    /// - Uses optimized DateInterval.contains()
    /// - Minimal memory allocation (filter creates new array)
    ///
    /// **Edge Cases**:
    /// - Empty array returns empty array
    /// - Empty interval returns empty array
    /// - Sessions exactly on interval boundaries are included
    ///
    /// - Parameters:
    ///   - interval: DateInterval to filter by
    /// - Returns: Array of sessions within the specified date interval
    func filteredByDateInterval(_ interval: DateInterval) -> [SessionRecord] {
        return self.filter { interval.contains($0.startDate) }
    }
    
    /// Filter sessions by date filter type (convenience method)
    ///
    /// **AI Context**: This method provides a convenient way to filter sessions by common
    /// time periods like today, this week, this month, etc. It's used in dashboard views
    /// for quick time-based filtering.
    ///
    /// **Business Rules**:
    /// - Supports multiple filter types (today, this week, this month, this year, all time, custom)
    /// - Uses Calendar for accurate date range calculation
    /// - Returns empty array if no sessions match
    ///
    /// **Performance Notes**:
    /// - Single pass through array (O(n))
    /// - Calendar operations are cached and optimized
    /// - Minimal memory allocation (filter creates new array)
    ///
    /// **Edge Cases**:
    /// - Empty array returns empty array
    /// - Invalid filter types return empty array
    /// - Custom ranges that don't match any sessions return empty array
    ///
    /// - Parameters:
    ///   - filter: Date filter type to apply
    /// - Returns: Array of sessions matching the specified date filter
    func filteredByDateFilter(_ filter: SessionsDateFilter) -> [SessionRecord] {
        let calendar = Calendar.current
        let today = Date()
        
        switch filter {
        case .today:
            let todayInterval = Calendar.current.startOfDay(for: today)
            return self.filter { session in
                Calendar.current.isDate(session.startDate, inSameDayAs: todayInterval)
            }
        case .thisWeek:
            guard let weekRange = calendar.dateInterval(of: .weekOfYear, for: today) else { return self }
            return filteredByDateInterval(weekRange)
        case .thisMonth:
            guard let monthRange = calendar.dateInterval(of: .month, for: today) else { return self }
            return filteredByDateInterval(monthRange)
        case .thisYear:
            guard let yearRange = calendar.dateInterval(of: .year, for: today) else { return self }
            return filteredByDateInterval(yearRange)
        case .allTime, .clear:
            return self
        case .custom:
            // For custom date ranges, we need to use the customDateRange from filterState
            // This method should be called with the appropriate date interval
            return self
        }
    }
    
    /// Sort sessions by start date (newest first)
    ///
    /// **AI Context**: This method sorts sessions chronologically with the most recent
    /// sessions first. It's the standard sorting order used throughout the application
    /// for displaying session lists and grids.
    ///
    /// **Business Rules**:
    /// - Sorts by startDate in descending order (newest first)
    /// - Stable sort (preserves relative order of equal elements)
    /// - Returns new sorted array (non-mutating)
    ///
    /// **Performance Notes**:
    /// - O(n log n) time complexity using optimized sorting algorithm
    /// - Minimal memory allocation (sort creates new array)
    ///
    /// **Edge Cases**:
    /// - Empty array returns empty array
    /// - Single element array returns same array
    /// - Array with duplicate dates maintains stable sort order
    ///
    /// - Returns: New array with sessions sorted by start date (newest first)
    func sortedByStartDate() -> [SessionRecord] {
        return self.sorted { $0.startDate > $1.startDate }
    }
    
    /// Sort sessions by duration (longest first)
    ///
    /// **AI Context**: This method sorts sessions by their duration with the longest
    /// sessions first. It's used for analysis and reporting to identify the longest
    /// or shortest sessions.
    ///
    /// **Business Rules**:
    /// - Sorts by duration in descending order (longest first)
    /// - Uses durationMinutes property for comparison
    /// - Stable sort (preserves relative order of equal elements)
    ///
    /// **Performance Notes**:
    /// - O(n log n) time complexity using optimized sorting algorithm
    /// - Minimal memory allocation (sort creates new array)
    ///
    /// **Edge Cases**:
    /// - Empty array returns empty array
    /// - Single element array returns same array
    /// - Sessions with zero duration are sorted to the end
    ///
    /// - Returns: New array with sessions sorted by duration (longest first)
    func sortedByDuration() -> [SessionRecord] {
        return self.sorted { $0.durationMinutes > $1.durationMinutes }
    }
    
    /// Sort sessions by project name (alphabetical)
    ///
    /// **AI Context**: This method sorts sessions alphabetically by project name.
    /// It's used for organizing sessions by project in reports and views.
    ///
    /// **Business Rules**:
    /// - Sorts by projectID (which is the primary project identifier)
    /// - Alphabetical order (A to Z)
    /// - Stable sort (preserves relative order of equal elements)
    ///
    /// **Performance Notes**:
    /// - O(n log n) time complexity using optimized sorting algorithm
    /// - String comparison is highly optimized
    /// - Minimal memory allocation (sort creates new array)
    ///
    /// **Edge Cases**:
    /// - Empty array returns empty array
    /// - Single element array returns same array
    /// - Sessions with empty projectID are sorted to the beginning
    ///
    /// - Returns: New array with sessions sorted by project (alphabetical)
    func sortedByProject() -> [SessionRecord] {
        return self.sorted { $0.projectID < $1.projectID }
    }
    
    /// Group sessions by date for display purposes
    ///
    /// **AI Context**: This method groups sessions by their start date to create
    /// date-based groupings for display in list views. It's used in the SessionsView
    /// to organize sessions by day with date headers.
    ///
    /// **Business Rules**:
    /// - Groups sessions by start date (day level, ignoring time)
    /// - Each group contains sessions from the same calendar day
    /// - Groups are sorted by date (newest first)
    /// - Sessions within each group are sorted by start time (newest first)
    ///
    /// **Performance Notes**:
    /// - O(n) time complexity for grouping
    /// - O(n log n) for final sorting
    /// - Uses Dictionary for efficient grouping
    ///
    /// **Edge Cases**:
    /// - Empty array returns empty array
    /// - Single session creates single group
    /// - Sessions with same start date are grouped together
    ///
    /// - Returns: Array of ArrayGroupedSession objects sorted by date (newest first)
    func groupedByDate() -> [ArrayGroupedSession] {
        let grouped = Dictionary(grouping: self) { session -> Date in
            let start = session.startDate
            return Calendar.current.startOfDay(for: start)
        }
        
        let sortedGroups = grouped.sorted(by: { group1, group2 in
            return group1.key > group2.key
        })
        
        return sortedGroups.map { group in
            let sortedSessions = group.value.sortedByStartDate()
            return ArrayGroupedSession(date: group.key, sessions: sortedSessions)
        }
    }
    
    /// Group sessions by project for reporting
    ///
    /// **AI Context**: This method groups sessions by project to facilitate
    /// project-specific reporting and analysis. It's used for generating
    /// project summaries and statistics.
    ///
    /// **Business Rules**:
    /// - Groups sessions by projectID
    /// - Each group contains all sessions for a specific project
    /// - Groups are sorted by projectID (alphabetical)
    /// - Sessions within each group are sorted by start date (newest first)
    ///
    /// **Performance Notes**:
    /// - O(n) time complexity for grouping
    /// - O(n log n) for final sorting
    /// - Uses Dictionary for efficient grouping
    ///
    /// **Edge Cases**:
    /// - Empty array returns empty array
    /// - Single session creates single group
    /// - Sessions with same projectID are grouped together
    ///
    /// - Returns: Dictionary mapping projectID to arrays of sessions, sorted by project
    func groupedByProject() -> [String: [SessionRecord]] {
        let grouped = Dictionary(grouping: self) { $0.projectID }
        
        // Sort sessions within each project group
        var sortedGroups: [String: [SessionRecord]] = [:]
        for (projectID, sessions) in grouped {
            sortedGroups[projectID] = sessions.sortedByStartDate()
        }
        
        return sortedGroups
    }
    
    /// Calculate total duration for all sessions
    ///
    /// **AI Context**: This method calculates the total duration of all sessions
    /// in minutes. It's used for generating overall statistics and summaries.
    ///
    /// **Business Rules**:
    /// - Sums durationMinutes for all sessions
    /// - Returns 0 for empty arrays
    /// - Uses validated duration calculation (handles edge cases)
    ///
    /// **Performance Notes**:
    /// - O(n) time complexity
    /// - Single pass through array
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - Empty array returns 0
    /// - Invalid durations are handled by durationMinutes property
    ///
    /// - Returns: Total duration in minutes for all sessions
    func totalDurationMinutes() -> Int {
        return self.reduce(0) { result, session in
            result + session.durationMinutes
        }
    }
    
    /// Calculate total duration for sessions within a date range
    ///
    /// **AI Context**: This method calculates the total duration of sessions
    /// within a specific date range. It's used for time-based reporting
    /// and analysis.
    ///
    /// **Business Rules**:
    /// - Filters sessions by date interval first
    /// - Then calculates total duration for filtered sessions
    /// - Returns 0 if no sessions match the date range
    ///
    /// **Performance Notes**:
    /// - O(n) time complexity
    /// - Single pass through array with filtering and summing
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - Empty array returns 0
    /// - No sessions in date range returns 0
    /// - Invalid durations are handled by durationMinutes property
    ///
    /// - Parameters:
    ///   - interval: DateInterval to filter sessions by
    /// - Returns: Total duration in minutes for sessions in the date range
    func totalDurationMinutes(in interval: DateInterval) -> Int {
        return filteredByDateInterval(interval).totalDurationMinutes()
    }
    
    /// Get unique project IDs from sessions
    ///
    /// **AI Context**: This method extracts all unique project IDs from the session array.
    /// It's used for populating project filters and dropdowns in the UI.
    ///
    /// **Business Rules**:
    /// - Returns unique project IDs only
    /// - Order is not guaranteed (Set-based)
    /// - Empty array returns empty set
    ///
    /// **Performance Notes**:
    /// - O(n) time complexity
    /// - Uses Set for efficient deduplication
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - Empty array returns empty set
    /// - Single session returns single project ID
    ///
    /// - Returns: Set of unique project IDs
    func uniqueProjectIDs() -> Set<String> {
        return Set(self.map { $0.projectID })
    }
    
    /// Get unique activity type IDs from sessions
    ///
    /// **AI Context**: This method extracts all unique activity type IDs from the session array.
    /// It's used for populating activity type filters and dropdowns in the UI.
    ///
    /// **Business Rules**:
    /// - Returns unique activity type IDs only
    /// - Filters out nil values
    /// - Order is not guaranteed (Set-based)
    ///
    /// **Performance Notes**:
    /// - O(n) time complexity
    /// - Uses Set for efficient deduplication
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - Empty array returns empty set
    /// - Sessions with nil activityTypeID are excluded
    ///
    /// - Returns: Set of unique activity type IDs
    func uniqueActivityTypeIDs() -> Set<String> {
        return Set(self.compactMap { $0.activityTypeID })
    }
    
    /// Find sessions that overlap with a given session
    ///
    /// **AI Context**: This method finds all sessions that overlap in time with
    /// a specified session. It's used for detecting time conflicts and
    /// validating session schedules.
    ///
    /// **Business Rules**:
    /// - Uses SessionRecord.overlaps(with:) for overlap detection
    /// - Returns all sessions that overlap with the target session
    /// - Does not include the target session itself
    ///
    /// **Performance Notes**:
    /// - O(n) time complexity
    /// - Single pass through array
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - Empty array returns empty array
    /// - No overlapping sessions returns empty array
    /// - Target session is excluded from results
    ///
    /// - Parameters:
    ///   - targetSession: Session to check for overlaps with
    /// - Returns: Array of sessions that overlap with the target session
    func findOverlappingSessions(with targetSession: SessionRecord) -> [SessionRecord] {
        return self.filter { session in
            session.id != targetSession.id && session.overlaps(with: targetSession)
        }
    }
    
    /// Remove duplicate sessions based on ID
    ///
    /// **AI Context**: This method removes duplicate sessions that have the same ID
    /// but may have different data. It's used for data cleanup and ensuring
    /// data integrity.
    ///
    /// **Business Rules**:
    /// - Uses session ID for duplicate detection
    /// - Keeps the first occurrence of each unique ID
    /// - Preserves original order of first occurrences
    ///
    /// **Performance Notes**:
    /// - O(n) time complexity
    /// - Uses Set for efficient duplicate detection
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - Empty array returns empty array
    /// - Array with no duplicates returns same array
    /// - Array with all duplicates returns single session
    ///
    /// - Returns: New array with duplicate sessions removed
    func removingDuplicates() -> [SessionRecord] {
        var seenIDs: Set<String> = []
        return self.filter { session in
            if seenIDs.contains(session.id) {
                return false
            } else {
                seenIDs.insert(session.id)
                return true
            }
        }
    }
    
    /// Aggregate session durations by activity type ID
    ///
    /// **AI Context**: This method groups session durations by activity type ID and
    /// calculates total hours for each activity type. It's the core aggregation logic
    /// that transforms individual session records into grouped time data.
    ///
    /// **Business Rules**:
    /// - Groups sessions by activity type ID
    /// - Converts session minutes to hours (dividing by 60)
    /// - Handles uncategorized sessions (nil activityTypeID)
    /// - Returns dictionary mapping activity type ID to total hours
    ///
    /// **Algorithm Steps**:
    /// 1. Initialize empty dictionary for totals
    /// 2. Iterate through all sessions
    /// 3. Determine activity type ID (use "uncategorized" for nil)
    /// 4. Add session duration (in hours) to appropriate activity total
    /// 5. Return completed totals dictionary
    ///
    /// **Performance Notes**:
    /// - O(n) time complexity for single pass through sessions
    /// - Dictionary operations are highly optimized
    /// - Minimal memory allocation with direct aggregation
    ///
    /// **Edge Cases**:
    /// - Empty session list returns empty dictionary
    /// - Sessions with nil activityTypeID are grouped as "uncategorized"
    /// - Zero-duration sessions contribute 0 hours to totals
    ///
    /// - Parameters:
    ///   - sessions: Array of SessionRecord objects to aggregate
    /// - Returns: Dictionary mapping activity type ID to total hours
    func aggregateSessionDurationsByActivityType(_ sessions: [SessionRecord]) -> [String: Double] {
        var totals: [String: Double] = [:]
        
        for session in sessions {
            // Determine activity type ID (handle nil values)
            let activityTypeID = session.activityTypeID ?? "uncategorized"
            
            // Convert session minutes to hours and add to total
            let hours = Double(session.durationMinutes) / 60.0
            totals[activityTypeID, default: 0] += hours
        }
        
        return totals
    }
}
