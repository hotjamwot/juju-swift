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

struct OverviewDashboardView: View {
    // MARK: - State objects (passed from DashboardRootView)
    @ObservedObject var chartDataPreparer: ChartDataPreparer
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var projectsViewModel: ProjectsViewModel
    @ObservedObject var narrativeEngine: NarrativeEngine
    
    // MARK: - Loading state
    @State private var isLoading = false
    
    // MARK - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    // Active Session Bar (always visible at top)
                    if sessionManager.activeSession != nil {
                        ActiveSessionStatusView(sessionManager: sessionManager)
                            .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                            .padding(.top, Theme.DashboardLayout.dashboardPadding)
                            .padding(.bottom, Theme.DashboardLayout.chartPadding)
                    }
                    
                    // ── Dashboard charts ──
                    DashboardLayout.weekly(
                        topLeft: {
                            SessionHeatMapView(
                                dailyTotals: chartDataPreparer.dailyTotalsForLast(days: 35, sessions: sessionManager.allSessions),
                                dayCount: 35
                            )
                        },
                        topRight: {
                            NarrativeSummaryCard(narrativeEngine: narrativeEngine)
                        },
                        bottom: {
                            SessionCalendarChartView(
                                sessions: chartDataPreparer.currentWeekSessionsForCalendar()
                            )
                        },
                        topHeightRatio: 0.35,
                        bottomHeightRatio: 0.65,
                        topLeftWidthRatio: 0.42,
                        gap: 14
                    )
                    .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                    .padding(.bottom, Theme.DashboardLayout.dashboardPadding + 32)
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
                        
                        chartDataPreparer.prepareWeeklyData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
                        
                        narrativeEngine.generateWeeklyHeadline()
                        
                        isLoading = false
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .sessionDidStart)) { _ in
                    Task {
                        chartDataPreparer.prepareWeeklyData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
                        narrativeEngine.generateWeeklyHeadline()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { _ in
                    Task {
                        chartDataPreparer.prepareWeeklyData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
                        narrativeEngine.generateWeeklyHeadline()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .projectsDidChange)) { _ in
                    Task {
                        await MainActor.run {
                            chartDataPreparer.prepareWeeklyData(
                                sessions: sessionManager.allSessions,
                                projects: projectsViewModel.projects
                            )
                            narrativeEngine.generateWeeklyHeadline()
                        }
                    }
                }
                .onChange(of: sessionManager.allSessions.count) { _ in
                    guard !isLoading else { return }
                    Task {
                        await MainActor.run {
                            chartDataPreparer.prepareWeeklyData(
                                sessions: sessionManager.allSessions,
                                projects: projectsViewModel.projects
                            )
                            narrativeEngine.generateWeeklyHeadline()
                        }
                    }
                }
                .onChange(of: projectsViewModel.projects.count) { _ in
                    guard !isLoading else { return }
                    Task {
                        await MainActor.run {
                            chartDataPreparer.prepareWeeklyData(
                                sessions: sessionManager.allSessions,
                                projects: projectsViewModel.projects
                            )
                            narrativeEngine.generateWeeklyHeadline()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 3-Column Narrative Summary Card

/// Displays THIS WEEK | FOCUS | PROJECT in three centered columns.
/// No vertical dividers — clean white space separates them.
/// Values use the accent color except project which uses its own project color.
private struct NarrativeSummaryCard: View {
    @ObservedObject var narrativeEngine: NarrativeEngine

    /// The most recent milestone from all sessions
    private var lastMilestone: Milestone? {
        narrativeEngine.mostRecentMilestone
    }

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
        current > previous ? Color.green : (current < previous ? Color.red.opacity(0.8) : Theme.Colors.textSecondary)
    }

    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    var body: some View {
        GeometryReader { geometry in
            if let headline = narrativeEngine.currentHeadline {
                VStack(spacing: Theme.Spacing.sm) {
                    let colWidth = (geometry.size.width - Theme.Spacing.xs * 2) / 3

                    HStack(spacing: Theme.Spacing.xs) {
                        // Column 1: Total Duration + Comparison
                        VStack(spacing: Theme.Spacing.xxs) {
                            Spacer()

                            Text("THIS WEEK")
                                .font(Theme.Fonts.caption.weight(.semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .tracking(1.0)

                            Text(headline.formattedHours)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.accentColor)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            if let comparative = comparativeData {
                                VStack(spacing: 3) {
                                    Text("Last week: \(formatHours(comparative.previous.totalHours))")                                        .font(Theme.Fonts.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                    Text(deltaText(current: comparative.current.totalHours, previous: comparative.previous.totalHours))
                                        .font(Theme.Fonts.caption.weight(.bold))
                                        .foregroundColor(deltaColor(current: comparative.current.totalHours, previous: comparative.previous.totalHours))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Theme.Colors.cardSurface.opacity(0.5))
                                .cornerRadius(6)
                            }

                            Spacer()
                        }
                        .frame(width: colWidth)

                        // Column 2: Focus Activity
                        VStack(spacing: Theme.Spacing.xxs) {
                            Spacer()

                            Text("FOCUS")
                                .font(Theme.Fonts.caption.weight(.semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .tracking(1.0)

                            Text("\(headline.topActivity.emoji) \(headline.topActivity.name)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.accentColor)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            Spacer()
                        }
                        .frame(width: colWidth)

                        // Column 3: Top Project
                        VStack(spacing: Theme.Spacing.xxs) {
                            Spacer()

                            Text("PROJECT")
                                .font(Theme.Fonts.caption.weight(.semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .tracking(1.0)

                            Text(headline.topProject.emoji)
                                .font(.system(size: 32))

                            Text(headline.topProject.name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineLimit(1)

                            Spacer()
                        }
                        .frame(width: colWidth)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Last Milestone detail section at the bottom
                    if let milestone = lastMilestone {
                        lastMilestoneView(milestone: milestone)
                    }
                }
            } else {
                VStack(spacing: Theme.Spacing.xs) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading your story...")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Displays the most recent milestone with project on left and details on right
    @ViewBuilder
    private func lastMilestoneView(milestone: Milestone) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            // Left: Project emoji and name
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.projectEmoji)
                    .font(.system(size: 16))
                Text(milestone.projectName)
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .frame(width: 50, alignment: .leading)

            // Right: Milestone details
            VStack(alignment: .leading, spacing: 3) {
                Text("Last Milestone")
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .tracking(0.5)

                Text(milestone.text)
                    .font(Theme.Fonts.body.weight(.medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(milestone.date.formatted(date: .abbreviated, time: .omitted))
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.DashboardLayout.chartPadding)
        .padding(.vertical, 10)
        .background(Theme.Colors.cardSurface.opacity(0.6))
        .cornerRadius(Theme.Design.cornerRadius)
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
    }
}