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
                        bottomHeightRatio: 0.65
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
    
    var body: some View {
        GeometryReader { geometry in
            if let headline = narrativeEngine.currentHeadline {
                let colWidth = (geometry.size.width - Theme.Spacing.xs * 2) / 3
                
                HStack(spacing: Theme.Spacing.xs) {
                    // Column 1: Total Duration
                    CenteredNarrativeColumn(
                        label: "THIS WEEK",
                        value: headline.formattedHours,
                        valueColor: Theme.Colors.accentColor,
                        width: colWidth
                    )
                    
                    // Column 2: Focus Activity
                    CenteredNarrativeColumn(
                        label: "FOCUS",
                        value: "\(headline.topActivity.emoji) \(headline.topActivity.name)",
                        valueColor: Theme.Colors.accentColor,
                        width: colWidth
                    )
                    
                    // Column 3: Top Project (with milestone)
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
                        
                        if !narrativeEngine.currentWeekMilestones.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.Colors.accentColor)
                                Text("\(narrativeEngine.currentWeekMilestones.count) milestone\(narrativeEngine.currentWeekMilestones.count == 1 ? "" : "s")")
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.accentColor)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.Colors.accentColor.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        Spacer()
                    }
                    .frame(width: colWidth)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}

/// A single centered column — label in secondary text, value in a large bold display color
private struct CenteredNarrativeColumn: View {
    let label: String
    let value: String
    let valueColor: Color
    let width: CGFloat
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Spacer()
            
            Text(label)
                .font(Theme.Fonts.caption.weight(.semibold))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(1.0)
            
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(valueColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(width: width)
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