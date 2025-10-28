import Foundation
import SwiftUI

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

    func prepareData(sessions: [SessionRecord], projects: [Project], filter: ChartTimePeriod) {
        print("[ChartDataPreparer] Re‑calculating for: \(filter.title)")
        viewModel.sessions = sessions
        viewModel.projects = projects
        viewModel.currentFilter = filter
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
            let color = viewModel.projects.first(where: { $0.name == name })?.color ?? "#999999"
            return ProjectChartData(
                projectName: name,
                color: color,
                totalHours: hours,
                percentage: totalHours > 0 ? (hours / totalHours * 100) : 0
            )
        }.sorted { $0.totalHours > $1.totalHours }
    }
    
    
    // MARK: - Dashboard Aggregations
    
    private func parseTimeToHour(_ timeString: String) -> Double {
        // Try with seconds first
        let formatterSeconds = DateFormatter()
        formatterSeconds.dateFormat = "HH:mm:ss"
        if let date = formatterSeconds.date(from: timeString) {
            let components = calendar.dateComponents([.hour, .minute], from: date)
            return Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60.0
        }
        
        // Fallback to without seconds
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let date = formatter.date(from: timeString) {
            let components = calendar.dateComponents([.hour, .minute], from: date)
            return Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60.0
        }
        
        // Manual parsing as last resort
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
    // Calendar.current.firstWeekday = 1 (Sunday).  
    // We want Monday as the first day (ISO‑8601) – so if today is Sunday we need to go back 6 days; otherwise subtract (weekday‑2).
    let weekday = calendar.component(.weekday, from: today)
    let daysToSubtract = (weekday == 1) ? 6 : weekday - 2   // Monday → 0, Tuesday → 1, … Sunday → 6
    
    guard let mondayDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
        // Fallback in the unlikely event calendar math fails – log it!
        print("[ChartDataPreparer] ❌ Unable to calculate week interval.")
        return DateInterval(start: today, end: today)
    }
    let mondayStart = calendar.startOfDay(for: mondayDate)
    let todayStart = calendar.startOfDay(for: today)
    guard let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) else {
        return DateInterval(start: mondayStart, end: today)
    }
    return DateInterval(start: mondayStart, end: tomorrowStart)
}

    private var currentYearInterval: DateInterval {
        let today = Date()
        let yearStart = calendar.date(from: DateComponents(year: calendar.component(.year, from: today))) ?? today
        return DateInterval(start: yearStart, end: today)
    }

    /// Current week project totals for weekly bubbles
    func weeklyProjectTotals() -> [ProjectChartData] {
        let filteredSessions = viewModel.sessions.filter { session in
            formatterYYYYMMDD.date(from: session.date).map { currentWeekInterval.contains($0) } ?? false
        }
        print("[ChartDataPreparer] Weekly filter: \(currentWeekInterval) with \(filteredSessions.count) sessions out of \(viewModel.sessions.count)")
        if !filteredSessions.isEmpty {
            let sampleDates = filteredSessions.prefix(3).map { $0.date }
            print("[ChartDataPreparer] Sample weekly session dates: \(sampleDates)")
            let sampleProjects = filteredSessions.prefix(3).map { ($0.date, $0.projectName, $0.durationMinutes) }
            print("[ChartDataPreparer] Sample weekly sessions: \(sampleProjects)")
        } else {
            let recentAllDates = viewModel.sessions.prefix(5).map { $0.date }
            print("[ChartDataPreparer] No weekly sessions. Recent session dates: \(recentAllDates)")
        }
        let aggregatedData = aggregateProjectTotals(from: filteredSessions)
        print("[ChartDataPreparer] Aggregated weekly ProjectChartData count: \(aggregatedData.count), projects: \(aggregatedData.map { $0.projectName })")
        return aggregatedData
    }

    /// Current week sessions transformed for calendar chart (WeeklySession format)
    func currentWeekSessionsForCalendar() -> [WeeklySession] {
        let weekSessions = viewModel.sessions.filter { session in
            let week = currentWeekInterval
            guard let date = formatterYYYYMMDD.date(from: session.date) else {
                return false
            }
            return week.contains(date)
        }
        return weekSessions.compactMap { session in
            let startHour = parseTimeToHour(session.startTime)
            let endHour = parseTimeToHour(session.endTime)
            guard let date = formatterYYYYMMDD.date(from: session.date),
                  endHour > startHour else { return nil }

            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"  // Full weekday name (Monday, etc.)
            let day = weekdayFormatter.string(from: date)

            let projectColor = viewModel.projects.first(where: { $0.name == session.projectName })?.color ?? "#999999"

            return WeeklySession(
                day: day,
                startHour: startHour,
                endHour: endHour,
                projectName: session.projectName,
                projectColor: projectColor
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

    /// Monthly project totals for grouped bar chart
    func monthlyProjectTotals() -> [MonthlyBarData] {
        let yearSessions = viewModel.sessions.filter { session in
            formatterYYYYMMDD.date(from: session.date).map { currentYearInterval.contains($0) } ?? false
        }
        var monthlyTotals: [Date: [String: Double]] = [:]
        for session in yearSessions {
            guard let date = formatterYYYYMMDD.date(from: session.date) else { continue }
            let components = calendar.dateComponents([.year, .month], from: date)
            guard let monthStart = calendar.date(from: components) else { continue }
            let hours = Double(session.durationMinutes) / 60.0
            monthlyTotals[monthStart, default: [:]][session.projectName, default: 0] += hours
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var result: [MonthlyBarData] = []
        for month in 1...12 {
            let components = DateComponents(year: calendar.component(.year, from: Date()), month: month)
            guard let monthDate = calendar.date(from: components) else { continue }
            let monthName = formatter.string(from: monthDate)
            let projectData = monthlyTotals[monthDate]?.map { (projectName, hours) in
                ProjectMonthlyData(projectName: projectName, hours: hours, color: viewModel.projects.first(where: { $0.name == projectName })?.color ?? "#999999")
            } ?? []
            result.append(MonthlyBarData(month: monthName, projects: projectData))
        }
        return result
    }

    /// Weekly total hours for headline
    func weeklyTotalHours() -> Double {
        weeklyProjectTotals().reduce(0) { $0 + $1.totalHours }
    }

    /// All-time total hours for summary
    func allTimeTotalHours() -> Double {
        aggregateProjectTotals(from: viewModel.sessions).reduce(0) { $0 + $1.totalHours }
    }

    /// All-time total sessions for summary
    func allTimeTotalSessions() -> Int {
        viewModel.sessions.count
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
}
