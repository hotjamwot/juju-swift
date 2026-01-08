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
}

// MARK: - Narrative Models
struct Milestone: Identifiable, Hashable, Equatable {
    let id = UUID()
    let text: String
    let date: Date
    let projectID: String
    let projectName: String
    let activityType: String
    
    static func == (lhs: Milestone, rhs: Milestone) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text && lhs.date == rhs.date
    }
}

struct PeriodSessionData: Identifiable {
    let id = UUID()
    let period: ChartTimePeriod
    let sessions: [SessionRecord]
    let totalHours: Double
    let topActivity: (name: String, emoji: String)
    let topProject: (name: String, emoji: String)
    let milestones: [Milestone]
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
    let topActivityChange: (from: String, to: String, change: Double)
    let topProjectChange: (from: String, to: String, change: Double)
    let milestoneCountChange: Int
    let averageDailyHoursChange: Double
    let activityDistributionChanges: [String: Double]
    let projectDistributionChanges: [String: Double]
}

struct NarrativeHeadline: Equatable {
    let totalHours: Double
    let topActivity: (name: String, emoji: String)
    let topProject: (name: String, emoji: String)
    let milestone: Milestone?
    let period: String
    
    static func == (lhs: NarrativeHeadline, rhs: NarrativeHeadline) -> Bool {
        lhs.totalHours == rhs.totalHours &&
        lhs.topActivity.name == rhs.topActivity.name &&
        lhs.topActivity.emoji == rhs.topActivity.emoji &&
        lhs.topProject.name == rhs.topProject.name &&
        lhs.topProject.emoji == rhs.topProject.emoji &&
        lhs.milestone == rhs.milestone &&
        lhs.period == rhs.period
    }
    
    var formattedHours: String {
        let hours = Int(totalHours)
        let minutes = Int((totalHours - Double(hours)) * 60)
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
    
    var headlineText: String {
        var text = "This \(period) you logged \(formattedHours). "
        if let milestone = milestone {
            text += "Your focus was **\(topActivity.emoji) \(topActivity.name)** on **\(topProject.emoji) \(topProject.name)**, where you reached a milestone: **'\(milestone.text)'**."
        } else {
            text += "Your focus was **\(topActivity.emoji) \(topActivity.name)** on **\(topProject.emoji) \(topProject.name)**."
        }
        return text
    }
}

// MARK: - Narrative Engine
@MainActor
final class NarrativeEngine: ObservableObject {
    @Published var currentHeadline: NarrativeHeadline?
    @Published var currentWeekMilestones: [Milestone] = []
    
    private let sessionManager: SessionManager
    private let projectsViewModel: ProjectsViewModel
    private let activityTypeManager: ActivityTypeManager
    
    init(sessionManager: SessionManager = .shared,
         projectsViewModel: ProjectsViewModel = .shared,
         activityTypeManager: ActivityTypeManager = .shared) {
        self.sessionManager = sessionManager
        self.projectsViewModel = projectsViewModel
        self.activityTypeManager = activityTypeManager
    }
    
    func generateWeeklyHeadline() {
        let headline = _generateHeadline(for: .week)
        let milestones = detectAllCurrentWeekMilestones()
        DispatchQueue.main.async {
            self.currentHeadline = headline
            self.currentWeekMilestones = milestones
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
    
    func getSessionData(for period: ChartTimePeriod) -> PeriodSessionData {
        let sessions = filterSessions(for: period)
        let calendar = Calendar.current
        
        return PeriodSessionData(
            period: period,
            sessions: sessions,
            totalHours: calculateTotalHours(from: sessions),
            topActivity: determineTopActivity(from: sessions),
            topProject: determineTopProject(from: sessions),
            milestones: detectMilestones(in: sessions),
            averageDailyHours: calculateAverageDailyHours(from: sessions, for: period),
            activityDistribution: calculateActivityDistribution(from: sessions),
            projectDistribution: calculateProjectDistribution(from: sessions),
            timeRange: getTimeRange(for: period, calendar: calendar)
        )
    }
    
    func getComparativeData(for period: ChartTimePeriod) -> ComparativeAnalytics {
        let currentData = getSessionData(for: period)
        let previousData = getSessionData(for: period.previousPeriod)
        return ComparativeAnalytics(current: currentData, previous: previousData, trends: calculateTrends(current: currentData, previous: previousData))
    }
    
    // MARK: - Private
    
    private func _generateHeadline(for period: ChartTimePeriod) -> NarrativeHeadline {
        let sessions = filterSessions(for: period)
        return NarrativeHeadline(
            totalHours: calculateTotalHours(from: sessions),
            topActivity: determineTopActivity(from: sessions),
            topProject: determineTopProject(from: sessions),
            milestone: detectRecentMilestone(from: sessions),
            period: period.title.lowercased().replacingOccurrences(of: "this ", with: "")
        )
    }
    
    private func filterSessions(for period: ChartTimePeriod) -> [SessionRecord] {
        let calendar = Calendar.current
        switch period {
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), end: Date())
            return sessionManager.allSessions.filter { interval.contains($0.startDate) }
        case .month:
            let interval = calendar.dateInterval(of: .month, for: Date()) ?? DateInterval(start: Date(), end: Date())
            return sessionManager.allSessions.filter { interval.contains($0.startDate) }
        case .year:
            let interval = calendar.dateInterval(of: .year, for: Date()) ?? DateInterval(start: Date(), end: Date())
            return sessionManager.allSessions.filter { interval.contains($0.startDate) }
        case .allTime:
            return sessionManager.allSessions
        }
    }
    
