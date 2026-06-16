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
/// Narrative metric cards use an explicit `cardSurface` background (#252526) for depth.
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
    @State private var highlightedMilestoneDate: Date? = nil
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
    
    // MARK: - Info Panel Data
    
    /// The effective day stack for the info panel.
    /// Chart hover takes priority; falls back to milestone-hover day.
    private var resolvedInfoDayStack: DayStack? {
        hoveredDay
    }
    
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
                            highlightedDate: highlightedMilestoneDate,
                            hoveredDay: $hoveredDay
                        )
                        .frame(minHeight: stackedBarMinHeight)
                        
                        // Info panel + Milestones side by side
                        milestoneInfoRow
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
    
    // MARK: - Milestone + Info Panel Row
    
    private var milestoneInfoRow: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            DaySessionInfoPanel(dayStack: resolvedInfoDayStack)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if !chartDataPreparer.current90DayMilestones.isEmpty {
                RecentMilestonesSection(
                    milestones: chartDataPreparer.current90DayMilestones,
                    highlightedMilestoneDate: $highlightedMilestoneDate,
                    onMilestoneHover: { date in
                        self.handleMilestoneHover(date)
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func handleMilestoneHover(_ date: Date?) {
        if let date = date {
            hoveredDay = chartDataPreparer.current90DayStacks.first { stack in
                Calendar.current.isDate(stack.date, inSameDayAs: date)
            }
        } else {
            hoveredDay = nil
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

/// Displays THIS WEEK | FOCUS | PROJECT as individual rounded metric cards.
/// Each card has a visible surface, an SF Symbol, and primary data below.
private struct NarrativeSummaryCard: View {
    @ObservedObject var narrativeEngine: NarrativeEngine

    /// Comparison data for the current week vs same elapsed period last week
    private var comparativeData: ComparativeAnalytics? {
        narrativeEngine.getComparativeData(for: .week)
    }

    private func deltaText(current: Double, previous: Double) -> String {
        let diff = current - previous
        let sign = diff >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", diff))h"
    }

    private func deltaColor(current: Double, previous: Double) -> Color {
        current > previous ? Theme.Colors.positive : (current < previous ? Theme.Colors.negative : Theme.Colors.textSecondary)
    }

    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    var body: some View {
        if let headline = narrativeEngine.currentHeadline {
            HStack(spacing: Theme.Spacing.sm) {
                // Card 1: Total Duration
                NarrativeMetricCard(title: "THIS WEEK", iconName: "clock.fill") {
                    VStack(spacing: Theme.Spacing.xs) {
                        Text(headline.formattedHours)
                            .font(Theme.Fonts.metricValue)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        if let comparative = comparativeData {
                            VStack(spacing: Theme.Spacing.micro) {
                                Text("vs \(formatHours(comparative.previous.totalHours)) last week")
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Text(deltaText(current: comparative.current.totalHours, previous: comparative.previous.totalHours))
                                    .font(Theme.Fonts.caption.weight(.semibold))
                                    .foregroundColor(deltaColor(current: comparative.current.totalHours, previous: comparative.previous.totalHours))
                            }
                        }
                    }
                }

                // Card 2: Focus Activity
                NarrativeMetricCard(title: "FOCUS", iconName: "target") {
                    VStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: headline.topActivity.sfSymbol)
                            .font(Theme.Fonts.iconLarge)
                            .foregroundColor(Theme.Colors.accentColor)
                        Text(headline.topActivity.name)
                            .font(Theme.Fonts.subheader)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
                    }
                }

                // Card 3: Top Project
                NarrativeMetricCard(title: "PROJECT", iconName: "folder.fill") {
                    VStack(spacing: Theme.Spacing.xs) {
                        Text(headline.topProject.emoji)
                            .font(Theme.Fonts.title)
                        Text(headline.topProject.name)
                            .font(Theme.Fonts.subheader)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
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
}

/// A single metric card in the narrative strip.
/// Layout: title + symbol at top-left, main content centred vertically and horizontally.
/// Uses a visible elevated card surface and generous vertical padding for equal height.
private struct NarrativeMetricCard<Content: View>: View {
    let title: String
    let iconName: String?
    let emoji: String?
    @ViewBuilder let content: () -> Content

    init(title: String, iconName: String? = nil, emoji: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.iconName = iconName
        self.emoji = emoji
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: title + symbol, left-aligned
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .tracking(0.8)

                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(Theme.Fonts.icon)
                        .foregroundColor(Theme.Colors.accentColor)
                } else if let emoji = emoji {
                    Text(emoji)
                        .font(Theme.Fonts.body)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)

            // Centre: main content
            Spacer(minLength: Theme.Spacing.xxs)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.md)
        }
        .frame(minHeight: 180)
        .background(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .fill(Theme.Colors.cardSurface)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Design.cornerRadius))
    }
}

// MARK: - Recent Milestones Section

/// Displays recent milestones from the 90-day period below the chart.
/// Uses the same card pattern as ProjectStoryView's NotableMomentCard.
/// Hovering a milestone turns the left pill gold and highlights the corresponding
/// day in the 90-day chart (dimming all other bars).
private struct RecentMilestonesSection: View {
    let milestones: [DashboardMilestone]
    @Binding var highlightedMilestoneDate: Date?
    var onMilestoneHover: ((Date?) -> Void)? = nil

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Recent milestones")
                .font(Theme.Fonts.narrative.weight(.semibold))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(0.5)

            VStack(spacing: Theme.Spacing.xs) {
                // Reverse so most recent is at the bottom
                ForEach(milestones.prefix(5).reversed()) { milestone in
                    milestoneRow(milestone)
                }
            }
        }
    }

    @ViewBuilder
    private func milestoneRow(_ milestone: DashboardMilestone) -> some View {
        MilestoneRowView(
            milestone: milestone,
            dateText: df.string(from: milestone.date),
            isHighlighted: highlightedMilestoneDate.map { Calendar.current.isDate($0, inSameDayAs: milestone.date) } ?? false,
            onHover: { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    if hovering {
                        highlightedMilestoneDate = milestone.date
                    } else {
                        highlightedMilestoneDate = nil
                    }
                    onMilestoneHover?(hovering ? milestone.date : nil)
                }
            }
        )
    }
}

/// A single milestone row with hover interaction — mimics NotableMomentCard from ProjectStoryView.
/// Left accent bar uses project color by default; turns gold on hover.
private struct MilestoneRowView: View {
    let milestone: DashboardMilestone
    let dateText: String
    let isHighlighted: Bool
    let onHover: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            // Left accent bar — project color or gold when highlighted
            RoundedRectangle(cornerRadius: 1)
                .fill(isHighlighted ? Theme.Colors.milestone : Color.lightenedHex(milestone.projectColor))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(milestone.projectEmoji)
                        .font(Theme.Fonts.caption)
                    Text(milestone.projectName)
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(dateText)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.65))
                }

                Text(milestone.text)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(isHighlighted ? Theme.Colors.surface.opacity(0.85) : Theme.Colors.surface.opacity(0.5))
        .cornerRadius(10)
        .onHover { hovering in
            onHover(hovering)
        }
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