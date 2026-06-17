import SwiftUI
import Charts

extension Date {
    var isInCurrentYear: Bool {
        let cal = Calendar.current
        return cal.component(.year, from: self) ==
               cal.component(.year, from: Date())
    }
}

// MARK: - Overview Dashboard View

/// Overview (weekly) dashboard — the single dashboard view for the app.
///
/// Charts float freely at their natural height with consistent horizontal margins.
/// Narrative metric cards use an explicit `surface` background for depth.
/// The optional ActiveSessionStatusView pushes everything down when a session is live.
/// At the bottom, yearly project and activity type distribution charts sit side-by-side.
struct OverviewDashboardView: View {
    // MARK: - State objects (passed from DashboardRootView)
    @ObservedObject var chartDataPreparer: ChartDataPreparer
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var projectsViewModel: ProjectsViewModel
    @ObservedObject var narrativeEngine: NarrativeEngine
    
    // MARK: - Loading state
    @State private var isLoading = false
    
    // MARK: - Hover state
    @State private var hoveredDay: DayStack? = nil
    
    // MARK: - Ideal heights
    private let calendarMinHeight: CGFloat = 400
    private let stackedBarMinHeight: CGFloat = 200
    private let distributionChartMinHeight: CGFloat = 340
    
    // MARK: - Spacing
    /// Space between a section header and its content
    private let headerToContentGap: CGFloat = Theme.Spacing.xs
    /// Space between the bottom of one section and the next section's header
    private let sectionGap: CGFloat = Theme.Spacing.xxl + 8  // ~56pt
    
    // MARK - Date Intervals
    private var currentYearInterval: DateInterval {
        let today = Date()
        guard let year = Calendar.current.dateInterval(of: .year, for: today) else {
            return DateInterval(start: today, end: today)
        }
        return year
    }
    
    // MARK - Body
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: sectionGap) {
                // Active Session Bar (appears at top when session is live,
                // naturally pushes all content down)
                if sessionManager.activeSession != nil {
                    ActiveSessionStatusView(sessionManager: sessionManager)
                        .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                }
                
                // Narrative Summary — THIS WEEK | FOCUS | PROJECT as metric cards
                NarrativeSummaryCard(narrativeEngine: narrativeEngine)
                    .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                
                // Weekly Calendar Chart — day/hour session blocks
                VStack(spacing: headerToContentGap) {
                    chartSectionHeader("This Week")
                        .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                    SessionCalendarChartView(
                        sessions: chartDataPreparer.currentWeekSessionsForCalendar()
                    )
                    .frame(minHeight: calendarMinHeight)
                    .chartContainer()
                }
                
                // 90-Day Stacked Bar Chart — daily project breakdown
                VStack(spacing: headerToContentGap) {
                    chartSectionHeader("90-Day Overview")
                        .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                    VStack(spacing: Theme.Spacing.sm) {
                        Session90DayBarChartView(
                            dayStacks: chartDataPreparer.current90DayStacks,
                            hoveredDay: $hoveredDay
                        )
                        .frame(minHeight: stackedBarMinHeight)
                        
                        // Info panel — full width, no milestone sidebar
                        DaySessionInfoPanel(dayStack: hoveredDay)
                    }
                    .chartContainer()
                }
                
                // Yearly Distribution Charts — side-by-side
                VStack(spacing: headerToContentGap) {
                    chartSectionHeader("Yearly Totals")
                        .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                    HStack(spacing: Theme.Spacing.lg) {
                        // Project Distribution Chart
                        YearlyProjectBarChartView(
                            data: chartDataPreparer.yearlyProjectTotals()
                        )
                        .frame(minHeight: distributionChartMinHeight)
                        
                        // Activity Types Distribution Chart
                        YearlyActivityTypeBarChartView(
                            data: chartDataPreparer.yearlyActivityTypeTotals()
                        )
                        .frame(minHeight: distributionChartMinHeight)
                    }
                    .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                }
            }
            .padding(.vertical, Theme.DashboardLayout.dashboardPadding)
        }
        // Loading overlay
        .overlay(
            Group {
                if isLoading {
                    Rectangle()
                        .fill(Theme.Colors.background.opacity(0.6))
                        .overlay(
                            VStack(spacing: 20) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Loading dashboard...")
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Theme.Colors.surface)
                            .cornerRadius(Theme.Design.cornerRadius)
                        )
                }
            }
        )
        .onAppear {
            Task {
                await projectsViewModel.loadProjects()
                isLoading = true
                await refreshDashboardData()
                isLoading = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionDidStart)) { _ in
            Task { await refreshDashboardData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { _ in
            Task { await refreshDashboardData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .projectsDidChange)) { _ in
            Task { await refreshDashboardData() }
        }
        .onChange(of: sessionManager.allSessions.count) { _ in
            guard !isLoading else { return }
            Task { await refreshDashboardData() }
        }
        .onChange(of: projectsViewModel.projects.count) { _ in
            guard !isLoading else { return }
            Task { await refreshDashboardData() }
        }
    }
    
    // MARK: - Data Refresh
    
    /// Refresh all dashboard data — chart data preparation and narrative headline.
    /// Extracted from inline closures to eliminate ~60 lines of duplication.
    private func refreshDashboardData() async {
        await MainActor.run {
            let yearlySessions = sessionManager.allSessions.filter { session in
                currentYearInterval.contains(session.startDate)
            }
            
            chartDataPreparer.prepareWeeklyData(
                sessions: sessionManager.allSessions,
                projects: projectsViewModel.projects
            )
            
            chartDataPreparer.prepareAllTimeData(
                sessions: yearlySessions,
                projects: projectsViewModel.projects
            )
            
            chartDataPreparer.stackedDailyProjectTotals(
                days: 90,
                sessions: sessionManager.allSessions,
                projects: projectsViewModel.projects
            )
            
            narrativeEngine.generateWeeklyHeadline()
        }
    }
    
    // MARK: - Section Header
    
    private func chartSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.Fonts.narrative.weight(.semibold))
            .foregroundColor(Theme.Colors.textSecondary)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Narrative Summary Card (3 metric cards)

