import SwiftUI
import Charts

// 1️⃣  Extension moved out of the struct
extension Date {
    var isInCurrentYear: Bool {
        let cal = Calendar.current
        return cal.component(.year, from: self) ==
               cal.component(.year, from: Date())
    }
}

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
                // Main content with tidy, balanced layout
                VStack(spacing: 0) {
                    // Active Session Bar (always visible at top)
                    if sessionManager.activeSession != nil {
                        ActiveSessionStatusView(sessionManager: sessionManager)
                            .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                            .padding(.top, Theme.DashboardLayout.dashboardPadding)
                            .padding(.bottom, Theme.DashboardLayout.chartPadding)
                    }
                    
                    // Narrative Strip — compact horizontal bar
                    WeeklyEditorialView(narrativeEngine: narrativeEngine)
                        .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                        .padding(.bottom, Theme.DashboardLayout.chartGap)
                    
                    // Dashboard charts using optimized layout
                    DashboardLayout.weekly(
                        topLeft: {
                            VStack {
                                Spacer()
                                Text("Coming Soon")
                                    .font(.headline)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Text("Heat map view")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        },
                        topRight: {
                            VStack {
                                Spacer()
                                Text("Coming Soon")
                                    .font(.headline)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Text("Project distribution")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        },
                        bottom: {
                            SessionCalendarChartView(
                                sessions: chartDataPreparer.currentWeekSessionsForCalendar()
                            )
                        },
                        topHeightRatio: 0.4,
                        bottomHeightRatio: 0.6
                    )
                }
                .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                .padding(.bottom, Theme.DashboardLayout.dashboardPadding + 32) 
                .background(Theme.Colors.background)
            }
            
            // Loading overlay
            .overlay(
                Group {
                    if isLoading {
                        Rectangle()
                            .fill(Theme.Colors.background.opacity(0.8))
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
                    
                    // Rely on the fact that DashboardRootView has already called
                    // sessionManager.loadAllSessions() to populate allSessions.
                    // We now filter from this complete dataset.
                    
                    // Filter sessions for the current week from the already loaded allSessions
                    // The ChartDataPreparer's currentWeekInterval is used internally for this filtering.
                    chartDataPreparer.prepareWeeklyData(
                        sessions: sessionManager.allSessions, // Pass all sessions
                        projects: projectsViewModel.projects
                    )
                    
                    // Generate initial editorial headline
                    narrativeEngine.generateWeeklyHeadline()
                    
                    isLoading = false
                }
            }
            // Event-driven reload when session starts
            .onReceive(NotificationCenter.default.publisher(for: .sessionDidStart)) { _ in
                Task {
                    chartDataPreparer.prepareWeeklyData(
                        sessions: sessionManager.allSessions, // Pass all sessions
                        projects: projectsViewModel.projects
                    )
                    narrativeEngine.generateWeeklyHeadline()
                }
            }
            // Event-driven reload when session ends
            .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { _ in
                Task {
                    chartDataPreparer.prepareWeeklyData(
                        sessions: sessionManager.allSessions, // Pass all sessions
                        projects: projectsViewModel.projects
                    )
                    narrativeEngine.generateWeeklyHeadline()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .projectsDidChange)) { _ in
                Task {
                    await MainActor.run {
                        chartDataPreparer.prepareWeeklyData(
                            sessions: sessionManager.allSessions, // Pass all sessions
                            projects: projectsViewModel.projects
                        )
                        narrativeEngine.generateWeeklyHeadline()
                    }
                }
            }
            .onChange(of: sessionManager.allSessions.count) { _ in
                // Only prepare data if not loading to prevent conflicts
                guard !isLoading else { return }
                Task {
                    await MainActor.run {
                        chartDataPreparer.prepareWeeklyData(
                            sessions: sessionManager.allSessions, // Pass all sessions
                            projects: projectsViewModel.projects
                        )
                        narrativeEngine.generateWeeklyHeadline()
                    }
                }
            }
            .onChange(of: projectsViewModel.projects.count) { _ in
                // Only prepare data if not loading to prevent conflicts
                guard !isLoading else { return }
                Task {
                    await MainActor.run {
                        chartDataPreparer.prepareWeeklyData(
                            sessions: sessionManager.allSessions, // Pass all sessions
                            projects: projectsViewModel.projects
                        )
                        narrativeEngine.generateWeeklyHeadline()
                    }
                }
            }
        }
    }

    // MARK: - Components
    struct NoDataPlaceholder: View {
        var minHeight: CGFloat = 200
        var body: some View {
            Text("No data available")
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(Theme.Colors.background.opacity(0.2))
                .cornerRadius(Theme.Design.cornerRadius)
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
    }
}