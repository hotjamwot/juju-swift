import Foundation
import SwiftUI

/// ChartDataPreparer.swift
/// 
/// **Purpose**: Prepares and aggregates session data for dashboard visualizations
/// including weekly, monthly, and yearly charts with activity type and project breakdowns
/// 
/// **Key Responsibilities**:
/// - Data aggregation for dashboard charts (activity types, projects, time periods)
/// - Session filtering by time intervals (weekly, yearly)
/// - Chart data model preparation for UI components
/// - Integration with ActivityTypeManager for activity categorization
/// 
/// **Dependencies**:
/// - SessionManager: For session data access
/// - ProjectManager: For project information and colors
/// - ActivityTypeManager: For activity type categorization
/// - ChartDataModels: For chart data structures
/// 
/// **AI Quick Find (Method Index)**:
/// - Data Prep: prepareWeeklyData(), prepareAllTimeData(), prepareYearlyData()
/// - Aggregation: aggregateActivityTypeTotals(), aggregateProjectTotals()
/// - Filtering: filterSessionsByDateInterval(), filterByActivityType()
/// - Chart Points: createActivityChartData(), createProjectChartData()
/// - Utilities: currentWeekInterval (computed), currentYearInterval (computed)
/// 
/// **AI Gotchas**:
/// - [GOTCHA] Input MUST be sessionManager.allSessions (pre-loaded); not lazily fetched
/// - [GOTCHA] Filters archived projects from yearly charts but NOT from weekly (design choice)
/// - [GOTCHA] Percentages calculated as: (total / grandTotal) * 100; handle division-by-zero
/// - [GOTCHA] Monday-based weeks; week boundaries may differ from calendar view
/// - [GOTCHA] Session minutes converted to hours; small sessions round to 0.0 hours visually
/// - [GOTCHA] Activity type names resolved from ActivityTypeManager; missing types show as "uncategorized"
/// 
/// **AI Integrations**:
/// - [RECEIVES] sessionManager.allSessions (must call loadAllSessions() first)
/// - [RECEIVES] projectManager.projects for colors and archived status
/// - [RECEIVES] activityTypeManager.activityTypes for category names
/// - [OUTPUTS] ActivityChartData[] for pie/bar charts
/// - [OUTPUTS] ProjectChartData[] for dashboard display
/// 
/// **AI Notes**:
/// - Uses @MainActor for UI-bound operations
/// - Implements weekly interval calculation (Monday-based weeks)
/// - Aggregates data by hours with proper time conversion
/// - Filters archived projects from yearly charts
/// - Provides both totals and percentage breakdowns
/// - Uses emoji-based categorization for visual consistency

// MARK: - Chart View Model
struct ChartViewModel {
    var sessions: [SessionRecord] = []
    var projects: [Project] = []
}

@MainActor
final class ChartDataPreparer: ObservableObject {
    @Published var viewModel = ChartViewModel()
    
    private let calendar = Calendar.current
    
    func prepareAllTimeData(sessions: [SessionRecord], projects: [Project]) {
        // [INTEGRATION] Called from DashboardRootView with pre-loaded sessions
        // [INTEGRATION] Updates viewModel which triggers UI refresh
        viewModel.sessions = sessions
        viewModel.projects = projects
    }
    
    func prepareWeeklyData(sessions: [SessionRecord], projects: [Project]) {
        // [INTEGRATION] Called from WeeklyDashboardView with pre-loaded sessions
        // [GOTCHA] Filters to current week only (Monday-based); earlier weeks hidden
        // [GOTCHA] Uses currentWeekInterval computed property based on system calendar
        viewModel.sessions = sessions.filter { currentWeekInterval.contains($0.startDate) }
        viewModel.projects = projects
    }
    
    // MARK: - Aggregations
    
