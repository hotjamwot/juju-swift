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
/// **AI Quick Find (Method Index)**:
/// - Data Prep: prepareWeeklyData(), prepareAllTimeData()
/// - Accessors: currentWeekSessionsForCalendar(), yearlyProjectTotals(), yearlyActivityTypeTotals()
/// - Utilities: currentWeekInterval (computed), currentYearInterval (computed)
/// 
/// **AI Gotchas**:
/// - [GOTCHA] Input MUST be sessionManager.allSessions (pre-loaded); not lazily fetched
/// - [GOTCHA] Filters archived projects from yearly charts but NOT from weekly (design choice)
/// - [GOTCHA] Percentages calculated as: (total / grandTotal) * 100; handle division-by-zero
/// - [GOTCHA] Monday-based weeks; week boundaries may differ from calendar view
/// - [GOTCHA] Session minutes converted to hours; small sessions round to 0.0 hours visually
/// - [GOTCHA] Activity type names resolved from ActivityTypeManager; missing types show as "uncategorized"
/// 
/// **AI Integrations**:
/// - [RECEIVES] sessionManager.allSessions (must call loadAllSessions() first)
/// - [RECEIVES] projectManager.projects for colors and archived status
/// - [RECEIVES] activityTypeManager.activityTypes for category names
/// - [OUTPUTS] ActivityDistributionItem[] for pie/bar charts
/// - [OUTPUTS] YearlyProjectChartData[] for dashboard display
/// - [OUTPUTS] [DayStack] for 90-day stacked bar chart
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
    @Published var current90DayStacks: [DayStack] = []
    /// Milestones that occurred within the 90-day range (newest first)
    @Published var current90DayMilestones: [DashboardMilestone] = []
    
    private let calendar = Calendar.current
    
    func prepareAllTimeData(sessions: [SessionRecord], projects: [Project]) {
        // [INTEGRATION] Called from DashboardRootView with pre-loaded sessions
        // [INTEGRATION] Updates viewModel which triggers UI refresh
        viewModel.sessions = sessions
        viewModel.projects = projects
    }
    
    func prepareWeeklyData(sessions: [SessionRecord], projects: [Project]) {
        // [INTEGRATION] Called from OverviewDashboardView with pre-loaded sessions
        // [GOTCHA] Filters to current week only (Monday-based); earlier weeks hidden
        // [GOTCHA] Uses currentWeekInterval computed property based on system calendar
        viewModel.sessions = sessions.filter { currentWeekInterval.contains($0.startDate) }
        viewModel.projects = projects
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
    /// - Zero-duration sessions (raw start hour == raw end hour) are dropped.
    /// - Sessions crossing midnight are split into two bubbles: one on the
    ///   start day (clipped to 24:00) and one on the end day (from 0:00 to
    ///   the actual end hour). If the end day is outside the current week
    ///   interval, only the start-day bubble (clipped to 24:00) is shown.
    ///
    /// **Integration**: Uses ActivityTypeManager for activity name/emoji lookup
    ///
    func currentWeekSessionsForCalendar() -> [WeeklySession] {
        let projectLookup = Dictionary(uniqueKeysWithValues: viewModel.projects.map { ($0.id, $0) })
        
        // Filter sessions to only current week sessions
        let currentWeekSessions = viewModel.sessions.filter { currentWeekInterval.contains($0.startDate) }
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"

        let activityTypeManager = ActivityTypeManager.shared

        return currentWeekSessions.flatMap { session -> [WeeklySession] in
            let startComp = calendar.dateComponents([.hour, .minute], from: session.startDate)
            let endComp = calendar.dateComponents([.hour, .minute], from: session.endDate)
            let startHour = Double(startComp.hour ?? 0) + Double(startComp.minute ?? 0) / 60.0
            let rawEndHour = Double(endComp.hour ?? 0) + Double(endComp.minute ?? 0) / 60.0

            // Drop zero-duration sessions (same start and end instant).
            guard rawEndHour != startHour else { return [] }

            let project = projectLookup[session.projectID]
            let projectColor = project?.color ?? "#999999"
            let projectEmoji = project?.emoji ?? Project.defaultEmoji
            let activity = activityTypeManager.getActivityType(id: session.activityTypeID ?? "") ?? activityTypeManager.getUncategorizedActivityType()
            let projectName = project?.name ?? session.projectID
            let activitySFSymbol = activity.sfSymbol

            // Normal same-day session: emit a single bubble on the start day.
            // Cross-midnight session: emit two bubbles — one on the start day
            // (clipped to 24:00) and one on the end day (from 0:00 to the
            // actual end hour). The end day must also fall in the current week
            // interval, otherwise the continuation is not shown.
            if rawEndHour > startHour {
                let day = dayFormatter.string(from: session.startDate)
                return [WeeklySession(day: day, startHour: startHour, endHour: rawEndHour, projectName: projectName, projectColor: projectColor, projectEmoji: projectEmoji, activitySFSymbol: activitySFSymbol)]
            } else {
                guard let endDate = calendar.date(byAdding: .day, value: 1, to: session.startDate),
                      currentWeekInterval.contains(endDate) else {
                    // End day is outside the current week; only show the start day
                    // bubble, clipped to 24:00.
                    let day = dayFormatter.string(from: session.startDate)
                    return [WeeklySession(day: day, startHour: startHour, endHour: 24.0, projectName: projectName, projectColor: projectColor, projectEmoji: projectEmoji, activitySFSymbol: activitySFSymbol)]
                }
                let startDay = dayFormatter.string(from: session.startDate)
                let endDay = dayFormatter.string(from: endDate)
                return [
                    WeeklySession(day: startDay, startHour: startHour, endHour: 24.0, projectName: projectName, projectColor: projectColor, projectEmoji: projectEmoji, activitySFSymbol: activitySFSymbol),
                    WeeklySession(day: endDay, startHour: 0.0, endHour: rawEndHour, projectName: projectName, projectColor: projectColor, projectEmoji: projectEmoji, activitySFSymbol: activitySFSymbol)
                ]
            }
        }
    }
    
    func yearlyProjectTotals() -> [YearlyProjectChartData] {
        let projectLookup = Dictionary(uniqueKeysWithValues: viewModel.projects.filter { !$0.archived }.map { ($0.id, $0) })
        let activeProjectIDs = Set(projectLookup.keys)
        let activityTypeManager = ActivityTypeManager.shared
        let activityLookup = Dictionary(uniqueKeysWithValues: activityTypeManager.getActiveActivityTypes().map { ($0.id, $0) })
        
        // First pass: project totals
        var totals: [String: Double] = [:]
        // Second pass: project → activityType → hours (for breakdown tooltips)
        var projectActivityBreakdown: [String: [String: Double]] = [:]
        
        for session in viewModel.sessions where currentYearInterval.contains(session.startDate) {
            guard activeProjectIDs.contains(session.projectID) else { continue }
            let hours = Double(session.durationMinutes) / 60.0
            totals[session.projectID, default: 0] += hours
            let activityID = session.activityTypeID ?? ActivityType.uncategorizedID
            projectActivityBreakdown[session.projectID, default: [:]][activityID, default: 0] += hours
        }
        
        let total = totals.values.reduce(0, +)
        return totals.compactMap { (projectID, hours) in
            guard hours > 0, let project = projectLookup[projectID] else { return nil }
            let activityBreakdown: [(activityName: String, sfSymbol: String, hours: Double)] =
                (projectActivityBreakdown[projectID] ?? [:])
                    .compactMap { (activityID, actHours) in
                        guard actHours > 0 else { return nil }
                        let activity = activityLookup[activityID] ?? activityTypeManager.getUncategorizedActivityType()
                        return (activityName: activity.name, sfSymbol: activity.sfSymbol, hours: actHours)
                    }
                    .sorted { $0.hours > $1.hours }
            
            return YearlyProjectChartData(
                projectName: project.name,
                color: project.color,
                emoji: project.emoji,
                totalHours: hours,
                percentage: total > 0 ? hours / total * 100 : 0,
                activityBreakdown: activityBreakdown
            )
        }.sorted { $0.totalHours > $1.totalHours }
    }
    
    func yearlyActivityTypeTotals() -> [ActivityDistributionItem] {
        let activityTypeManager = ActivityTypeManager.shared
        let activityLookup = Dictionary(uniqueKeysWithValues: activityTypeManager.getActiveActivityTypes().map { ($0.id, $0) })
        let projectLookup = Dictionary(uniqueKeysWithValues: viewModel.projects.filter { !$0.archived }.map { ($0.id, $0) })
        
        // First pass: activity type totals
        var totals: [String: Double] = [:]
        // Second pass: activityType → project → hours (for breakdown tooltips)
        var activityProjectBreakdown: [String: [String: Double]] = [:]
        
        for session in viewModel.sessions where currentYearInterval.contains(session.startDate) {
            let id = session.activityTypeID ?? ActivityType.uncategorizedID
            let hours = Double(session.durationMinutes) / 60.0
            totals[id, default: 0] += hours
            // Track per-project breakdown even for archived projects so the tooltip is accurate
            activityProjectBreakdown[id, default: [:]][session.projectID, default: 0] += hours
        }
        
        let total = totals.values.reduce(0, +)
        return totals.compactMap { (id, hours) in
            guard hours > 0 else { return nil }
            let activity = activityLookup[id] ?? activityTypeManager.getUncategorizedActivityType()
            let projectBreakdown: [(projectName: String, emoji: String, color: String, hours: Double)] =
                (activityProjectBreakdown[id] ?? [:])
                    .compactMap { (projectID, projHours) in
                        guard projHours > 0, let project = projectLookup[projectID] else { return nil }
                        return (projectName: project.name, emoji: project.emoji, color: project.color, hours: projHours)
                    }
                    .sorted { $0.hours > $1.hours }
            
            return ActivityDistributionItem(
                activityName: activity.name,
                sfSymbol: activity.sfSymbol,
                totalHours: hours,
                percentage: total > 0 ? hours / total * 100 : 0,
                projectBreakdown: projectBreakdown
            )
        }.sorted { $0.totalHours > $1.totalHours }
    }
    
    // MARK: - 90-Day Stacked Bar Chart
    
    /// Build per-day, per-project stacked data for the last N days.
    ///
    /// Every calendar day in the range is represented — days with no sessions
    /// get an empty `segments` array, so the chart can render a zero-height bar.
    ///
    /// - Parameters:
    ///   - days: Number of trailing days to include (default 90)
    ///   - sessions: The session records to aggregate (pass sessionManager.allSessions)
    ///   - projects: All projects (for colour and name lookup)
    func stackedDailyProjectTotals(
        days: Int = 90,
        sessions: [SessionRecord],
        projects: [Project]
    ) {
        let projectLookup = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        let today = calendar.startOfDay(for: Date())
        let totalDays = days  // include today, so go back (days - 1)
        guard let startDate = calendar.date(byAdding: .day, value: -(totalDays - 1), to: today) else {
            current90DayStacks = []
            current90DayMilestones = []
            return
        }
        
        // Accumulate: date → projectID → hours
        var accumulator: [Date: [String: Double]] = [:]
        // Track milestone sessions for marking days and building the list
        var milestoneDays: Set<Date> = []
        var milestoneSessions: [SessionRecord] = []
        // Track individual sessions per day for the info panel
        var sessionsByDay: [Date: [SessionRecord]] = [:]
        let activityTypeManager = ActivityTypeManager.shared
        
        for session in sessions where session.startDate >= startDate && session.startDate <= today {
            let day = calendar.startOfDay(for: session.startDate)
            let hours = Double(session.durationMinutes) / 60.0
            accumulator[day, default: [:]][session.projectID, default: 0] += hours
            sessionsByDay[day, default: []].append(session)
            
            if session.isMilestone, let text = session.action, !text.isEmpty {
                milestoneDays.insert(day)
                milestoneSessions.append(session)
            }
        }
        
        // Build DayStack for every calendar day in the range
        var stacks: [DayStack] = []
        var dayCursor = startDate
        while dayCursor <= today {
            let projectHours = accumulator[dayCursor] ?? [:]
            let segments = projectHours.compactMap { (projectID, hours) -> ProjectSegment? in
                guard hours > 0, let project = projectLookup[projectID] else { return nil }
                return ProjectSegment(
                    projectID: projectID,
                    projectName: project.name,
                    emoji: project.emoji,
                    color: project.color,
                    hours: hours
                )
            }
            .sorted { $0.hours > $1.hours }  // largest on bottom for visual stability
            
            stacks.append(DayStack(
                date: dayCursor,
                segments: segments,
                isMilestone: milestoneDays.contains(dayCursor),
                sessions: sessionsByDay[dayCursor] ?? []
            ))
            
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayCursor) else { break }
            dayCursor = nextDay
        }
        
        current90DayStacks = stacks
        
        // Build Milestone list (newest first) for the 90-day chart section
        current90DayMilestones = milestoneSessions
            .sorted { $0.startDate > $1.startDate }
            .compactMap { session -> DashboardMilestone? in
                guard let text = session.action else { return nil }
                let activity = activityTypeManager.getActivityType(id: session.activityTypeID ?? ActivityType.uncategorizedID) ?? activityTypeManager.getUncategorizedActivityType()
                let project = projectLookup[session.projectID]
                return DashboardMilestone(
                    text: text,
                    date: session.startDate,
                    projectID: session.projectID,
                    projectName: project?.name ?? "Unknown",
                    projectEmoji: project?.emoji ?? Project.defaultEmoji,
                    projectColor: project?.color ?? "#999999",
                    activityType: activity.name
                )
            }
    }
    
}
