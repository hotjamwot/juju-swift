import Foundation
import SwiftUI

// MARK: - Time Period Enum (for Editorial Engine filtering)
/// Defines the available time periods for filtering sessions in the Editorial Engine.
/// This enum is used specifically by the Editorial Engine for narrative generation.
/// 
/// FUTURE-PROOFING: Designed to support comparative analytics (week-on-week, month-on-month)
/// and complex time-based insights as the Editorial Engine evolves.
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
    
    /// Get the previous period for comparative analysis
    /// FUTURE USE: Enables week-on-week, month-on-month comparisons
    var previousPeriod: ChartTimePeriod {
        return self // Placeholder for future implementation
    }
    
    /// Get the duration in days for this period
    /// FUTURE USE: Normalization for fair comparisons across different time periods
    var durationInDays: Int {
        switch self {
        case .week: return 7
        case .month: return 30 // Approximate
        case .year: return 365 // Approximate
        case .allTime: return Int.max
        }
    }
}

// MARK: - Editorial Engine Models

/// Represents a milestone detected from session data
struct Milestone: Identifiable, Hashable, Equatable {
    let id = UUID()
    let text: String
    let date: Date
    let projectName: String
    let activityType: String
    
    static func == (lhs: Milestone, rhs: Milestone) -> Bool {
        return lhs.id == rhs.id &&
               lhs.text == rhs.text &&
               lhs.date == rhs.date &&
               lhs.projectName == rhs.projectName &&
               lhs.activityType == rhs.activityType
    }
}

/// Enhanced session data for a specific time period with comprehensive analytics
struct PeriodSessionData: Identifiable {
    let id = UUID()
    let period: ChartTimePeriod
    let sessions: [SessionRecord]
    let totalHours: Double
    let topActivity: (name: String, emoji: String)
    let topProject: (name: String, emoji: String)
    let milestones: [Milestone]
    let averageDailyHours: Double
    let activityDistribution: [String: Double] // activityID -> hours
    let projectDistribution: [String: Double] // projectName -> hours
    let timeRange: DateInterval
}

/// Comparative analytics between two time periods
struct ComparativeAnalytics: Identifiable {
    let id = UUID()
    let current: PeriodSessionData
    let previous: PeriodSessionData
    let trends: AnalyticsTrends
}

/// Trend analysis results for comparative analytics
struct AnalyticsTrends: Identifiable {
    let id = UUID()
    let totalHoursChange: Double // Percentage change
    let topActivityChange: (from: String, to: String, change: Double)
    let topProjectChange: (from: String, to: String, change: Double)
    let milestoneCountChange: Int
    let averageDailyHoursChange: Double
    let activityDistributionChanges: [String: Double] // activityID -> percentage change
    let projectDistributionChanges: [String: Double] // projectName -> percentage change
}

/// Narrative headline components for dynamic generation
struct NarrativeHeadline: Equatable {
    let totalHours: Double
    let topActivity: (name: String, emoji: String)
    let topProject: (name: String, emoji: String)
    let milestone: Milestone?
    let period: String
    