    /// Aggregate activity type totals from session data with comprehensive processing
    ///
    /// **AI Context**: This method aggregates session data to show how time was distributed
    /// across different activity types. It's used for dashboard visualizations and provides
    /// both absolute hours and percentage breakdowns.
    ///
    /// **Business Rules**:
    /// - Groups sessions by activity type ID (supports uncategorized sessions)
    /// - Aggregates duration minutes for each activity type
    /// - Converts session minutes to hours for display
    /// - Calculates percentages relative to total hours
    ///
    /// **Data Flow**:
    /// 1. Create activity type lookup dictionary for efficient name/emoji resolution
    /// 2. Aggregate session durations by activity type ID
    /// 3. Calculate total hours across all activity types
    /// 4. Convert to ActivityChartData objects with percentages
    /// 5. Sort by total hours (descending) for consistent ordering
    ///
    /// **Performance Characteristics**:
    /// - O(n) complexity for session aggregation and lookup creation
    /// - Uses dictionary for efficient activity type resolution
    /// - Minimal memory overhead with direct aggregation
    ///
    /// **Edge Cases**:
    /// - Empty session list returns empty array
    /// - Zero total hours results in 0% for all activities
    /// - Uncategorized sessions grouped under "uncategorized" ID
    /// - Missing activity type names fall back to "Uncategorized"
    ///
    /// **Integration**: Uses ActivityTypeManager for activity name/emoji lookup
    ///
    /// - Parameters:
    ///   - sessions: Array of SessionRecord objects to aggregate
    /// - Returns: Array of ActivityChartData objects sorted by total hours (descending)
    private func aggregateActivityTotals(from sessions: [SessionRecord]) -> [ActivityChartData] {
        // [INTEGRATION] Called from prepareWeeklyData() and prepareAllTimeData()
        // [INTEGRATION] Receives pre-loaded sessions from DashboardRootView
        // [GOTCHA] Input MUST be pre-loaded; method does not fetch from SessionManager
        
        // 1. Create activity type lookup for efficient name/emoji resolution
        let activityLookup = getActivityTypeLookup()
        
        // 2. Aggregate session durations by activity type
        let totals = aggregateSessionDurationsByActivityType(sessions)
        
        // 3. Calculate percentages and create chart data
        let totalHours = totals.values.reduce(0, +)
        // [GOTCHA] If totalHours is 0, all percentages will be 0 (not NaN)
        let chartData = createActivityChartData(from: totals, lookup: activityLookup, totalHours: totalHours)
        
        // 4. Sort by total hours (descending)
        return sortActivityData(chartData)
    }
    
