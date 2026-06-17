import Foundation
import SwiftUI

// MARK: - Time Period Enum
enum ChartTimePeriod: String, CaseIterable, Identifiable {
    case week, month, year, allTime
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        case .allTime: return "All Time"
        }
    }
    
    var previousPeriod: ChartTimePeriod { self }
    var durationInDays: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        case .allTime: return Int.max
        }
    }

    var calendarComponent: Calendar.Component? {
        switch self {
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        case .allTime: return nil
        }
    }

    func dateInterval(endingAt referenceDate: Date = Date(), calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .week:
            return weekToDateInterval(endingAt: referenceDate, calendar: calendar)
        case .month:
            return calendar.dateInterval(of: .month, for: referenceDate)
        case .year:
            return calendar.dateInterval(of: .year, for: referenceDate)
        case .allTime:
            return DateInterval(start: .distantPast, end: .distantFuture)
        }
    }

    private func weekToDateInterval(endingAt referenceDate: Date, calendar: Calendar) -> DateInterval? {
        let today = calendar.startOfDay(for: referenceDate)
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        guard let startMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today),
              let endOfToday = calendar.date(byAdding: .day, value: 1, to: today) else {
            return nil
        }
        return DateInterval(start: startMonday, end: endOfToday)
    }
}

// MARK: - Narrative Summary Types

/// Represents the top activity for a period, replacing the tuple anti-pattern.
struct ActivitySummary: Equatable {
    let name: String
    let sfSymbol: String
}

/// Represents the top project for a period, replacing the tuple anti-pattern.
struct ProjectSummary: Equatable {
    let name: String
    let emoji: String
}

/// Represents a trend comparison between two periods, replacing the tuple anti-pattern.
struct TrendChange: Equatable {
    let from: String
    let to: String
    let change: Double
}

struct PeriodSessionData: Identifiable {
    let id = UUID()
    let period: ChartTimePeriod
    let sessions: [SessionRecord]
    let totalHours: Double
    let topActivity: ActivitySummary
    let topProject: ProjectSummary
    let averageDailyHours: Double
    let activityDistribution: [String: Double]
    let projectDistribution: [String: Double]
    let timeRange: DateInterval
}

struct ComparativeAnalytics: Identifiable {
    let id = UUID()
    let current: PeriodSessionData
    let previous: PeriodSessionData
    let trends: AnalyticsTrends
}

struct AnalyticsTrends: Identifiable {
    let id = UUID()
    let totalHoursChange: Double
    let topActivityChange: TrendChange
    let topProjectChange: TrendChange
    let averageDailyHoursChange: Double
    let activityDistributionChanges: [String: Double]
    let projectDistributionChanges: [String: Double]
}

struct NarrativeHeadline: Equatable {
    let totalHours: Double
    let topActivity: ActivitySummary
    let topProject: ProjectSummary
    let period: String
    
    var formattedHours: String {
        let hours = Int(totalHours)
        let minutes = Int((totalHours - Double(hours)) * 60)
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
    
    var headlineText: String {
        "This \(period) you logged \(formattedHours). Your focus was **\(topActivity.name)** on **\(topProject.emoji) \(topProject.name)**."
    }
}

// MARK: - Rich Week Summary Types

/// A ranked activity type within the weekly breakdown with its hours.
struct ActivityTypeBreakdown: Identifiable, Equatable {
    let id: String
    let name: String
    let sfSymbol: String
    let hours: Double
}

/// A ranked project within the weekly breakdown with its hours.
struct ProjectBreakdown: Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    let color: String
    let hours: Double
}

/// Full weekly summary with top activities, projects, and comparative data.
struct NarrativeWeekSummary: Equatable {
    let totalHours: Double
    let formattedHours: String
    let topActivities: [ActivityTypeBreakdown]
    let topProjects: [ProjectBreakdown]
    let previousTotalHours: Double
    let deltaHours: Double
}

// MARK: - Narrative Engine
@MainActor
final class NarrativeEngine: ObservableObject {
    @Published var currentHeadline: NarrativeHeadline?
    @Published var weekSummary: NarrativeWeekSummary?
    
    private let sessionManager: SessionManager
    private let projectsViewModel: ProjectsViewModel
    private let activityTypeManager: ActivityTypeManager
    
    init(
        sessionManager: SessionManager? = nil,
        projectsViewModel: ProjectsViewModel? = nil,
        activityTypeManager: ActivityTypeManager? = nil
    ) {
        // Swift 6 actor isolation: avoid referencing MainActor singletons in default arg expressions.
        self.sessionManager = sessionManager ?? .shared
        self.projectsViewModel = projectsViewModel ?? .shared
        self.activityTypeManager = activityTypeManager ?? .shared
    }
    
    func generateWeeklyHeadline() {
        let headline = _generateHeadline(for: .week)
        let summary = _generateWeekSummary()
        DispatchQueue.main.async {
            self.currentHeadline = headline
            self.weekSummary = summary
        }
    }
    