    static func == (lhs: NarrativeHeadline, rhs: NarrativeHeadline) -> Bool {
        return lhs.totalHours == rhs.totalHours &&
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
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
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

// MARK: - Editorial Engine Service

/// The Editorial Engine generates compelling narrative headlines for the dashboard
/// based on session data, activity types, and project information.
@MainActor
final class EditorialEngine: ObservableObject {
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
    
    // MARK: - Public Interface
    
    /// Generate narrative headline for the current week
    func generateWeeklyHeadline() {
        let headline = _generateHeadline(for: .week)
        let milestones = detectAllCurrentWeekMilestones()
        DispatchQueue.main.async {
            self.currentHeadline = headline
            self.currentWeekMilestones = milestones
        }
    }
    
    /// Generate narrative headline for the specified period
    func generateHeadline(for period: ChartTimePeriod) {
        let headline = _generateHeadline(for: period)
        DispatchQueue.main.async {
            self.currentHeadline = headline
        }
    }
    
    /// Get the current headline text for display
    func getCurrentHeadlineText() -> String {
        return currentHeadline?.headlineText ?? "Loading your creative story..."
    }
    
    // MARK: - Future Analytics Preparation
    
    /// Get session data for a specific period with enhanced metadata
    /// FUTURE USE: Foundation for comparative analytics and trend detection
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
    
    /// Get comparative data between current and previous periods
    /// FUTURE USE: Week-on-week, month-on-month comparisons
    func getComparativeData(for period: ChartTimePeriod) -> ComparativeAnalytics {
        let currentData = getSessionData(for: period)
        let previousData = getSessionData(for: period.previousPeriod)
        
        return ComparativeAnalytics(
            current: currentData,
            previous: previousData,
            trends: calculateTrends(current: currentData, previous: previousData)
        )
    }
    
    // MARK: - Private Implementation
    
    private func _generateHeadline(for period: ChartTimePeriod) -> NarrativeHeadline {
        let sessions = filterSessions(for: period)
        let totalHours = calculateTotalHours(from: sessions)
        let topActivity = determineTopActivity(from: sessions)
        let topProject = determineTopProject(from: sessions)
        let milestone = detectRecentMilestone(from: sessions)
        
        return NarrativeHeadline(
            totalHours: totalHours,
            topActivity: topActivity,
            topProject: topProject,
            milestone: milestone,
            period: period.title.lowercased().replacingOccurrences(of: "this ", with: "")
        )
    }
    
    private func filterSessions(for period: ChartTimePeriod) -> [SessionRecord] {
        let calendar = Calendar.current
        
        switch period {
        case .week:
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), end: Date())
            return sessionManager.allSessions.filter { session in
                DateFormatter.cachedYYYYMMDD.date(from: session.date).map { weekInterval.contains($0) } ?? false
            }
        case .month:
            let monthInterval = calendar.dateInterval(of: .month, for: Date()) ?? DateInterval(start: Date(), end: Date())
            return sessionManager.allSessions.filter { session in
                DateFormatter.cachedYYYYMMDD.date(from: session.date).map { monthInterval.contains($0) } ?? false
            }
        case .year:
            let yearInterval = calendar.dateInterval(of: .year, for: Date()) ?? DateInterval(start: Date(), end: Date())
            return sessionManager.allSessions.filter { session in
                DateFormatter.cachedYYYYMMDD.date(from: session.date).map { yearInterval.contains($0) } ?? false
            }
        case .allTime:
            return sessionManager.allSessions
        }
    }
    
    private func calculateTotalHours(from sessions: [SessionRecord]) -> Double {
        let totalMinutes = sessions.reduce(into: 0) { result, session in
            result += session.durationMinutes
        }
        return Double(totalMinutes) / 60.0
    }
    
    private func determineTopActivity(from sessions: [SessionRecord]) -> (name: String, emoji: String) {
        var activityTotals: [String: Double] = [:]
        
        for session in sessions {
            let activityID = session.activityTypeID ?? "uncategorized"
            let hours = Double(session.durationMinutes) / 60.0
            activityTotals[activityID, default: 0] += hours
        }
        
        guard let topActivityID = activityTotals.max(by: { $0.value < $1.value })?.key else {
            return ("Uncategorized", "📝")
        }
        
        let activityType = activityTypeManager.getActivityType(id: topActivityID) ??
                          activityTypeManager.getUncategorizedActivityType()
        
        return (activityType.name, activityType.emoji)
    }
    
    private func determineTopProject(from sessions: [SessionRecord]) -> (name: String, emoji: String) {
        var projectTotals: [String: Double] = [:]
        
        for session in sessions {
            let projectName = session.projectName
            let hours = Double(session.durationMinutes) / 60.0
            projectTotals[projectName, default: 0] += hours
        }
        
        guard let topProjectName = projectTotals.max(by: { $0.value < $1.value })?.key else {
            return ("No Project", "📁")
        }
        
        let project = projectsViewModel.projects.first { $0.name == topProjectName } ??
                     Project(id: "unknown", name: topProjectName, color: "#999999", about: nil, order: 0, emoji: "📁", phases: [])
        
        return (project.name, project.emoji)
    }
    