    /// Create activity type lookup dictionary for efficient name/emoji resolution
    ///
    /// **AI Context**: This method creates a lookup dictionary that maps activity type IDs
    /// to ActivityType objects. It's used for efficient resolution of activity names and
    /// emojis when creating chart data, avoiding repeated manager calls.
    ///
    /// **Business Rules**:
    /// - Uses ActivityTypeManager to get all active activity types
    /// - Creates dictionary with activity ID as key and ActivityType as value
    /// - Provides O(1) lookup performance for activity resolution
    ///
    /// **Performance Notes**:
    /// - O(n) time complexity for dictionary creation
    /// - O(1) lookup performance for subsequent operations
    /// - Minimal memory allocation with direct dictionary creation
    ///
    /// **Edge Cases**:
    /// - Empty activity type list returns empty dictionary
    /// - Duplicate activity IDs are handled by Dictionary (last one wins)
    ///
    /// **Integration**: Uses ActivityTypeManager.shared for activity type access
    ///
    /// - Returns: Dictionary mapping activity type IDs to ActivityType objects
    private func getActivityTypeLookup() -> [String: ActivityType] {
        let activityTypeManager = ActivityTypeManager.shared
        return Dictionary(uniqueKeysWithValues: activityTypeManager.getActiveActivityTypes().map { ($0.id, $0) })
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
    private func aggregateSessionDurationsByActivityType(_ sessions: [SessionRecord]) -> [String: Double] {
        var totals: [String: Double] = [:]
        
        for session in sessions {
            // [INTEGRATION] Determine activity type ID (handle nil values)
            let activityTypeID = session.activityTypeID ?? "uncategorized"
            
            // [GOTCHA] durationMinutes stored as Int; division by 60.0 for hours
            // Convert session minutes to hours and add to total
            let hours = Double(session.durationMinutes) / 60.0
            totals[activityTypeID, default: 0] += hours
        }
        
        return totals
    }
    
    /// Create ActivityChartData objects from aggregated totals
    ///
    /// **AI Context**: This method transforms aggregated duration totals into chart-ready
    /// data objects that include activity names, emojis, hours, and percentages.
    /// It handles the conversion from raw data to display-ready chart data.
    ///
    /// **Business Rules**:
    /// - Creates ActivityChartData for each activity type with >0 hours
    /// - Looks up activity names and emojis using the provided lookup
    /// - Calculates percentage of total hours for each activity
    /// - Falls back to uncategorized activity for missing lookups
    ///
    /// **Algorithm Steps**:
    /// 1. Iterate through aggregated totals
    /// 2. Skip activities with 0 hours
    /// 3. Look up activity name and emoji from lookup dictionary
    /// 4. Calculate percentage of total hours
    /// 5. Create ActivityChartData object
    /// 6. Return array of chart data objects
    ///
    /// **Performance Notes**:
    /// - O(n) time complexity for single pass through totals
    /// - Dictionary lookups are O(1) for efficient resolution
    /// - Minimal memory allocation with direct object creation
    ///
    /// **Edge Cases**:
    /// - Zero total hours results in 0% for all activities
    /// - Missing activity type lookups fall back to uncategorized
    /// - Activities with 0 hours are excluded from results
    ///
    /// - Parameters:
    ///   - totals: Dictionary of activity type ID to total hours
    ///   - lookup: Dictionary mapping activity type ID to ActivityType objects
    ///   - totalHours: Total hours across all activity types
    /// - Returns: Array of ActivityChartData objects
    private func createActivityChartData(from totals: [String: Double], lookup: [String: ActivityType], totalHours: Double) -> [ActivityChartData] {
        return totals.compactMap { (activityTypeID, hours) in
            // Skip activities with 0 hours
            guard hours > 0 else { return nil }
            
            // Look up activity information or fall back to uncategorized
            let activityTypeManager = ActivityTypeManager.shared
            let activity = lookup[activityTypeID] ?? activityTypeManager.getUncategorizedActivityType()
            
            // Calculate percentage (avoid division by zero)
            let percentage = totalHours > 0 ? (hours / totalHours) * 100 : 0
            
            // Create chart data object
            return ActivityChartData(
                activityName: activity.name,
                emoji: activity.emoji,
                totalHours: hours,
                percentage: percentage
            )
        }
    }
    
    /// Sort activity data by total hours in descending order
    ///
    /// **AI Context**: This method sorts ActivityChartData objects by their total hours
    /// in descending order (highest first). It ensures consistent ordering for chart
    /// displays and provides a logical presentation of activity data.
    ///
    /// **Business Rules**:
    /// - Sorts by totalHours property
    /// - Uses descending order (highest hours first)
    /// - Stable sort preserves relative order of equal elements
    ///
    /// **Performance Notes**:
    /// - O(n log n) time complexity using optimized sorting algorithm
    /// - Minimal memory allocation (sort creates new array)
    ///
    /// **Edge Cases**:
    /// - Empty array returns empty array
    /// - Single element array returns same array
    /// - Equal hours maintain stable sort order
    ///
    /// - Parameters:
    ///   - data: Array of ActivityChartData objects to sort
    /// - Returns: Sorted array with highest hours first
    private func sortActivityData(_ data: [ActivityChartData]) -> [ActivityChartData] {
        return data.sorted { $0.totalHours > $1.totalHours }
    }
    
    // MARK: - Week Helpers
    
    private var currentWeekInterval: DateInterval {
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = (weekday == 1) ? 6 : (weekday - 2)
        guard let start = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return DateInterval(start: today, end: today)
        }
        let startOfDay = calendar.startOfDay(for: start)
        guard let end = calendar.date(byAdding: .day, value: 7, to: startOfDay) else {
            return DateInterval(start: startOfDay, end: today)
        }
        return DateInterval(start: startOfDay, end: end)
    }
    
