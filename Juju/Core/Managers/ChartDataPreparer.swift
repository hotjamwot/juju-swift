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
/// - Data Prep: prepareWeeklyData(), prepareAllTimeData(), prepare90DayTimeline()
/// - Accessors: currentWeekSessionsForCalendar(), yearlyProjectTotals(), yearlyActivityTypeTotals()
/// - Utilities: currentWeekInterval (computed), last90DaysInterval / last360DaysInterval (computed)
/// 
/// **AI Gotchas**:
/// - [GOTCHA] Input MUST be sessionManager.allSessions (pre-loaded); not lazily fetched
/// - [GOTCHA] Filters archived projects from yearly charts but NOT from weekly (design choice)
/// - [GOTCHA] Yearly charts use ROLLING windows (last 90 / 360 days), not calendar year —
///   callers must pass all sessions; the preparer filters by window internally
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
/// - [OUTPUTS] [DayStack] for 90-day timeline chart
/// - [OUTPUTS] [DayTimelineSession] for 90-day timeline chart
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
    @Published var current90DayTimeline: [DayTimelineSession] = []
    
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
    
    /// Rolling last-90-days window (includes today).
    private var last90DaysInterval: DateInterval {
        rollingWindowInterval(days: 90)
    }
    
    /// Rolling last-360-days window (includes today).
    private var last360DaysInterval: DateInterval {
        rollingWindowInterval(days: 360)
    }
    
    /// A trailing window of `days` calendar days ending at the end of today.
    private func rollingWindowInterval(days: Int) -> DateInterval {
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else {
            return DateInterval(start: today, end: today)
        }
        return DateInterval(start: start, end: end)
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
                return [WeeklySession(day: day, startHour: startHour, endHour: rawEndHour, projectName: projectName, projectColor: projectColor, projectEmoji: projectEmoji, activitySFSymbol: activitySFSymbol, action: session.action, isMilestone: session.isMilestone, phaseName: project?.phases.first(where: { $0.id == session.projectPhaseID })?.name, notes: session.notes)]
            } else {
                guard let endDate = calendar.date(byAdding: .day, value: 1, to: session.startDate),
                      currentWeekInterval.contains(endDate) else {
                    let day = dayFormatter.string(from: session.startDate)
                    return [WeeklySession(day: day, startHour: startHour, endHour: 24.0, projectName: projectName, projectColor: projectColor, projectEmoji: projectEmoji, activitySFSymbol: activitySFSymbol, action: session.action, isMilestone: session.isMilestone, phaseName: project?.phases.first(where: { $0.id == session.projectPhaseID })?.name, notes: session.notes)]
                }
                let startDay = dayFormatter.string(from: session.startDate)
                let endDay = dayFormatter.string(from: endDate)
                return [
                    WeeklySession(day: startDay, startHour: startHour, endHour: 24.0, projectName: projectName, projectColor: projectColor, projectEmoji: projectEmoji, activitySFSymbol: activitySFSymbol, action: session.action, isMilestone: session.isMilestone, phaseName: project?.phases.first(where: { $0.id == session.projectPhaseID })?.name, notes: session.notes),
                    WeeklySession(day: endDay, startHour: 0.0, endHour: rawEndHour, projectName: projectName, projectColor: projectColor, projectEmoji: projectEmoji, activitySFSymbol: activitySFSymbol, action: session.action, isMilestone: session.isMilestone, phaseName: project?.phases.first(where: { $0.id == session.projectPhaseID })?.name, notes: session.notes)
                ]
            }
        }
    }
    
    /// Project trend totals: rolling last-90-days hours vs yearly average per
    /// 90-day period (rolling last-360-days total ÷ 4).
    ///
    /// **AI Context**: Powers the dual-bar trend chart. Each session in the
    /// 360-day window contributes to the baseline bucket, and additionally to
    /// the 90-day bucket when it falls in the shorter window — a single O(n)
    /// pass fills both. The 360-day total is divided by 4 at the model level
    /// so the view renders two directly comparable bars on one scale.
    ///
    /// **Business Rules**:
    /// - Rolling windows (last 90 / 360 days including today), NOT calendar year
    /// - Archived projects excluded
    /// - Items sorted by 360-day total (descending) for stable ordering
    func yearlyProjectTotals() -> [YearlyProjectChartData] {
        let projectLookup = Dictionary(uniqueKeysWithValues: viewModel.projects.filter { !$0.archived }.map { ($0.id, $0) })
        
        let window90 = last90DaysInterval
        let window360 = last360DaysInterval
        
        // 360-day totals (baseline) and 90-day totals (recent) in one pass
        var totals360: [String: Double] = [:]
        var totals90: [String: Double] = [:]
        
        for session in viewModel.sessions where window360.contains(session.startDate) {
            guard projectLookup[session.projectID] != nil else { continue }
            let hours = Double(session.durationMinutes) / 60.0
            totals360[session.projectID, default: 0] += hours
            if window90.contains(session.startDate) {
                totals90[session.projectID, default: 0] += hours
            }
        }
        
        return totals360.compactMap { (projectID, hours360) in
            guard hours360 > 0, let project = projectLookup[projectID] else { return nil }
            return YearlyProjectChartData(
                projectName: project.name,
                color: project.color,
                emoji: project.emoji,
                recent90DaysHours: totals90[projectID] ?? 0,
                yearlyAvgPer90Days: hours360 / 4
            )
        }.sorted { $0.yearlyAvgPer90Days > $1.yearlyAvgPer90Days }
    }
    
    /// Activity type trend totals: rolling last-90-days hours vs yearly average
    /// per 90-day period (rolling last-360-days total ÷ 4).
    ///
    /// **AI Context**: Mirrors `yearlyProjectTotals()` — one O(n) pass fills
    /// both the 360-day baseline and the 90-day recent buckets; the 360-day
    /// total is divided by 4 so the view renders two comparable bars.
    ///
    /// **Business Rules**:
    /// - Rolling windows (last 90 / 360 days including today), NOT calendar year
    /// - Items sorted by 360-day total (descending) for stable ordering
    func yearlyActivityTypeTotals() -> [ActivityDistributionItem] {
        let activityTypeManager = ActivityTypeManager.shared
        let activityLookup = Dictionary(uniqueKeysWithValues: activityTypeManager.getActiveActivityTypes().map { ($0.id, $0) })
        
        let window90 = last90DaysInterval
        let window360 = last360DaysInterval
        
        // 360-day totals (baseline) and 90-day totals (recent) in one pass
        var totals360: [String: Double] = [:]
        var totals90: [String: Double] = [:]
        
        for session in viewModel.sessions where window360.contains(session.startDate) {
            let id = session.activityTypeID ?? ActivityType.uncategorizedID
            let hours = Double(session.durationMinutes) / 60.0
            totals360[id, default: 0] += hours
            if window90.contains(session.startDate) {
                totals90[id, default: 0] += hours
            }
        }
        
        return totals360.compactMap { (id, hours360) in
            guard hours360 > 0 else { return nil }
            let activity = activityLookup[id] ?? activityTypeManager.getUncategorizedActivityType()
            return ActivityDistributionItem(
                activityName: activity.name,
                sfSymbol: activity.sfSymbol,
                recent90DaysHours: totals90[id] ?? 0,
                yearlyAvgPer90Days: hours360 / 4
            )
        }.sorted { $0.yearlyAvgPer90Days > $1.yearlyAvgPer90Days }
    }
    
    // MARK: - 90-Day Timeline
    
    /// Build per-session sliver data and per-day stacks for the 90-day timeline.
    ///
    /// Emits one `DayTimelineSession` per session, positioned by decimal
    /// start/end hour within its calendar-day column. Sessions that cross
    /// midnight are split into two slivers: one clipped to 24:00 on the
    /// start day and a continuation from 0:00 on the following day (when
    /// that day falls inside the 90-day range).
    ///
    /// Also publishes `current90DayStacks` — one `DayStack` per calendar day
    /// in the range, with milestone flags, the day's session records, and
    /// per-day project lookups for `DaySessionInfoPanel` on hover.
    ///
    /// - Parameters:
    ///   - days: Number of trailing days to include (default 90)
    ///   - sessions: The session records to aggregate (pass sessionManager.allSessions)
    ///   - projects: All projects (for colour and name lookup)
    func prepare90DayTimeline(
        days: Int = 90,
        sessions: [SessionRecord],
        projects: [Project]
    ) {
        let projectLookup = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        let today = calendar.startOfDay(for: Date())
        let totalDays = days  // include today, so go back (days - 1)
        guard let startDate = calendar.date(byAdding: .day, value: -(totalDays - 1), to: today) else {
            current90DayTimeline = []
            current90DayStacks = []
            return
        }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            current90DayTimeline = []
            current90DayStacks = []
            return
        }
        
        func decimalHour(from date: Date) -> Double {
            let comps = calendar.dateComponents([.hour, .minute], from: date)
            return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
        }
        
        var timeline: [DayTimelineSession] = []
        var sessionsByDay: [Date: [SessionRecord]] = [:]
        var milestoneDays: Set<Date> = []
        var projectIDsByDay: [Date: Set<String>] = [:]
        
        for session in sessions where session.startDate >= startDate && session.startDate < tomorrow {
            let startHour = decimalHour(from: session.startDate)
            let rawEndHour = decimalHour(from: session.endDate)
            let project = projectLookup[session.projectID]
            
            // Drop zero-duration sessions (same start and end instant).
            guard rawEndHour != startHour else { continue }
            
            func addSliver(day: Date, start: Double, end: Double) {
                timeline.append(DayTimelineSession(
                    date: day,
                    startHour: start,
                    endHour: end,
                    projectID: session.projectID,
                    projectName: project?.name ?? session.projectID,
                    projectColor: project?.color ?? "#999999",
                    projectEmoji: project?.emoji ?? Project.defaultEmoji,
                    isMilestone: session.isMilestone
                ))
            }
            
            if rawEndHour > startHour {
                // Normal same-day session: single sliver on the start day.
                addSliver(
                    day: calendar.startOfDay(for: session.startDate),
                    start: startHour,
                    end: rawEndHour
                )
            } else {
                // Cross-midnight session: start-day sliver clipped to 24:00,
                // plus a continuation sliver on the following day if it is
                // within the 90-day range.
                addSliver(
                    day: calendar.startOfDay(for: session.startDate),
                    start: startHour,
                    end: 24.0
                )
                
                guard let endDate = calendar.date(byAdding: .day, value: 1, to: session.startDate),
                      endDate <= today else { continue }
                addSliver(
                    day: calendar.startOfDay(for: endDate),
                    start: 0.0,
                    end: rawEndHour
                )
            }
            
            // Track per-day data for the info panel.
            let sessionDay = calendar.startOfDay(for: session.startDate)
            sessionsByDay[sessionDay, default: []].append(session)
            projectIDsByDay[sessionDay, default: []].insert(session.projectID)
            if session.isMilestone {
                milestoneDays.insert(sessionDay)
            }
        }
        
        // Sort by day then start hour for stable rendering.
        current90DayTimeline = timeline.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.startHour < $1.startHour
        }
        
        // Build DayStack for every calendar day in the range.
        var stacks: [DayStack] = []
        var dayCursor = startDate
        while dayCursor <= today {
            let projectIDs = projectIDsByDay[dayCursor] ?? []
            let dayProjects = projectIDs.compactMap { projectID -> DayProjectInfo? in
                guard let project = projectLookup[projectID] else { return nil }
                return DayProjectInfo(
                    id: projectID,
                    name: project.name,
                    color: project.color,
                    emoji: project.emoji
                )
            }
            
            stacks.append(DayStack(
                date: dayCursor,
                isMilestone: milestoneDays.contains(dayCursor),
                sessions: sessionsByDay[dayCursor] ?? [],
                projects: dayProjects
            ))
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayCursor) else { break }
            dayCursor = nextDay
        }
        current90DayStacks = stacks
    }
    
}