    private func detectRecentMilestone(from sessions: [SessionRecord]) -> Milestone? {
        // Look for sessions with milestone text in the last 7 days
        let calendar = Calendar.current
        guard let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else {
            return nil
        }
        
        let recentSessions = sessions.filter { session in
            guard let sessionDate = DateFormatter.cachedYYYYMMDD.date(from: session.date) else { return false }
            return sessionDate >= oneWeekAgo && (session.milestoneText?.isEmpty == false)
        }
        
        // Return the most recent milestone
        let sortedSessions = recentSessions.sorted { session1, session2 in
            guard let date1 = DateFormatter.cachedYYYYMMDD.date(from: session1.date),
                  let date2 = DateFormatter.cachedYYYYMMDD.date(from: session2.date) else { return false }
            return date1 > date2
        }
        
        guard let milestoneSession = sortedSessions.first,
              let milestoneText = milestoneSession.milestoneText,
              let sessionDate = DateFormatter.cachedYYYYMMDD.date(from: milestoneSession.date) else {
            return nil
        }
        
        let activityType = activityTypeManager.getActivityType(id: milestoneSession.activityTypeID ?? "uncategorized") ??
                          activityTypeManager.getUncategorizedActivityType()
        
        return Milestone(
            text: milestoneText,
            date: sessionDate,
            projectName: milestoneSession.projectName,
            activityType: activityType.name
        )
    }
    