    private func calculateTotalHours(from sessions: [SessionRecord]) -> Double {
        Double(sessions.reduce(0) { $0 + $1.durationMinutes }) / 60.0
    }
    
    private func determineTopActivity(from sessions: [SessionRecord]) -> (name: String, emoji: String) {
        var totals: [String: Double] = [:]
        for session in sessions {
            let id = session.activityTypeID ?? "uncategorized"
            totals[id, default: 0] += Double(session.durationMinutes) / 60.0
        }
        guard let topID = totals.max(by: { $0.value < $1.value })?.key else {
            return ("Uncategorized", "📝")
        }
        let activity = activityTypeManager.getActivityType(id: topID) ?? activityTypeManager.getUncategorizedActivityType()
        return (activity.name, activity.emoji)
    }
    
    private func determineTopProject(from sessions: [SessionRecord]) -> (name: String, emoji: String) {
        var totals: [String: Double] = [:]
        for session in sessions {
            totals[session.projectID, default: 0] += Double(session.durationMinutes) / 60.0
        }
        guard let topID = totals.max(by: { $0.value < $1.value })?.key else {
            return ("No Project", "📁")
        }
        let project = projectsViewModel.projects.first { $0.id == topID }
        return (project?.name ?? topID, project?.emoji ?? "📁")
    }
    
    private func detectRecentMilestone(from sessions: [SessionRecord]) -> Milestone? {
        guard let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return nil }
        let recent = sessions.filter { $0.startDate >= oneWeekAgo && !($0.milestoneText?.isEmpty ?? true) }
            .sorted { $0.startDate > $1.startDate }
        guard let session = recent.first, let text = session.milestoneText else { return nil }
        let activity = activityTypeManager.getActivityType(id: session.activityTypeID ?? "uncategorized") ?? activityTypeManager.getUncategorizedActivityType()
        let project = projectsViewModel.projects.first { $0.id == session.projectID }
        return Milestone(text: text, date: session.startDate, projectID: session.projectID, projectName: project?.name ?? "Unknown Project", activityType: activity.name)
    }
    
    private func detectAllCurrentWeekMilestones() -> [Milestone] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return sessionManager.allSessions
            .filter { interval.contains($0.startDate) && !($0.milestoneText?.isEmpty ?? true) }
            .sorted { $0.startDate > $1.startDate }
            .compactMap { session -> Milestone? in
                guard let text = session.milestoneText else { return nil }
                let activity = activityTypeManager.getActivityType(id: session.activityTypeID ?? "uncategorized") ?? activityTypeManager.getUncategorizedActivityType()
                let project = projectsViewModel.projects.first { $0.id == session.projectID }
                return Milestone(text: text, date: session.startDate, projectID: session.projectID, projectName: project?.name ?? "Unknown Project", activityType: activity.name)
            }
    }
    
    private func detectMilestones(in sessions: [SessionRecord]) -> [Milestone] {
        sessions.compactMap { session -> Milestone? in
            guard let text = session.milestoneText else { return nil }
            let activity = activityTypeManager.getActivityType(id: session.activityTypeID ?? "uncategorized") ?? activityTypeManager.getUncategorizedActivityType()
            let project = projectsViewModel.projects.first { $0.id == session.projectID }
            return Milestone(text: text, date: session.startDate, projectID: session.projectID, projectName: project?.name ?? "Unknown Project", activityType: activity.name)
        }
    }
    
    private func calculateAverageDailyHours(from sessions: [SessionRecord], for period: ChartTimePeriod) -> Double {
        calculateTotalHours(from: sessions) / Double(period.durationInDays)
    }
    
    private func calculateActivityDistribution(from sessions: [SessionRecord]) -> [String: Double] {
        var dist: [String: Double] = [:]
        for session in sessions {
            let id = session.activityTypeID ?? "uncategorized"
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
            topActivityChange: (previous.topActivity.name, current.topActivity.name, current.activityDistribution[current.topActivity.name, default: 0] - previous.activityDistribution[previous.topActivity.name, default: 0]),
            topProjectChange: (previous.topProject.name, current.topProject.name, current.projectDistribution[current.topProject.name, default: 0] - previous.projectDistribution[previous.topProject.name, default: 0]),
            milestoneCountChange: current.milestones.count - previous.milestones.count,
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
