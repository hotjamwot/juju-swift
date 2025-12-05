import Foundation
import SwiftUI

// MARK:

/// The data model that the ChartDataPreparer populates and works with.
struct ChartViewModel {
    var sessions: [SessionRecord] = []
    var projects: [Project] = []
}

/// Defines the available time periods for filtering the chart data.
enum ChartTimePeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case year
    case allTime

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        case .allTime: return "All Time"
        }
    }
}


/// Responsible for parsing and aggregating raw session data into reusable time-series or categorical structures.
/// Keeps logic focused on *data integrity*, not chart styling.
@MainActor
final class ChartDataPreparer: ObservableObject {
    @Published var viewModel = ChartViewModel()

    // MARK: - Public Entry Point
    
    func prepareAllTimeData(sessions: [SessionRecord], projects: [Project]) {
        viewModel.sessions = sessions
        viewModel.projects = projects
        
        print("[ChartDataPreparer] Prepared all-time data")
    }
    
    /// Background version for heavy data processing (FIX: Background chart prep)
    func prepareAllTimeDataInBackground(sessions: [SessionRecord], projects: [Project]) async {
        await Task.detached {
            await MainActor.run {
                self.viewModel.sessions = sessions
                self.viewModel.projects = projects
            }
            print("[ChartDataPreparer] Background preparation complete")
        }
    }

