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

    var durationInDays: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        case .allTime: return Int.max
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

/// A ranked activity type within the breakdown with its hours.
struct ActivityTypeBreakdown: Identifiable, Equatable {
    let id: String
    let name: String
    let sfSymbol: String
    let hours: Double
}

/// A ranked project within the breakdown with its hours.
struct ProjectBreakdown: Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    let color: String
    let hours: Double
}

/// Full narrative summary for the Overview Dashboard metric cards.
/// - Total hours and delta are for THIS WEEK.
/// - Top activities and projects are for the LAST 30 DAYS (rolling window).
/// - Delta compares this week against the average active week
///   over a rolling 12-month window.
struct NarrativeWeekSummary: Equatable {
    let totalHours: Double
    let formattedHours: String
    let topActivities: [ActivityTypeBreakdown]
    let topProjects: [ProjectBreakdown]
    let averageWeeklyHours: Double
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

    func getCurrentHeadlineText() -> String {
        currentHeadline?.headlineText ?? "Loading your story..."
    }

    func encouragement() -> Phrase? {
        guard let summary = weekSummary, summary.totalHours > 0 else { return nil }

        let sessions = sessionManager.allSessions

        if hasMilestoneThisWeek(from: sessions) {
            return JujuPhrases.milestone()
        }

        if hasActiveStreak(minDays: 3, from: sessions) {
            return JujuPhrases.encouragement()
        }

        if hasProificProject(sessions: sessions) {
            return JujuPhrases.encouragement()
        }

        if highAverageMood(sessions: sessions) {
            return JujuPhrases.encouragement()
        }

        if summary.deltaHours > 1 {
            return JujuPhrases.encouragement()
        } else if summary.deltaHours < -1 {
            return JujuPhrases.encouragement()
        }

        return JujuPhrases.encouragement()
    }

    // MARK: - Private

    private func hasActiveStreak(minDays: Int = 3, from sessions: [SessionRecord]) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today

