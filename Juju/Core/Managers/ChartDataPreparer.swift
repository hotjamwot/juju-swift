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

            return WeeklySession(
                day: day,
                startHour: startHour,
                endHour: endHour,
                projectName: session.projectName,
                projectColor: projectColor,
                projectEmoji: projectEmoji
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

    /// Weekly total hours for headline
    func weeklyTotalHours() -> Double {
        weeklyProjectTotals().reduce(into: 0.0) { result, value in
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

    // MARK: - Bubble Chart Data Preparation
    
    /// Returns ChartEntry array specifically prepared for bubble chart display
    func bubbleChartEntries() -> [ChartEntry] {
        viewModel.sessions.compactMap { session in
            guard let date = formatterYYYYMMDD.date(from: session.date) else { return nil }
            let project = viewModel.projects.first { $0.name == session.projectName }
            let projectColor = project?.color ?? "#999999"
            let projectEmoji = project?.emoji ?? "📁"
            
            return ChartEntry(
                date: date,
                projectName: session.projectName,
                projectColor: projectColor,
                projectEmoji: projectEmoji,
                durationMinutes: session.durationMinutes,
                startTime: session.startTime,
                endTime: session.endTime,
                notes: session.notes,
                mood: session.mood
            )
        }
    }
    
    /// Calculates bubble positions and visual properties for a given set of sessions
    func bubbleChartData(for entries: [ChartEntry], chartSize: CGSize) -> [BubbleChartData] {
        guard !entries.isEmpty else { return [] }
        
        let startDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: Date()), month: 1, day: 1))!
        let endDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: Date()), month: 12, day: 31))!
        let totalDays = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 365
        
        var bubbles: [BubbleChartData] = []
        
        for entry in entries {
            // X Position: mapped linearly from 1 Jan → 31 Dec
            let daysFromStart = calendar.dateComponents([.day], from: startDate, to: entry.date).day ?? 0
            let x = CGFloat(daysFromStart) / CGFloat(totalDays) * chartSize.width
            
            // Y Position: consistent jitter per project
            let y = yJitter(for: entry.projectName, totalHeight: chartSize.height)
            
            // Size: scaled by duration
            let diameter = bubbleSize(for: entry.durationMinutes)
            
            // Color: from project
            let projectColor = Color(hex: entry.projectColor)
            
            // Opacity: based on mood tag
            let opacity = entry.mood != nil ? 0.6 : 0.8
            
            // Shadow: based on mood
            let shadow = entry.mood != nil
            
            bubbles.append(BubbleChartData(
                x: x - diameter/2,
                y: y - diameter/2,
                diameter: diameter,
                color: projectColor,
                opacity: opacity,
                shadow: shadow
            ))
        }
        
        return bubbles
    }
    
    // MARK: - Private Bubble Chart Helpers
    
    private func yJitter(for projectName: String, totalHeight: CGFloat) -> CGFloat {
        // Create a consistent jitter per project to maintain some structure
        let hash = projectName.hashValue
        let randomValue = Double(hash) / Double(Int.max)
        return 50 + CGFloat(randomValue * (totalHeight - 100))
    }
    
    private func bubbleSize(for durationMinutes: Int) -> CGFloat {
        // Scale bubble size to preserve visibility of small sessions while keeping large sessions proportionate
        let baseSize: CGFloat = 4
        let maxSize: CGFloat = 20
        let durationHours = Double(durationMinutes) / 60.0
        
        // Use logarithmic scaling to better handle large differences
        let scaledSize = baseSize + log10(max(durationHours, 1)) * 3
        return min(scaledSize, maxSize)
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

// MARK: - Bubble Chart Data Model
struct BubbleChartData: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let diameter: CGFloat
    let color: Color
    let opacity: Double
    let shadow: Bool
}
