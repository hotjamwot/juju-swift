import Foundation
import SwiftUI

// MARK:

/// The data model that the ChartDataPreparer populates and works with.
struct ChartViewModel {
    var sessions: [SessionRecord] = []
    var projects: [Project] = []
}


/// Responsible for parsing and aggregating raw session data into reusable time-series or categorical structures.
/// 
/// CURRENT SCOPE: Weekly dashboard and all-time analysis only
/// 
/// ARCHITECTURE NOTE: This class has been cleaned up to remove yearly chart logic
/// that was never implemented. When yearly charts are needed in the future:
/// 1. Create separate ChartDataPreparerYearly.swift file
/// 2. Keep yearly logic isolated from weekly logic  
/// 3. Use efficient aggregation methods
/// 4. Implement appropriate caching for yearly data
/// 
/// PERFORMANCE: Focus on weekly dashboard performance. Avoid complex caching systems
/// unless absolutely necessary for performance.
/// 
/// MAINTENANCE: Keep only methods used by current features. Remove unused code immediately.
@MainActor
final class ChartDataPreparer: ObservableObject {
    @Published var viewModel = ChartViewModel()
    
    // MARK: - Public Entry Point
    
    /// Prepare all-time data for comprehensive analysis
    /// 
    /// USE CASE: Used for all-time analysis and future yearly dashboard implementation
    /// PERFORMANCE: No filtering applied - uses all sessions for maximum flexibility
    /// MAINTENANCE: Keep this method simple - it's the foundation for all other data preparation
    /// 
    /// - Parameters:
    ///   - sessions: All session records to be analyzed
    ///   - projects: All projects to be included in analysis
    func prepareAllTimeData(sessions: [SessionRecord], projects: [Project]) {
        viewModel.sessions = sessions
        viewModel.projects = projects
        
        print("[ChartDataPreparer] Prepared all-time data")
    }
    
    /// Prepare weekly-only data for optimized weekly dashboard performance
    /// 
    /// USE CASE: Weekly dashboard charts (activity bubbles, session calendar)
    /// PERFORMANCE: Filters sessions to current week only for optimal performance
    /// ARCHITECTURE: This is the primary method used by the weekly dashboard
    /// 
    /// - Parameters:
    ///   - sessions: All session records (will be filtered to current week)
    ///   - projects: All projects to be included in analysis
    func prepareWeeklyData(sessions: [SessionRecord], projects: [Project]) {
        // Filter sessions to current week only
        let weeklySessions = sessions.filter { session in
            guard let sessionDate = DateFormatter.cachedYYYYMMDD.date(from: session.date) else { return false }
            return currentWeekInterval.contains(sessionDate)
        }
        
        viewModel.sessions = weeklySessions
        viewModel.projects = projects
        
        print("[ChartDataPreparer] Prepared weekly data (\(weeklySessions.count) sessions)")
    }
    
    // MARK: - Core Accessors
    
    private let calendar = Calendar.current
    
    // MARK: - Aggregations
    
    /// Sums total hours per activity type (for activity bubble charts) with optimized lookups.
    private func aggregateActivityTotals(from sessions: [SessionRecord]) -> [ActivityChartData] {
        // Pre-build activity type lookup dictionary for O(1) access
        let activityTypeManager = ActivityTypeManager.shared
        let activityLookup = Dictionary(uniqueKeysWithValues: 
            activityTypeManager.getAllActivityTypes().map { ($0.id, $0) }
        )
        
        var totals: [String: Double] = [:]
        
        for session in sessions {
            let activityID = session.activityTypeID ?? "uncategorized"
            // Ensure duration is positive
            let hours = max(0, Double(session.durationMinutes) / 60.0)
            totals[activityID, default: 0] += hours
        }
        
        let totalHours = totals.values.reduce(0, +)
        return totals.compactMap { (activityID: String, hours: Double) in
            // Skip activities with zero hours
            guard hours > 0 else { return nil }
            let activityType = activityLookup[activityID] ??
                              activityTypeManager.getUncategorizedActivityType()
            return ActivityChartData(
                activityName: activityType.name,
                emoji: activityType.emoji,
                totalHours: hours,
                percentage: totalHours > 0 ? (hours / totalHours * 100) : 0
            )
        }.sorted { $0.totalHours > $1.totalHours }
    }
    
    // MARK: - Dashboard Aggregations
    
