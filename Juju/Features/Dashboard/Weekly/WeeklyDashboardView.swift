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

struct WeeklyDashboardView: View {
    // MARK: - State objects (passed from DashboardRootView)
    @ObservedObject var chartDataPreparer: ChartDataPreparer
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var projectsViewModel: ProjectsViewModel
    @ObservedObject var narrativeEngine: NarrativeEngine
    
    // MARK: - Loading state
    @State private var isLoading = false
    
    // MARK: - Responsive layout helpers
    // Note: Removed old layout helper functions since we're using the new grid system
    
    // MARK: - Component Views
    // Note: Removed thisYearSection, weeklyStackedBarChart, and stackedAreaChart
    // These are now moved to YearlyDashboardView for better separation of concerns

    // MARK - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Floating navigation button (always visible in center-right, even closer to edge)
                // NavigationButton()
                //     .position(x: geometry.size.width - 26, y: geometry.size.height / 2)
                //     .zIndex(2)
                
                // Main content with tidy, balanced layout
                VStack(spacing: 0) {
                    // Active Session Bar (always visible at top)
                    if sessionManager.activeSession != nil {
                        ActiveSessionStatusView(sessionManager: sessionManager)
                            .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                            .padding(.top, Theme.DashboardLayout.dashboardPadding)
                            .padding(.bottom, Theme.DashboardLayout.chartPadding) // Reduced padding
                    }
                    
                    // Dashboard charts using optimized layout
                    DashboardLayout.weekly(
                        topLeft: {
                            WeeklyEditorialView(
                                narrativeEngine: narrativeEngine
                            )
                        },
                        topRight: {
                            WeeklyActivityBubbleChartView(
                                data: chartDataPreparer.weeklyActivityTotals()
                            )
                        },
                        bottom: {
                            SessionCalendarChartView(
                                sessions: chartDataPreparer.currentWeekSessionsForCalendar()
                            )
                        },
                        topHeightRatio: 0.45,  // More space for editorial content
                        bottomHeightRatio: 0.55
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
                    
                    // Use optimized query-based loading for weekly sessions only
                    let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), end: Date())
                    let weeklySessions = await sessionManager.loadSessions(in: weekInterval)
                    
                    // Prepare WEEKLY data for initial display (optimized for performance)
                    chartDataPreparer.prepareWeeklyData(
                        sessions: weeklySessions,
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
                    // Use optimized query-based loading for weekly sessions
                    let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), end: Date())
                    let weeklySessions = await sessionManager.loadSessions(in: weekInterval)
                    
                    chartDataPreparer.prepareWeeklyData(
                        sessions: weeklySessions,
                        projects: projectsViewModel.projects
                    )
                    narrativeEngine.generateWeeklyHeadline()
                }
            }
            // Event-driven reload when session ends
            .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { _ in
                Task {
                    // Use optimized query-based loading for weekly sessions
                    let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), end: Date())
                    let weeklySessions = await sessionManager.loadSessions(in: weekInterval)
                    
                    chartDataPreparer.prepareWeeklyData(
                        sessions: weeklySessions,
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
                // Only prepare data if not loading to prevent conflicts
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
                // Only prepare data if not loading to prevent conflicts
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

// MARK: - Navigation Button Component

/// Floating navigation button for switching between weekly and yearly views
/// This button is embedded directly in WeeklyDashboardView for better encapsulation
struct NavigationButton: View {
    @StateObject private var sessionManager = SessionManager.shared
    
    var body: some View {
        Button(action: {
            // This will be handled by parent DashboardRootView through state management
            // For now, we'll use a notification to trigger the navigation
            NotificationCenter.default.post(name: .switchToYearlyView, object: nil)
        }) {
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
        }
        .buttonStyle(.navigation) // Use shared NavigationButtonStyle
        .help("Switch to Yearly Dashboard")
    }
}

// MARK: - Preview

struct WeeklyDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        WeeklyDashboardView(
            chartDataPreparer: ChartDataPreparer(),
            sessionManager: SessionManager.shared,
            projectsViewModel: ProjectsViewModel.shared,
            narrativeEngine: NarrativeEngine()
        )
            .frame(width: 1200, height: 1200)
    }
}