    private let sessionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current // Use the user's local time zone
        return formatter
    }()

    func prepareData(sessions: [SessionRecord], projects: [Project], filter: ChartTimePeriod) {
        print("[ChartDataPreparer] Re‑calculating for: \(filter.title)")
        
        // Apply filtering based on the selected time period
        let filteredSessions = filterSessions(sessions: sessions, filter: filter)
        viewModel.sessions = filteredSessions
        viewModel.projects = projects
    }
    
    // MARK: - Core Accessors
    
    private let calendar = Calendar.current
    private let formatterYYYYMMDD = DateFormatter.yyyyMMdd
    
    // MARK: - Aggregations
    
    /// Sums total hours per project (for pie charts or stacked bars).
    private func aggregateProjectTotals(from sessions: [SessionRecord]) -> [ProjectChartData] {
        var totals: [String: Double] = [:]
        for session in sessions {
            totals[session.projectName, default: 0] += Double(session.durationMinutes) / 60
        }
        
        let totalHours = totals.values.reduce(0, +)
        return totals.map { (name, hours) in
            let project = viewModel.projects.first(where: { $0.name == name })
            let color = project?.color ?? "#999999"
            let emoji = project?.emoji ?? "📁"
            return ProjectChartData(
                projectName: name,
                color: color,
                emoji: emoji,
                totalHours: hours,
                percentage: totalHours > 0 ? (hours / totalHours * 100) : 0
            )
        }.sorted { $0.totalHours > $1.totalHours }
    }
    
    /// Sums total hours per activity type (for activity bubble charts).
    private func aggregateActivityTotals(from sessions: [SessionRecord]) -> [ActivityChartData] {
        var totals: [String: Double] = [:]
        
        for session in sessions {
            let activityID = session.activityTypeID ?? "uncategorized"
            let hours = Double(session.durationMinutes) / 60.0
            totals[activityID, default: 0] += hours
        }
        
        let totalHours = totals.values.reduce(0, +)
        return totals.map { (activityID, hours) in
            let activityTypeManager = ActivityTypeManager.shared
            let activityType = activityTypeManager.getActivityType(id: activityID) ??
                              activityTypeManager.getUncategorizedActivityType()
            return ActivityChartData(
                activityName: activityType.name,
                emoji: activityType.emoji,
                totalHours: hours,
                percentage: totalHours > 0 ? (hours / totalHours * 100) : 0
            )
        }.sorted { $0.totalHours > $1.totalHours }
    }
    
    /// Filters sessions based on the selected time period
    private func filterSessions(sessions: [SessionRecord], filter: ChartTimePeriod) -> [SessionRecord] {
        switch filter {
        case .week:
            return sessions.filter { session in
                formatterYYYYMMDD.date(from: session.date).map { currentWeekInterval.contains($0) } ?? false
            }
        case .month:
            return sessions.filter { session in
                formatterYYYYMMDD.date(from: session.date).map { currentMonthInterval.contains($0) } ?? false
            }
        case .year:
            return sessions.filter { session in
                formatterYYYYMMDD.date(from: session.date).map { currentYearInterval.contains($0) } ?? false
            }
        case .allTime:
            return sessions
        }
    }
    
    // MARK: - Dashboard Aggregations
    
    private func parseTimeToHour(_ timeString: String) -> Double {
        // Try parsing with seconds first
        let formatterSeconds = DateFormatter()
        formatterSeconds.dateFormat = "HH:mm:ss"
        if let date = formatterSeconds.date(from: timeString) {
            let components = calendar.dateComponents([.hour, .minute], from: date)
            return Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60.0
        }
        
        // Try parsing without seconds
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let date = formatter.date(from: timeString) {
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

    private var currentMonthInterval: DateInterval {
        let today = Date()
        guard let month = calendar.dateInterval(of: .month, for: today) else {
            return DateInterval(start: today, end: today)
        }
        return month
    }

    private var currentYearInterval: DateInterval {
        let today = Date()
        guard let year = calendar.dateInterval(of: .year, for: today) else {
            return DateInterval(start: today, end: today)
        }
        return year
    }

    /// Current week project totals for weekly bubbles
    func weeklyProjectTotals() -> [ProjectChartData] {
        let filteredSessions = viewModel.sessions.filter { session in
            formatterYYYYMMDD.date(from: session.date).map { currentWeekInterval.contains($0) } ?? false
        }
        return aggregateProjectTotals(from: filteredSessions)
    }

    /// Current week activity totals for activity bubbles
    func weeklyActivityTotals() -> [ActivityChartData] {
        let filteredSessions = viewModel.sessions.filter { session in
            formatterYYYYMMDD.date(from: session.date).map { currentWeekInterval.contains($0) } ?? false
        }
        return aggregateActivityTotals(from: filteredSessions)
    }

    /// Current week sessions transformed for calendar chart (WeeklySession format)
    func currentWeekSessionsForCalendar() -> [WeeklySession] {
        let weekSessions = viewModel.sessions.filter { session in
            formatterYYYYMMDD.date(from: session.date).map { currentWeekInterval.contains($0) } ?? false
        }
        return weekSessions.compactMap { session in
            let startHour = parseTimeToHour(session.startTime)
            let endHour = parseTimeToHour(session.endTime)
            guard let date = formatterYYYYMMDD.date(from: session.date), endHour > startHour else { return nil }

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

    /// Year to date project totals for yearly bubbles
    func yearlyProjectTotals() -> [ProjectChartData] {
        let yearSessions = viewModel.sessions.filter { session in
            formatterYYYYMMDD.date(from: session.date).map { currentYearInterval.contains($0) } ?? false
        }
        return aggregateProjectTotals(from: yearSessions)
    }
    
    public func yearlyTotalHours() -> Double {
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearlySessions = viewModel.sessions.filter { session in
            // FIX: Use session.date instead of session.startTime for year filtering
            guard let sessionDate = formatterYYYYMMDD.date(from: session.date) else { return false }
            let sessionYear = Calendar.current.component(.year, from: sessionDate)
            return sessionYear == currentYear
        }
        
        let totalSeconds = yearlySessions.reduce(into: 0.0) { result, session in
            result += Double(session.durationMinutes) * 60 // Convert Int to Double
        }
        return totalSeconds / 3600.0
    }
    
    /// Calculates the total number of sessions for the current year.
    public func yearlyTotalSessions() -> Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearlySessions = viewModel.sessions.filter { session in
            // FIX: Use session.date instead of session.startTime for year filtering
            guard let sessionDate = formatterYYYYMMDD.date(from: session.date) else { return false }
            let sessionYear = Calendar.current.component(.year, from: sessionDate)
            return sessionYear == currentYear
        }
        return yearlySessions.count
    }
    
    /// Calculates the average session duration for the current year and returns a formatted string.
    public func yearlyAvgDurationString() -> String {
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearlySessions = viewModel.sessions.filter { session in
            // FIX: Use session.date instead of session.startTime for year filtering
            guard let sessionDate = formatterYYYYMMDD.date(from: session.date) else { return false }
            let sessionYear = Calendar.current.component(.year, from: sessionDate)
            return sessionYear == currentYear
        }
        
        guard !yearlySessions.isEmpty else { return "0m" }
        
        // Calculate average duration directly in minutes
        let totalDuration = yearlySessions.reduce(into: 0.0) { result, session in
            result += Double(session.durationMinutes)
        }
        let averageMinutes = totalDuration / Double(yearlySessions.count)
        
        let hours = Int(averageMinutes) / 60
        let minutes = Int(averageMinutes) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Stacked Area Chart Helpers
    func prepareStackedAreaData() -> [ProjectSeriesData] {
        var monthlyTotals: [Date: [String: Double]] = [:]
        let yearSessions = viewModel.sessions.filter { session in
            formatterYYYYMMDD.date(from: session.date).map { currentYearInterval.contains($0) } ?? false
        }
        for session in yearSessions {
            guard let date = formatterYYYYMMDD.date(from: session.date) else { continue }
            let components = calendar.dateComponents([.year, .month], from: date)
            guard let monthStart = calendar.date(from: components) else { continue }
            let hours = Double(session.durationMinutes) / 60.0
            monthlyTotals[monthStart, default: [:]][session.projectName, default: 0] += hours
        }
        
        var projectData: [String: [MonthlyHour]] = [:]
        for (monthDate, projectHours) in monthlyTotals {
            for (projectName, hours) in projectHours {
                let monthlyHour = MonthlyHour(date: monthDate, hours: hours)
                projectData[projectName, default: []].append(monthlyHour)
            }
        }
        
        let allMonths = (1...12).compactMap { month -> Date? in
            var components = calendar.dateComponents([.year], from: Date())
            components.month = month
            return calendar.date(from: components)
        }
        
        var finalData: [ProjectSeriesData] = []
        for (projectName, hoursData) in projectData {
            var completeMonthlyHours: [MonthlyHour] = []
            for month in allMonths {
                if let existingData = hoursData.first(where: { $0.date == month }) {
                    completeMonthlyHours.append(existingData)
                } else {
                    completeMonthlyHours.append(MonthlyHour(date: month, hours: 0))
                }
            }
            
            completeMonthlyHours.sort(by: { $0.date < $1.date })
            let project = viewModel.projects.first(where: { $0.name == projectName })
            let projectColor = project?.color ?? "#999999"
            let projectEmoji = project?.emoji ?? "📁"
            
            finalData.append(
                ProjectSeriesData(
                    projectName: projectName,
                    monthlyHours: completeMonthlyHours,
                    color: projectColor,
                    emoji: projectEmoji
                )
            )
        }
        
        return finalData.sorted { $0.projectName < $1.projectName }
    }

    /// Monthly project totals for stacked area chart
    func monthlyProjectTotals() -> [ProjectSeriesData] {
        return prepareStackedAreaData()
    }

    /// Weekly total hours for headline (uses activity totals for consistency)
    func weeklyTotalHours() -> Double {
        weeklyActivityTotals().reduce(into: 0.0) { result, value in
            result += value.totalHours
        }
    }

    /// All-Time Total Hours for SummaryMetricView
    func allTimeTotalHours() -> Double {
        let totalMinutes = viewModel.sessions.reduce(into: 0) { result, value in
            result += value.durationMinutes
        }
        return Double(totalMinutes) / 60.0
    }
    
    /// All-Time Total Sessions for SummaryMetricView
    func allTimeTotalSessions() -> Int {
        return viewModel.sessions.count
    }

    // MARK: - Weekly Stacked Bar Chart Data Preparation
    
    /// Generates all weeks for the current year
    private func generateWeeksForCurrentYear() -> [WeekOfYear] {
        let currentYear = calendar.component(.year, from: Date())
        var weeks: [WeekOfYear] = []
        
        // Start from January 1st
        var date = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1))!
        
        for weekNumber in 1...52 {
            // Calculate week start (Monday)
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            let weekEnd = calendar.dateInterval(of: .weekOfYear, for: weekStart)?.end ?? calendar.date(byAdding: .day, value: 6, to: weekStart)!
            
            // Determine the dominant month for this week
            let monthComponents = calendar.dateComponents([.month], from: weekStart)
            let dominantMonth = monthComponents.month ?? 1
            
            let week = WeekOfYear(
                weekNumber: weekNumber,
                year: currentYear,
                month: dominantMonth,
                startDate: weekStart,
                endDate: weekEnd
            )
            
            weeks.append(week)
            
            // Move to next week
            date = calendar.date(byAdding: .day, value: 7, to: date)!
            
            // Break if we've moved into next year
            if calendar.component(.year, from: date) > currentYear {
                break
            }
        }
        
        return weeks
    }
    
    /// Aggregates session data by week and project
    func weeklyStackedBarChartData() -> [WeeklyStackedBarChartData] {
        let allWeeks = generateWeeksForCurrentYear()
        let yearSessions = viewModel.sessions.filter { session in
            formatterYYYYMMDD.date(from: session.date).map { currentYearInterval.contains($0) } ?? false
        }
        
        // Group sessions by week
        var weekProjectTotals: [Int: [String: Double]] = [:] // [weekNumber: [projectName: hours]]
        
        for session in yearSessions {
            guard let sessionDate = formatterYYYYMMDD.date(from: session.date) else { continue }
            
            // Find which week this session belongs to
            if let weekOfYear = calendar.dateInterval(of: .weekOfYear, for: sessionDate) {
                let weekNumber = calendar.component(.weekOfYear, from: sessionDate)
                let hours = Double(session.durationMinutes) / 60.0
                
                weekProjectTotals[weekNumber, default: [:]][session.projectName, default: 0] += hours
            }
        }
        
        // Create WeeklyStackedBarChartData for each week
        return allWeeks.map { week in
            let projectData = weekProjectTotals[week.weekNumber] ?? [:]
            let weeklyProjectData = projectData.map { (projectName, hours) -> ProjectWeeklyData in
                let project = viewModel.projects.first { $0.name == projectName }
                let color = project?.color ?? "#999999"
                let emoji = project?.emoji ?? "📁"
                
                return ProjectWeeklyData(
                    projectName: projectName,
                    projectColor: color,
                    projectEmoji: emoji,
                    hours: hours,
                    weekId: week.weekNumber
                )
            }
            
            return WeeklyStackedBarChartData(
                week: week,
                projectData: weeklyProjectData
            )
        }
    }

    // Accessors for convenience in views
    var projects: [Project] { viewModel.projects }
    var sessions: [SessionRecord] { viewModel.sessions }
    
} 


// MARK: - DateFormatter Helper
extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    static let HHmm: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