/// Displays THIS WEEK | FOCUS | PROJECT as slim editorial metric cards.
/// Each card has a subtle surface background, a compact header row with
/// an SF Symbol icon, and ranked breakdowns (top-3 activity types / projects).
private struct NarrativeSummaryCard: View {
    @ObservedObject var narrativeEngine: NarrativeEngine

    private var weekSummary: NarrativeWeekSummary? {
        narrativeEngine.weekSummary
    }

    var body: some View {
        if let summary = weekSummary {
            HStack(spacing: Theme.Spacing.sm) {
                // Card 1: Total Duration — uses clock icon
                NarrativeMetricCard(title: "THIS WEEK", iconName: "clock") {
                    VStack(spacing: Theme.Spacing.xxs) {
                        Text(summary.formattedHours)
                            .font(Theme.Fonts.metricValue)
                            .foregroundColor(Theme.Colors.textPrimary)

                        // Delta vs last week
                        deltaView(delta: summary.deltaHours)
                    }
                }

                // Card 2: Focus Activity Types (top 3)
                NarrativeMetricCard(title: "FOCUS", iconName: "target") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        ForEach(summary.topActivities.prefix(3)) { activity in
                            HStack(spacing: Theme.Spacing.xxs) {
                                Image(systemName: activity.sfSymbol)
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .frame(width: 14, alignment: .center)
                                Text(activity.name)
                                    .font(Theme.Fonts.narrative)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(formatCompactHours(activity.hours))
                                    .font(Theme.Fonts.narrativeAccent)
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                        }
                        // If no activities, show placeholder
                        if summary.topActivities.isEmpty {
                            Text("No activities logged")
                                .font(Theme.Fonts.narrative)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }

                // Card 3: Top Projects (top 3)
                NarrativeMetricCard(title: "PROJECT", iconName: "folder") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        ForEach(summary.topProjects.prefix(3)) { project in
                            HStack(spacing: Theme.Spacing.xxs) {
                                Text(project.emoji)
                                    .font(Theme.Fonts.caption)
                                    .frame(width: 14, alignment: .center)
                                Text(project.name)
                                    .font(Theme.Fonts.narrative)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(formatCompactHours(project.hours))
                                    .font(Theme.Fonts.narrativeAccent)
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                        }
                        // If no projects, show placeholder
                        if summary.topProjects.isEmpty {
                            Text("No projects logged")
                                .font(Theme.Fonts.narrative)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
            }
        } else {
            HStack {
                Spacer()
                VStack(spacing: Theme.Spacing.xs) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading your story...")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Helpers

    /// Compact hours display: "6.2h" or "45m"
    private func formatCompactHours(_ hours: Double) -> String {
        if hours >= 1 {
            return String(format: "%.1fh", hours)
        } else {
            let mins = Int(hours * 60)
            return "\(mins)m"
        }
    }

    /// Delta view — shows "+2.1h" or "-0.5h" vs last week
    @ViewBuilder
    private func deltaView(delta: Double) -> some View {
        if delta == 0 {
            Text("Same as last week")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        } else {
            let sign = delta > 0 ? "+" : ""
            let color: Color = delta > 0 ? Theme.Colors.positive : Theme.Colors.negative
            HStack(spacing: Theme.Spacing.micro) {
                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(color)
                Text("\(sign)\(String(format: "%.1f", delta))h vs last week")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(color)
            }
        }
    }
}

/// A single metric card in the narrative strip.
/// Layout: icon + title row at top, generous spacing, then main content.
/// Uses a visible surface background — no divider, no border.
private struct NarrativeMetricCard<Content: View>: View {
    let title: String
    let iconName: String?
    @ViewBuilder let content: () -> Content

    init(title: String, iconName: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.iconName = iconName
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — icon + title, left-aligned, muted
            HStack(spacing: Theme.Spacing.xxs) {
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(Theme.Fonts.icon)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                Text(title)
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .tracking(0.8)
            }

            // Breathing room between header and content — no divider needed
            Spacer().frame(height: Theme.Spacing.sm)

            // Content — fills remaining space
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .frame(minHeight: 110)
        .background(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .fill(Theme.Colors.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Design.cornerRadius))
    }
}

// MARK: - Preview

struct OverviewDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        OverviewDashboardView(
            chartDataPreparer: ChartDataPreparer(),
            sessionManager: SessionManager.shared,
            projectsViewModel: ProjectsViewModel.shared,
            narrativeEngine: NarrativeEngine()
        )
        .frame(width: 1200, height: 1200)
        .background(Theme.Colors.background)
        .preferredColorScheme(.dark)
    }
}