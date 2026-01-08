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
        viewModel.sessions = sessions
        viewModel.projects = projects
    }
    
    func prepareWeeklyData(sessions: [SessionRecord], projects: [Project]) {
        viewModel.sessions = sessions.filter { currentWeekInterval.contains($0.startDate) }
        viewModel.projects = projects
    }
    
    // MARK: - Aggregations
    
    private func aggregateActivityTotals(from sessions: [SessionRecord]) -> [ActivityChartData] {
        let activityTypeManager = ActivityTypeManager.shared
        let activityLookup = Dictionary(uniqueKeysWithValues: activityTypeManager.getAllActivityTypes().map { ($0.id, $0) })
        
        var totals: [String: Double] = [:]
        for session in sessions {
            let id = session.activityTypeID ?? "uncategorized"
            totals[id, default: 0] += Double(session.durationMinutes) / 60.0
        }
        
        let total = totals.values.reduce(0, +)
        return totals.compactMap { (id, hours) in
            guard hours > 0 else { return nil }
            let activity = activityLookup[id] ?? activityTypeManager.getUncategorizedActivityType()
            return ActivityChartData(activityName: activity.name, emoji: activity.emoji, totalHours: hours, percentage: total > 0 ? hours / total * 100 : 0)
        }.sorted { $0.totalHours > $1.totalHours }
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