    private func parseTimeToHour(_ timeString: String) -> Double {
        // Try parsing with seconds first using cached formatter
        if let date = DateFormatter.cachedDateTime.date(from: timeString) {
            let components = calendar.dateComponents([.hour, .minute], from: date)
            return Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60.0
        }
        
        // Try parsing without seconds using cached formatter
        if let date = DateFormatter.cachedHHmm.date(from: timeString) {
            let components = calendar.dateComponents([.hour, .minute], from: date)
            return Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60.0
        }
        
        // Fallback to manual parsing
        let parts = timeString.components(separatedBy: ":")
        if parts.count >= 2 {
            let hour = Int(parts[0]) ?? 0
            let minute = Int(parts[1]) ?? 0
            return Double(hour) + Double(minute) / 60.0
        }
        
        return 0.0
    }

    // MARK: - Dashboard Aggregations – week‑boundary fix

    private var currentWeekInterval: DateInterval {
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        // Adjust for Monday as the first day (2). Sunday is 1.
        let daysToSubtract = (weekday == 1) ? 6 : (weekday - 2)
        
        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return DateInterval(start: today, end: today)
        }
        let mondayStart = calendar.startOfDay(for: startOfWeek)
        
        guard let endOfWeek = calendar.date(byAdding: .day, value: 6, to: mondayStart),
              let sundayEnd = calendar.date(byAdding: .day, value: 1, to: endOfWeek) else {
            return DateInterval(start: mondayStart, end: mondayStart)
        }
        
