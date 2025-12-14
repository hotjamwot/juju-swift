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
    
    // MARK: - Caching for Performance
    private var yearlyCache: [String: Any] = [:]
    private var lastCacheKey: String = ""
    private var cacheTimestamp: Date = Date.distantPast
    private var cacheAccessCount: [String: Int] = [:]
    
    // MARK: - Cache Management
    private func clearCache() {
        yearlyCache.removeAll()
        lastCacheKey = ""
        cacheTimestamp = Date.distantPast
        cacheAccessCount.removeAll()
    }
    
    private func shouldInvalidateCache() -> Bool {
        // Invalidate cache if it's older than 10 seconds or if data has changed significantly
        let age = Date().timeIntervalSince(cacheTimestamp)
        return age > 10.0
    }
    
    // MARK: - Advanced Caching with LRU Eviction
    private func setCacheValue(_ key: String, value: Any) {
        yearlyCache[key] = value
        cacheAccessCount[key, default: 0] += 1
        cacheTimestamp = Date()
        
        // LRU eviction: remove oldest entries if cache gets too large
        if yearlyCache.count > 20 {
            let oldestKey = cacheAccessCount.min { lhs, rhs in
                lhs.value < rhs.value
            }?.key
            
            if let keyToRemove = oldestKey {
                yearlyCache.removeValue(forKey: keyToRemove)
                cacheAccessCount.removeValue(forKey: keyToRemove)
            }
        }
    }
    
    private func getCacheValue<T>(_ key: String) -> T? {
        cacheAccessCount[key, default: 0] += 1
        return yearlyCache[key] as? T
    }
    
    // MARK: - Public Entry Point
    
    /// Prepare all-time data for yearly dashboard and comprehensive analysis
    func prepareAllTimeData(sessions: [SessionRecord], projects: [Project]) {
        viewModel.sessions = sessions
        viewModel.projects = projects
        clearCache()
        
        print("[ChartDataPreparer] Prepared all-time data")
    }
    
    /// Prepare weekly-only data for optimized weekly dashboard performance
    func prepareWeeklyData(sessions: [SessionRecord], projects: [Project]) {
        // Filter sessions to current week only
        let weeklySessions = sessions.filter { session in
            guard let sessionDate = DateFormatter.cachedYYYYMMDD.date(from: session.date) else { return false }
            return currentWeekInterval.contains(sessionDate)
        }
        
        viewModel.sessions = weeklySessions
        viewModel.projects = projects
        clearCache()
        
        print("[ChartDataPreparer] Prepared weekly data (\(weeklySessions.count) sessions)")
    }
    
    /// Prepare yearly-only data for yearly dashboard with caching
    func prepareYearlyData(sessions: [SessionRecord], projects: [Project]) {
        print("[ChartDataPreparer] Starting prepareYearlyData with \(sessions.count) sessions and \(projects.count) projects")
        
        // Filter sessions to current year only
        let yearlySessions = sessions.filter { session in
            guard let sessionDate = DateFormatter.cachedYYYYMMDD.date(from: session.date) else { return false }
            return currentYearInterval.contains(sessionDate)
        }
        
        viewModel.sessions = yearlySessions
        viewModel.projects = projects
        clearCache()
        cacheTimestamp = Date()
        
        print("[ChartDataPreparer] Prepared yearly data (\(yearlySessions.count) sessions out of \(sessions.count) total)")
        
        // Debug: Log some sample sessions
        if !yearlySessions.isEmpty {
            let sample = Array(yearlySessions.prefix(3))
            print("[ChartDataPreparer] Sample sessions: \(sample.map { "\($0.date) - \($0.projectName) - \($0.durationMinutes)min" })")
        }
    }
    
    // MARK: - Core Accessors
    
    private let calendar = Calendar.current
    
    // MARK: - Aggregations
    
    /// Sums total hours per project (for pie charts or stacked bars) with optimized lookups.
    private func aggregateProjectTotals(from sessions: [SessionRecord]) -> [ProjectChartData] {
        // Pre-build project lookup dictionary for O(1) access
        let projectLookup = Dictionary(uniqueKeysWithValues: viewModel.projects.map { ($0.name, $0) })
        
        var totals: [String: Double] = [:]
        for session in sessions {
            // Ensure duration is positive
            let hours = max(0, Double(session.durationMinutes) / 60)
            totals[session.projectName, default: 0] += hours
        }
        
        let totalHours = totals.values.reduce(0, +)
        return totals.compactMap { (name: String, hours: Double) in
            // Skip projects with zero hours
            guard hours > 0 else { return nil }
            let project = projectLookup[name]
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
    
    /// Sums total hours per activity type (for pie chart).
    private func aggregateActivityTotalsForPieChart(from sessions: [SessionRecord]) -> [ActivityTypePieSlice] {
        var totals: [String: Double] = [:]
        
        for session in sessions {
            let activityID = session.activityTypeID ?? "uncategorized"
            let activityTypeManager = ActivityTypeManager.shared
            let activityType = activityTypeManager.getActivityType(id: activityID) ??
                              activityTypeManager.getUncategorizedActivityType()
            
            // Skip uncategorized activities - they are essentially null sessions
            if activityType.name.lowercased() == "uncategorized" {
                continue
            }
            
            let hours = Double(session.durationMinutes) / 60.0
            totals[activityID, default: 0] += hours
        }
        
        // If no valid activities remain, return empty array
        guard !totals.isEmpty else { return [] }
        
        let totalHours = totals.values.reduce(0, +)
        return totals.map { (activityID, hours) in
            let activityTypeManager = ActivityTypeManager.shared
            let activityType = activityTypeManager.getActivityType(id: activityID) ??
                              activityTypeManager.getUncategorizedActivityType()
            
            let percentage = totalHours > 0 ? (hours / totalHours * 100) : 0
            
            // Generate a color for the activity type (using a simple hash-based approach)
            let color = generateColorForActivityType(activityType.name)
            
            return ActivityTypePieSlice(
                activityName: activityType.name,
                emoji: activityType.emoji,
                totalHours: hours,
                percentage: percentage,
                color: color
            )
        }
        .sorted { $0.totalHours > $1.totalHours }
    }
    
    /// Generates a consistent color for an activity type based on its name
    private func generateColorForActivityType(_ activityName: String) -> Color {
        let colors: [Color] = [
            Theme.Colors.accentColor,
            Color(hex: "#FF6B6B"), // Red
            Color(hex: "#4ECDC4"), // Teal
            Color(hex: "#45B7D1"), // Blue
            Color(hex: "#96CEB4"), // Green
            Color(hex: "#FFEAA7"), // Yellow
            Color(hex: "#DDA0DD"), // Plum
            Color(hex: "#98D8C8"), // Sage
            Color(hex: "#F7DC6F"), // Yellow
            Color(hex: "#BB8FCE"), // Purple
            Color(hex: "#85C1E9"), // Sky Blue
            Color(hex: "#82E0AA"), // Mint
        ]
        
        let hash = activityName.hashValue
        let index = abs(hash) % colors.count
        return colors[index]
    }
    
    /// Filters sessions based on the selected time period with optimized performance
    private func filterSessions(sessions: [SessionRecord], filter: ChartTimePeriod) -> [SessionRecord] {
        // For allTime, return sessions directly without filtering
        if filter == .allTime {
            return sessions
        }
        
        // Pre-calculate interval boundaries for better performance
        let (start, end) = getIntervalBounds(for: filter)
        
        // Use optimized filtering with early returns
        return sessions.compactMap { session in
            guard let sessionDate = DateFormatter.cachedYYYYMMDD.date(from: session.date) else { return nil }
            return (sessionDate >= start && sessionDate < end) ? session : nil
        }
    }
    
    /// Get interval bounds for optimized filtering
    private func getIntervalBounds(for filter: ChartTimePeriod) -> (Date, Date) {
        switch filter {
        case .week:
            return (currentWeekInterval.start, currentWeekInterval.end)
        case .month:
            return (currentMonthInterval.start, currentMonthInterval.end)
        case .year:
            return (currentYearInterval.start, currentYearInterval.end)
        case .allTime:
            return (Date.distantPast, Date.distantFuture)
        }
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

    /// Current week activity totals for activity bubbles
    func weeklyActivityTotals() -> [ActivityChartData] {
        let filteredSessions = viewModel.sessions.filter { session in
            DateFormatter.cachedYYYYMMDD.date(from: session.date).map { currentWeekInterval.contains($0) } ?? false
        }
        return aggregateActivityTotals(from: filteredSessions)
    }

    /// Current week sessions transformed for calendar chart (WeeklySession format)
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