        for _ in 0..<30 {
            let dayStart = checkDate
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                continue
            }
            let hasSession = sessions.contains { $0.startDate >= dayStart && $0.startDate < dayEnd }
            if hasSession {
                streak += 1
            } else if streak > 0 {
                break
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previous
        }
        return streak >= minDays
    }

    private func hasMilestoneThisWeek(from sessions: [SessionRecord]) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        guard let weekStart = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return false
        }
        return sessions.contains { $0.isMilestone && $0.startDate >= weekStart && $0.startDate < weekEnd }
    }

    private func hasProificProject(sessions: [SessionRecord]) -> Bool {
        let calendar = Calendar.current
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        guard let start = calendar.date(byAdding: .day, value: -30, to: endOfToday) else { return false }
        let recent = sessions.filter { $0.startDate >= start && $0.startDate < endOfToday }

        var projectCounts: [String: Int] = [:]
        for session in recent {
            projectCounts[session.projectID, default: 0] += 1
        }
        return projectCounts.values.max() ?? 0 > 5
    }

    private func highAverageMood(sessions: [SessionRecord]) -> Bool {
        let calendar = Calendar.current
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        guard let start = calendar.date(byAdding: .day, value: -30, to: endOfToday) else { return false }
        let recent = sessions.filter { $0.startDate >= start && $0.startDate < endOfToday }

        let moods = recent.compactMap { $0.mood }
        guard !moods.isEmpty else { return false }
        let avg = Double(moods.reduce(0, +)) / Double(moods.count)
        return avg >= 7.0
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

    /// Builds the rich week summary.
    /// - Total hours: THIS WEEK (Mon → today)
    /// - Top activities/projects: LAST 30 DAYS (rolling window ending today)
    /// - Delta: this week vs average active week over rolling 12-month window
    private func _generateWeekSummary() -> NarrativeWeekSummary {
        let weekSessions = filterSessions(for: .week)
        let last30DaysSessions = filterSessionsForLast30Days()
        let totalHours = calculateTotalHours(from: weekSessions)
        let averageWeeklyHours = calculateAverageWeeklyHours()

        // Build sorted activity type breakdown (last 30 days)
        var activityTotals: [String: Double] = [:]
        for session in last30DaysSessions {
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

        // Build sorted project breakdown (last 30 days)
        var projectTotals: [String: Double] = [:]
        for session in last30DaysSessions {
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
            averageWeeklyHours: averageWeeklyHours,
            deltaHours: totalHours - averageWeeklyHours
        )
    }

    /// Computes the average weekly hours over a rolling 12-month window,
    /// considering only weeks with at least one session, excluding the current partial week.
    /// Each historical week is measured from Monday to the same weekday offset as today
    /// (e.g., if today is Thursday, each week is Mon→Thu), so the comparison is fair.
    private func calculateAverageWeeklyHours() -> Double {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7

        // Start of current week (Monday)
        let currentWeekStart = mondayBasedWeekInterval(containing: now, calendar: calendar).start
        guard let windowStart = calendar.date(byAdding: .month, value: -12, to: currentWeekStart) else {
            return 0
        }

        // Find the first Monday on or before windowStart
        let windowWeekday = calendar.component(.weekday, from: windowStart)
        let windowDaysSinceMonday = (windowWeekday + 5) % 7
        guard let firstMonday = calendar.date(byAdding: .day, value: -windowDaysSinceMonday, to: windowStart) else {
            return 0
        }

        // Iterate over Mondays within the rolling 12-month window,
        // computing partial weeks (Mon → today's weekday offset) for each.
        var weekHours: [Double] = []
        var monday = firstMonday

        while monday < currentWeekStart {
            guard let partialWeekEnd = calendar.date(byAdding: .day, value: daysSinceMonday + 1, to: monday) else {
                monday = calendar.date(byAdding: .day, value: 7, to: monday) ?? monday
                continue
            }

            let weekStart = max(monday, windowStart)
            let weekEnd = min(partialWeekEnd, currentWeekStart)

            guard weekStart < weekEnd else {
                monday = calendar.date(byAdding: .day, value: 7, to: monday) ?? monday
                continue
            }

            let interval = DateInterval(start: weekStart, end: weekEnd)
            let weekSessions = sessionManager.allSessions.filter { interval.contains($0.startDate) }
            let hours = calculateTotalHours(from: weekSessions)
            if hours > 0 {
                weekHours.append(hours)
            }

            monday = calendar.date(byAdding: .day, value: 7, to: monday) ?? monday
        }

        guard !weekHours.isEmpty else { return 0 }
        return weekHours.reduce(0, +) / Double(weekHours.count)
    }

    /// Returns a Monday-based week interval (start Monday 00:00 → next Monday 00:00)
    /// for the date containing `date`, matching the week boundaries used by `ChartTimePeriod`.
    private func mondayBasedWeekInterval(containing date: Date, calendar: Calendar) -> DateInterval {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let daysSinceMonday = (weekday + 5) % 7
        let startMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: day) ?? day
        let endNextMonday = calendar.date(byAdding: .day, value: 7, to: startMonday) ?? day
        return DateInterval(start: startMonday, end: endNextMonday)
    }

    private func filterSessions(for period: ChartTimePeriod, referenceDate: Date = Date()) -> [SessionRecord] {
        let calendar = Calendar.current
        guard let interval = period.dateInterval(endingAt: referenceDate, calendar: calendar) else {
            return []
        }
        return sessionManager.allSessions.filter { interval.contains($0.startDate) }
    }

    /// Filters sessions to a rolling 30-day window ending at the start of tomorrow
    /// (i.e., includes all of today and the 29 preceding days).
    /// Used for the FOCUS and PROJECT metric cards so they reflect a consistent
    /// month-long view rather than resetting on the 1st of each month.
    private func filterSessionsForLast30Days(referenceDate: Date = Date()) -> [SessionRecord] {
        let calendar = Calendar.current
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
        guard let start = calendar.date(byAdding: .day, value: -30, to: endOfToday) else {
            return []
        }
        let interval = DateInterval(start: start, end: endOfToday)
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
}