    func generateHeadline(for period: ChartTimePeriod) {
        let headline = _generateHeadline(for: period)
        DispatchQueue.main.async {
            self.currentHeadline = headline
        }
    }
    
    func getCurrentHeadlineText() -> String {
        currentHeadline?.headlineText ?? "Loading your story..."
    }
    
    func getSessionData(for period: ChartTimePeriod, referenceDate: Date = Date()) -> PeriodSessionData {
        let sessions = filterSessions(for: period, referenceDate: referenceDate)
        let calendar = Calendar.current

        return PeriodSessionData(
            period: period,
            sessions: sessions,
            totalHours: calculateTotalHours(from: sessions),
            topActivity: determineTopActivity(from: sessions),
            topProject: determineTopProject(from: sessions),
            averageDailyHours: calculateAverageDailyHours(from: sessions, for: period),
            activityDistribution: calculateActivityDistribution(from: sessions),
            projectDistribution: calculateProjectDistribution(from: sessions),
            timeRange: period.dateInterval(endingAt: referenceDate, calendar: calendar) ?? DateInterval(start: referenceDate, end: referenceDate)
        )
    }

    func getComparativeData(for period: ChartTimePeriod) -> ComparativeAnalytics {
        let calendar = Calendar.current
        let currentDate = Date()
        let currentData = getSessionData(for: period, referenceDate: currentDate)

        let previousData: PeriodSessionData
        if period == .week,
           let previousReferenceDate = calendar.date(byAdding: .weekOfYear, value: -1, to: currentDate) {
            previousData = getSessionData(for: period, referenceDate: previousReferenceDate)
        } else if let component = period.calendarComponent,
                  let previousReferenceDate = calendar.date(byAdding: component, value: -1, to: currentDate) {
            previousData = getSessionData(for: period, referenceDate: previousReferenceDate)
        } else {
            previousData = currentData
        }

        return ComparativeAnalytics(current: currentData, previous: previousData, trends: calculateTrends(current: currentData, previous: previousData))
    }
    
    // MARK: - Private
    
    private func _generateHeadline(for period: ChartTimePeriod, referenceDate: Date = Date()) -> NarrativeHeadline {
        let sessions = filterSessions(for: period, referenceDate: referenceDate)
        return NarrativeHeadline(
            totalHours: calculateTotalHours(from: sessions),
            topActivity: determineTopActivity(from: sessions),
            topProject: determineTopProject(from: sessions),
            period: period.title.lowercased().replacingOccurrences(of: "this ", with: "")
        )
    }
    
    /// Builds the rich week summary with top-3 activities and projects.
    private func _generateWeekSummary() -> NarrativeWeekSummary {
        let sessions = filterSessions(for: .week)
        let totalHours = calculateTotalHours(from: sessions)
        
        // Compute previous week's hours for delta
        let calendar = Calendar.current
        let previousWeekHours: Double
        if let previousReferenceDate = calendar.date(byAdding: .weekOfYear, value: -1, to: Date()) {
            let prevSessions = filterSessions(for: .week, referenceDate: previousReferenceDate)
            previousWeekHours = calculateTotalHours(from: prevSessions)
        } else {
            previousWeekHours = 0
        }
        
        // Build sorted activity type breakdown
        var activityTotals: [String: Double] = [:]
        for session in sessions {
            let id = session.activityTypeID ?? ActivityType.uncategorizedID
            activityTotals[id, default: 0] += Double(session.durationMinutes) / 60.0
        }
        let sortedActivities = activityTotals
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .compactMap { (id, hours) -> ActivityTypeBreakdown? in
                let activity = activityTypeManager.getActivityType(id: id) ?? activityTypeManager.getUncategorizedActivityType()
                return ActivityTypeBreakdown(id: id, name: activity.name, sfSymbol: activity.sfSymbol, hours: hours)
            }
        
        // Build sorted project breakdown
        var projectTotals: [String: Double] = [:]
        for session in sessions {
            projectTotals[session.projectID, default: 0] += Double(session.durationMinutes) / 60.0
        }
        let sortedProjects = projectTotals
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .compactMap { (id, hours) -> ProjectBreakdown? in
                let project = projectsViewModel.projects.first { $0.id == id }
                return ProjectBreakdown(
                    id: id,
                    name: project?.name ?? id,
                    emoji: project?.emoji ?? Project.defaultEmoji,
                    color: project?.color ?? "#999999",
                    hours: hours
                )
            }
        
        // Format hours
        let h = Int(totalHours)
        let m = Int((totalHours - Double(h)) * 60)
        let formatted = h > 0 ? "\(h)h \(m)m" : "\(m)m"
        
        return NarrativeWeekSummary(
            totalHours: totalHours,
            formattedHours: formatted,
            topActivities: Array(sortedActivities),
            topProjects: Array(sortedProjects),
            previousTotalHours: previousWeekHours,
            deltaHours: totalHours - previousWeekHours
        )
    }