    private var currentYearInterval: DateInterval {
        calendar.dateInterval(of: .year, for: Date()) ?? DateInterval(start: Date(), end: Date())
    }
    
    // MARK: - Accessors
    
    /// Calculate activity type totals for the current week
    ///
    /// **AI Context**: This method aggregates session data to show how time was distributed
    /// across different activity types during the current week. It's used for weekly dashboard
    /// visualizations and provides both absolute hours and percentage breakdowns.
    ///
    /// **Business Rules**:
    /// - Only includes sessions within the current week interval
    /// - Aggregates by activity type ID (supports uncategorized sessions)
    /// - Converts session minutes to hours for display
    /// - Calculates percentages relative to total weekly hours
    ///
    /// **Data Flow**:
    /// 1. Filter sessions to current week using date interval
    /// 2. Group sessions by activity type ID
    /// 3. Sum duration minutes for each activity type
    /// 4. Convert minutes to hours
    /// 5. Calculate percentage of total weekly hours
    /// 6. Sort by total hours (descending)
    ///
    /// **Performance Characteristics**:
    /// - O(n) complexity for session filtering and aggregation
    /// - Uses dictionary for efficient grouping by activity type
    /// - Minimal memory overhead with direct aggregation
    ///
    /// **Edge Cases**:
    /// - Empty session list returns empty array
    /// - Zero total hours results in 0% for all activities
    /// - Uncategorized sessions grouped under "uncategorized" ID
    /// - Missing activity type names fall back to "Uncategorized"
    ///
    /// **Integration**: Uses ActivityTypeManager for activity name/emoji lookup
    ///
    /// - Returns: Array of ActivityChartData objects sorted by total hours (descending)
    func weeklyActivityTotals() -> [ActivityChartData] {
        aggregateActivityTotals(from: viewModel.sessions.filter { currentWeekInterval.contains($0.startDate) })
    }
    
    func currentWeekSessionsForCalendar() -> [WeeklySession] {
        let projectLookup = Dictionary(uniqueKeysWithValues: viewModel.projects.map { ($0.id, $0) })
        
        // Filter sessions to only current week sessions
        let currentWeekSessions = viewModel.sessions.filter { currentWeekInterval.contains($0.startDate) }
        
        return currentWeekSessions.compactMap { session -> WeeklySession? in
            let startComp = calendar.dateComponents([.hour, .minute], from: session.startDate)
            let endComp = calendar.dateComponents([.hour, .minute], from: session.endDate)
            let startHour = Double(startComp.hour ?? 0) + Double(startComp.minute ?? 0) / 60.0
            let endHour = Double(endComp.hour ?? 0) + Double(endComp.minute ?? 0) / 60.0
            
            guard endHour > startHour else { return nil }
            
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            let day = dayFormatter.string(from: session.startDate)
            
            let project = projectLookup[session.projectID]
            let projectColor = project?.color ?? "#999999"
            let projectEmoji = project?.emoji ?? "📁"
            
            let activityTypeManager = ActivityTypeManager.shared
            let activity = activityTypeManager.getActivityType(id: session.activityTypeID ?? "") ?? activityTypeManager.getUncategorizedActivityType()
            
            return WeeklySession(day: day, startHour: startHour, endHour: endHour, projectName: project?.name ?? session.projectID, projectColor: projectColor, projectEmoji: projectEmoji, activityEmoji: activity.emoji)
        }
    }
    