    /// Detect all milestones from the current week
    private func detectAllCurrentWeekMilestones() -> [Milestone] {
        let calendar = Calendar.current
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), end: Date())
        
        let weekSessions = sessionManager.allSessions.filter { session in
            guard let sessionDate = DateFormatter.cachedYYYYMMDD.date(from: session.date) else { return false }
            return weekInterval.contains(sessionDate) && (session.milestoneText?.isEmpty == false)
        }
        
        // Sort by date (most recent first)
        let sortedSessions = weekSessions.sorted { session1, session2 in
            guard let date1 = DateFormatter.cachedYYYYMMDD.date(from: session1.date),
                  let date2 = DateFormatter.cachedYYYYMMDD.date(from: session2.date) else { return false }
            return date1 > date2
        }
        
        return sortedSessions.compactMap { session in
            guard let milestoneText = session.milestoneText,
                  let sessionDate = DateFormatter.cachedYYYYMMDD.date(from: session.date) else {
                return nil
            }
            
            let activityType = activityTypeManager.getActivityType(id: session.activityTypeID ?? "uncategorized") ??
                              activityTypeManager.getUncategorizedActivityType()
            
            return Milestone(
                text: milestoneText,
                date: sessionDate,
                projectName: session.projectName,
                activityType: activityType.name
            )
        }
    }
    
    // MARK: - Enhanced Analytics Helper Methods
    
    /// Detect milestones in a specific session set
    /// FUTURE USE: Part of enhanced analytics framework
    private func detectMilestones(in sessions: [SessionRecord]) -> [Milestone] {
        return sessions.compactMap { session in
            guard let milestoneText = session.milestoneText,
                  let sessionDate = DateFormatter.cachedYYYYMMDD.date(from: session.date) else {
                return nil
            }
            
            let activityType = activityTypeManager.getActivityType(id: session.activityTypeID ?? "uncategorized") ??
                              activityTypeManager.getUncategorizedActivityType()
            
            return Milestone(
                text: milestoneText,
                date: sessionDate,
                projectName: session.projectName,
                activityType: activityType.name
            )
        }
    }
    
    /// Calculate average daily hours for a period
    /// FUTURE USE: Normalization for fair comparisons across different time periods
    private func calculateAverageDailyHours(from sessions: [SessionRecord], for period: ChartTimePeriod) -> Double {
        let totalHours = calculateTotalHours(from: sessions)
        let daysInPeriod = Double(period.durationInDays)
        return totalHours / daysInPeriod
    }
    
    /// Calculate activity distribution across all activities
    /// FUTURE USE: Trend analysis and comparative analytics
    private func calculateActivityDistribution(from sessions: [SessionRecord]) -> [String: Double] {
        var distribution: [String: Double] = [:]
        
        for session in sessions {
            let activityID = session.activityTypeID ?? "uncategorized"
            let hours = Double(session.durationMinutes) / 60.0
            distribution[activityID, default: 0] += hours
        }
        
        return distribution
    }
    
    /// Calculate project distribution across all projects
    /// FUTURE USE: Trend analysis and comparative analytics
    private func calculateProjectDistribution(from sessions: [SessionRecord]) -> [String: Double] {
        var distribution: [String: Double] = [:]
        
        for session in sessions {
            let projectName = session.projectName
            let hours = Double(session.durationMinutes) / 60.0
            distribution[projectName, default: 0] += hours
        }
        
        return distribution
    }
    
    /// Get the time range for a specific period
    /// FUTURE USE: Precise time-based analytics and comparisons
    private func getTimeRange(for period: ChartTimePeriod, calendar: Calendar) -> DateInterval {
        switch period {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), end: Date())
        case .month:
            return calendar.dateInterval(of: .month, for: Date()) ?? DateInterval(start: Date(), end: Date())
        case .year:
            return calendar.dateInterval(of: .year, for: Date()) ?? DateInterval(start: Date(), end: Date())
        case .allTime:
            return DateInterval(start: Date.distantPast, end: Date.distantFuture)
        }
    }
    
    /// Calculate trends between current and previous periods
    /// FUTURE USE: Comparative analytics and insight generation
    private func calculateTrends(current: PeriodSessionData, previous: PeriodSessionData) -> AnalyticsTrends {
        // Calculate percentage changes
        let totalHoursChange = calculatePercentageChange(current: current.totalHours, previous: previous.totalHours)
        let averageDailyHoursChange = calculatePercentageChange(current: current.averageDailyHours, previous: previous.averageDailyHours)
        
        // Calculate milestone count change
        let milestoneCountChange = current.milestones.count - previous.milestones.count
        
        // Calculate top activity change
        let topActivityChange = (
            from: previous.topActivity.name,
            to: current.topActivity.name,
            change: current.activityDistribution[current.topActivity.name, default: 0] - previous.activityDistribution[previous.topActivity.name, default: 0]
        )
        
        // Calculate top project change
        let topProjectChange = (
            from: previous.topProject.name,
            to: current.topProject.name,
            change: current.projectDistribution[current.topProject.name, default: 0] - previous.projectDistribution[previous.topProject.name, default: 0]
        )
        
        // Calculate distribution changes
        let activityDistributionChanges = calculateDistributionChanges(
            current: current.activityDistribution,
            previous: previous.activityDistribution
        )
        
        let projectDistributionChanges = calculateDistributionChanges(
            current: current.projectDistribution,
            previous: previous.projectDistribution
        )
        
        return AnalyticsTrends(
            totalHoursChange: totalHoursChange,
            topActivityChange: topActivityChange,
            topProjectChange: topProjectChange,
            milestoneCountChange: milestoneCountChange,
            averageDailyHoursChange: averageDailyHoursChange,
            activityDistributionChanges: activityDistributionChanges,
            projectDistributionChanges: projectDistributionChanges
        )
    }
    
    /// Calculate percentage change between two values
    /// FUTURE USE: Trend calculation helper
    private func calculatePercentageChange(current: Double, previous: Double) -> Double {
        guard previous > 0 else { return current > 0 ? 100.0 : 0.0 }
        return ((current - previous) / previous) * 100.0
    }
    
    /// Calculate distribution changes between periods
    /// FUTURE USE: Detailed trend analysis
    private func calculateDistributionChanges(current: [String: Double], previous: [String: Double]) -> [String: Double] {
        var changes: [String: Double] = [:]
        
        // Get all keys from both distributions
        let allKeys = Set(current.keys).union(Set(previous.keys))
        
        for key in allKeys {
            let currentValue = current[key, default: 0]
            let previousValue = previous[key, default: 0]
            changes[key] = calculatePercentageChange(current: currentValue, previous: previousValue)
        }
        
        return changes
    }
}