    private func filterSessions(for period: ChartTimePeriod, referenceDate: Date = Date()) -> [SessionRecord] {
        let calendar = Calendar.current
        guard let interval = period.dateInterval(endingAt: referenceDate, calendar: calendar) else {
            return []
        }
        return sessionManager.allSessions.filter { interval.contains($0.startDate) }
    }
    
    private func calculateTotalHours(from sessions: [SessionRecord]) -> Double {
        Double(sessions.reduce(0) { $0 + $1.durationMinutes }) / 60.0
    }
    
    private func determineTopActivity(from sessions: [SessionRecord]) -> ActivitySummary {
        var totals: [String: Double] = [:]
        for session in sessions {
            let id = session.activityTypeID ?? ActivityType.uncategorizedID
            totals[id, default: 0] += Double(session.durationMinutes) / 60.0
        }
        guard let topID = totals.max(by: { $0.value < $1.value })?.key else {
            return ActivitySummary(name: "Uncategorized", sfSymbol: ActivityType.defaultSFSymbol)
        }
        let activity = activityTypeManager.getActivityType(id: topID) ?? activityTypeManager.getUncategorizedActivityType()
        return ActivitySummary(name: activity.name, sfSymbol: activity.sfSymbol)
    }
    
    private func determineTopProject(from sessions: [SessionRecord]) -> ProjectSummary {
        var totals: [String: Double] = [:]
        for session in sessions {
            totals[session.projectID, default: 0] += Double(session.durationMinutes) / 60.0
        }
        guard let topID = totals.max(by: { $0.value < $1.value })?.key else {
            return ProjectSummary(name: "No Project", emoji: Project.defaultEmoji)
        }
        let project = projectsViewModel.projects.first { $0.id == topID }
        return ProjectSummary(name: project?.name ?? topID, emoji: project?.emoji ?? Project.defaultEmoji)
    }
    
    private func calculateAverageDailyHours(from sessions: [SessionRecord], for period: ChartTimePeriod) -> Double {
        calculateTotalHours(from: sessions) / Double(period.durationInDays)
    }
    
    private func calculateActivityDistribution(from sessions: [SessionRecord]) -> [String: Double] {
        var dist: [String: Double] = [:]
        for session in sessions {
            let id = session.activityTypeID ?? ActivityType.uncategorizedID
            dist[id, default: 0] += Double(session.durationMinutes) / 60.0
        }
        return dist
    }
    
    private func calculateProjectDistribution(from sessions: [SessionRecord]) -> [String: Double] {
        var dist: [String: Double] = [:]
        for session in sessions {
            dist[session.projectID, default: 0] += Double(session.durationMinutes) / 60.0
        }
        return dist
    }
    
    private func getTimeRange(for period: ChartTimePeriod, calendar: Calendar) -> DateInterval {
        switch period {
        case .week: return calendar.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), end: Date())
        case .month: return calendar.dateInterval(of: .month, for: Date()) ?? DateInterval(start: Date(), end: Date())
        case .year: return calendar.dateInterval(of: .year, for: Date()) ?? DateInterval(start: Date(), end: Date())
        case .allTime: return DateInterval(start: .distantPast, end: .distantFuture)
        }
    }
    
    private func calculateTrends(current: PeriodSessionData, previous: PeriodSessionData) -> AnalyticsTrends {
        AnalyticsTrends(
            totalHoursChange: pctChange(current: current.totalHours, previous: previous.totalHours),
            topActivityChange: TrendChange(from: previous.topActivity.name, to: current.topActivity.name, change: current.activityDistribution[current.topActivity.name, default: 0] - previous.activityDistribution[previous.topActivity.name, default: 0]),
            topProjectChange: TrendChange(from: previous.topProject.name, to: current.topProject.name, change: current.projectDistribution[current.topProject.name, default: 0] - previous.projectDistribution[previous.topProject.name, default: 0]),
            averageDailyHoursChange: pctChange(current: current.averageDailyHours, previous: previous.averageDailyHours),
            activityDistributionChanges: distChanges(current: current.activityDistribution, previous: previous.activityDistribution),
            projectDistributionChanges: distChanges(current: current.projectDistribution, previous: previous.projectDistribution)
        )
    }
    
    private func pctChange(current: Double, previous: Double) -> Double {
        guard previous > 0 else { return current > 0 ? 100.0 : 0.0 }
        return ((current - previous) / previous) * 100.0
    }
    
    private func distChanges(current: [String: Double], previous: [String: Double]) -> [String: Double] {
        let allKeys = Set(current.keys).union(Set(previous.keys))
        var changes: [String: Double] = [:]
        for key in allKeys {
            changes[key] = pctChange(current: current[key, default: 0], previous: previous[key, default: 0])
        }
        return changes
    }
}