    func yearlyProjectTotals() -> [YearlyProjectChartData] {
        let projectLookup = Dictionary(uniqueKeysWithValues: viewModel.projects.filter { !$0.archived }.map { ($0.id, $0) })
        let activeProjectIDs = Set(projectLookup.keys)
        
        var totals: [String: Double] = [:]
        for session in viewModel.sessions where currentYearInterval.contains(session.startDate) {
            guard activeProjectIDs.contains(session.projectID) else { continue }
            totals[session.projectID, default: 0] += Double(session.durationMinutes) / 60.0
        }
        
        let total = totals.values.reduce(0, +)
        return totals.compactMap { (projectID, hours) in
            guard hours > 0, let project = projectLookup[projectID] else { return nil }
            return YearlyProjectChartData(projectName: project.name, color: project.color, emoji: project.emoji, totalHours: hours, percentage: total > 0 ? hours / total * 100 : 0)
        }.sorted { $0.totalHours > $1.totalHours }
    }
    
    func yearlyActivityTypeTotals() -> [YearlyActivityTypeChartData] {
        let activityTypeManager = ActivityTypeManager.shared
        let activityLookup = Dictionary(uniqueKeysWithValues: activityTypeManager.getActiveActivityTypes().map { ($0.id, $0) })
        
        var totals: [String: Double] = [:]
        for session in viewModel.sessions where currentYearInterval.contains(session.startDate) {
            let id = session.activityTypeID ?? "uncategorized"
            totals[id, default: 0] += Double(session.durationMinutes) / 60.0
        }
        
        let total = totals.values.reduce(0, +)
        return totals.compactMap { (id, hours) in
            guard hours > 0 else { return nil }
            let activity = activityLookup[id] ?? activityTypeManager.getUncategorizedActivityType()
            return YearlyActivityTypeChartData(activityName: activity.name, emoji: activity.emoji, totalHours: hours, percentage: total > 0 ? hours / total * 100 : 0)
        }.sorted { $0.totalHours > $1.totalHours }
    }
    
    func monthlyActivityTypeTotals() -> [MonthlyActivityTypeChartData] {
        let activityTypeManager = ActivityTypeManager.shared
        let activityLookup = Dictionary(uniqueKeysWithValues: activityTypeManager.getActiveActivityTypes().map { ($0.id, $0) })
        
        var monthlyData: [Int: [SessionRecord]] = [:]
        for session in viewModel.sessions where currentYearInterval.contains(session.startDate) {
            let month = calendar.component(.month, from: session.startDate)
            monthlyData[month, default: []].append(session)
        }
        
        let monthNames = DateFormatter().monthSymbols ?? []
        return (1...12).compactMap { monthNum -> MonthlyActivityTypeChartData? in
            guard monthNum >= 1 && monthNum <= monthNames.count else { return nil }
            let sessions = monthlyData[monthNum] ?? []
            var activityTotals: [String: Double] = [:]
            for session in sessions {
                let id = session.activityTypeID ?? "uncategorized"
                activityTotals[id, default: 0] += Double(session.durationMinutes) / 60.0
            }
            
            let total = activityTotals.values.reduce(0, +)
            let breakdown = activityTotals.compactMap { (id, hours) -> MonthlyActivityTypeDataPoint? in
                guard hours > 0 else { return nil }
                let activity = activityLookup[id] ?? activityTypeManager.getUncategorizedActivityType()
                return MonthlyActivityTypeDataPoint(activityName: activity.name, emoji: activity.emoji, totalHours: hours, percentage: total > 0 ? hours / total * 100 : 0)
            }.sorted { $0.totalHours > $1.totalHours }
            
            return MonthlyActivityTypeChartData(month: monthNames[monthNum - 1], monthNumber: monthNum, activityBreakdown: breakdown, totalHours: total)
        }
    }
}