        return DateInterval(start: mondayStart, end: sundayEnd)
    }
    
    // MARK: - Yearly Date Intervals
    
    private var currentYearInterval: DateInterval {
        let today = Date()
        guard let year = calendar.dateInterval(of: .year, for: today) else {
            return DateInterval(start: today, end: today)
        }
        return year
    }


    /// Current week activity totals for activity bubbles
    /// 
    /// USE CASE: WeeklyActivityBubbleChartView
    /// OUTPUT: Array of ActivityChartData with activity names, emojis, and percentages
    /// PERFORMANCE: Uses pre-filtered weekly sessions for optimal performance
    /// 
    /// - Returns: ActivityChartData array sorted by total hours (descending)
    func weeklyActivityTotals() -> [ActivityChartData] {
        let filteredSessions = viewModel.sessions.filter { session in
            DateFormatter.cachedYYYYMMDD.date(from: session.date).map { currentWeekInterval.contains($0) } ?? false
        }
        return aggregateActivityTotals(from: filteredSessions)
    }

    /// Current week sessions transformed for calendar chart (WeeklySession format)
    /// 
    /// USE CASE: SessionCalendarChartView
    /// OUTPUT: Array of WeeklySession with parsed time data and visual elements
    /// TRANSFORMATION: Converts SessionRecord to WeeklySession with:
    ///   - Day of week (Monday-Sunday)
    ///   - Start/end hours as Double
    ///   - Project color and emoji
    ///   - Activity emoji
    /// 
    /// - Returns: WeeklySession array for calendar visualization
    func currentWeekSessionsForCalendar() -> [WeeklySession] {
        let weekSessions = viewModel.sessions.filter { session in
            DateFormatter.cachedYYYYMMDD.date(from: session.date).map { currentWeekInterval.contains($0) } ?? false
        }
        return weekSessions.compactMap { session in
            let startHour = parseTimeToHour(session.startTime)
            let endHour = parseTimeToHour(session.endTime)
            guard let date = DateFormatter.cachedYYYYMMDD.date(from: session.date), endHour > startHour else { return nil }

            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            let day = weekdayFormatter.string(from: date)

            let project = viewModel.projects.first(where: { $0.name == session.projectName })
            let projectColor = project?.color ?? "#999999"
            let projectEmoji = project?.emoji ?? "📁"
            
            // Get activity emoji with fallback to project emoji
            let activityEmoji = session.getActivityTypeDisplay().emoji

            return WeeklySession(
                day: day,
                startHour: startHour,
                endHour: endHour,
                projectName: session.projectName,
                projectColor: projectColor,
                projectEmoji: projectEmoji,
                activityEmoji: activityEmoji
            )
        }
    }


    // MARK: - Yearly Project Data
    
    /// Prepare yearly project data for current year only
    /// 
    /// USE CASE: YearlyProjectBarChartView
    /// OUTPUT: Array of YearlyProjectChartData with project names, emojis, colors, and percentages
    /// PERFORMANCE: Filters sessions to current year only for optimal performance
    /// 
    /// - Returns: YearlyProjectChartData array sorted by total hours (descending)
    func yearlyProjectTotals() -> [YearlyProjectChartData] {
        let yearlySessions = viewModel.sessions.filter { session in
            DateFormatter.cachedYYYYMMDD.date(from: session.date).map { currentYearInterval.contains($0) } ?? false
        }
        return aggregateYearlyProjectTotals(from: yearlySessions)
    }
    
    /// Aggregates yearly project totals with optimized lookups
    /// 
    /// PERFORMANCE: Pre-builds project lookup dictionary for O(1) access
    /// MAINTENANCE: Reuses existing project color system for consistency
    /// FILTERING: Only includes active projects (archived: false)
    /// 
    /// - Parameter sessions: Filtered sessions for current year
    /// - Returns: Array of YearlyProjectChartData sorted by total hours
    private func aggregateYearlyProjectTotals(from sessions: [SessionRecord]) -> [YearlyProjectChartData] {
        // Pre-build project lookup dictionary for O(1) access, filtering out archived projects
        let activeProjects = viewModel.projects.filter { !$0.archived }
        let projectLookup = Dictionary(uniqueKeysWithValues: 
            activeProjects.map { ($0.name, $0) }
        )
        
        var totals: [String: Double] = [:]
        
        for session in sessions {
            // Only include sessions for active projects
            guard projectLookup[session.projectName] != nil else { continue }
            
            // Ensure duration is positive
            let hours = max(0, Double(session.durationMinutes) / 60.0)
            totals[session.projectName, default: 0] += hours
        }
        
        let totalHours = totals.values.reduce(0, +)
        return totals.compactMap { (projectName: String, hours: Double) in
            // Skip projects with zero hours
            guard hours > 0 else { return nil }
            let project = projectLookup[projectName] ??
                         Project(name: projectName, color: "#999999", emoji: "📁")
            return YearlyProjectChartData(
                projectName: projectName,
                color: project.color,
                emoji: project.emoji,
                totalHours: hours,
                percentage: totalHours > 0 ? (hours / totalHours * 100) : 0
            )
        }.sorted { $0.totalHours > $1.totalHours }
    }
    
    // MARK: - Yearly Activity Types Data
    
    /// Prepare yearly activity type data for current year only
    /// 
    /// USE CASE: YearlyActivityTypeBarChartView
    /// OUTPUT: Array of YearlyActivityTypeChartData with activity names, emojis, and percentages
    /// PERFORMANCE: Filters sessions to current year only for optimal performance
    /// FILTERING: Only includes active (non-archived) activity types
    /// 
    /// - Returns: YearlyActivityTypeChartData array sorted by total hours (descending)
    func yearlyActivityTypeTotals() -> [YearlyActivityTypeChartData] {
        let yearlySessions = viewModel.sessions.filter { session in
            DateFormatter.cachedYYYYMMDD.date(from: session.date).map { currentYearInterval.contains($0) } ?? false
        }
        return aggregateYearlyActivityTypeTotals(from: yearlySessions)
    }
    
    /// Aggregates yearly activity type totals with optimized lookups
    /// 
    /// PERFORMANCE: Pre-builds activity type lookup dictionary for O(1) access
    /// MAINTENANCE: Reuses existing activity type system for consistency
    /// FILTERING: Only includes active (non-archived) activity types
    /// 
    /// - Parameter sessions: Filtered sessions for current year
    /// - Returns: Array of YearlyActivityTypeChartData sorted by total hours
    private func aggregateYearlyActivityTypeTotals(from sessions: [SessionRecord]) -> [YearlyActivityTypeChartData] {
        // Pre-build activity type lookup dictionary for O(1) access, filtering out archived activity types
        let activityTypeManager = ActivityTypeManager.shared
        let activeActivityTypes = activityTypeManager.getActiveActivityTypes()
        let activityLookup = Dictionary(uniqueKeysWithValues: 
            activeActivityTypes.map { ($0.id, $0) }
        )
        
        var totals: [String: Double] = [:]
        
        for session in sessions {
            let activityID = session.activityTypeID ?? "uncategorized"
            
            // Only include sessions for active activity types
            guard activityLookup[activityID] != nil else { continue }
            
            // Ensure duration is positive
            let hours = max(0, Double(session.durationMinutes) / 60.0)
            totals[activityID, default: 0] += hours
        }
        
        let totalHours = totals.values.reduce(0, +)
        return totals.compactMap { (activityID: String, hours: Double) in
            // Skip activity types with zero hours
            guard hours > 0 else { return nil }
            let activityType = activityLookup[activityID] ??
                              activityTypeManager.getUncategorizedActivityType()
            return YearlyActivityTypeChartData(
                activityName: activityType.name,
                emoji: activityType.emoji,
                totalHours: hours,
                percentage: totalHours > 0 ? (hours / totalHours * 100) : 0
            )
        }.sorted { $0.totalHours > $1.totalHours }
    }
    
    // Accessors for convenience in views
    var projects: [Project] { viewModel.projects }
    var sessions: [SessionRecord] { viewModel.sessions }
    
} 


// MARK: - DateFormatter Helper
extension DateFormatter {
    static let cachedYYYYMMDD: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    static let cachedHHmm: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    static let cachedDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
