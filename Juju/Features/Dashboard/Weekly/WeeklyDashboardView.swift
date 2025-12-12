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
    // MARK: - State objects
    @StateObject private var chartDataPreparer = ChartDataPreparer()
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var projectsViewModel = ProjectsViewModel.shared
    @StateObject private var editorialEngine = EditorialEngine()
    
    // MARK: - Loading state
    @State private var isLoading = false
    
    // MARK: - Component Views
    private var heroSection: some View {
        VStack(spacing: 32) {
            // Top Row: Active Session Status (only show if active session)
            if sessionManager.activeSession != nil {
                ActiveSessionStatusView(sessionManager: sessionManager)
                    .frame(maxWidth: .infinity)
            }
            
            // Hero Section (full width when no active session, or below active session)
            HeroSectionView(
                chartDataPreparer: chartDataPreparer,
                editorialEngine: editorialEngine
            )
            .frame(maxWidth: .infinity)
            
            // Continue with existing sections...
        }
    }
    
    private var thisYearSection: some View {
        VStack(spacing: Theme.spacingMedium) {
            // Header for the container
            Text("This Year")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
            
            GeometryReader { geo in
                HStack(spacing: Theme.spacingMedium) {
                    YearlyTotalBarChartView(
                        data: chartDataPreparer.yearlyProjectTotals()
                    )
                    .layoutPriority(3)
                    .frame(maxHeight: .infinity, alignment: .center)

                    VStack(alignment: .center, spacing: Theme.spacingMedium) {
                        SummaryMetricView(
                            title: "Total Hours",
                            value: String(format: "%.1f h", chartDataPreparer.yearlyTotalHours())
                        )
                        SummaryMetricView(
                            title: "Total Sessions",
                            value: "\(chartDataPreparer.yearlyTotalSessions())"
                        )
                        SummaryMetricView(
                            title: "Average Duration",
                            value: chartDataPreparer.yearlyAvgDurationString()
                        )
                        
                    }
                    .frame(width: 400)
                    .layoutPriority(1)
                    .frame(maxHeight: .infinity, alignment: .center)
                }
            }
            .frame(height: calculateThisYearSectionHeight())
        }
        .padding(Theme.spacingLarge)
        .background(
            Theme.Colors.surface.opacity(0.5)
        )
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
    }
    
    /// Calculate dynamic height for the "This Year" section based on number of projects
    private func calculateThisYearSectionHeight() -> CGFloat {
        let data = chartDataPreparer.yearlyProjectTotals()
        
        if data.isEmpty {
            // If no data, use minimum height
            return 300
        }
        
        // Calculate height needed for each project row
        let projectCount = data.count
        let barHeight: CGFloat = Theme.Design.cornerRadius + 2  // Height of each bar
        let rowSpacing: CGFloat = Theme.spacingMedium  // Spacing between rows
        let chartPadding: CGFloat = Theme.spacingMedium * 2  // Top and bottom padding in chart
        
        // Calculate total height needed for the chart
        let chartHeight = CGFloat(projectCount) * (barHeight + rowSpacing) + chartPadding
        
        // Calculate height needed for summary metrics (3 metrics with spacing)
        let summaryMetricHeight: CGFloat = 3 * 60 + (2 * Theme.spacingMedium)  // Approximate height per metric + spacing
        
        // Return the maximum of chart height and summary metrics height, with a minimum
        let minHeight: CGFloat = 300
        let maxHeight: CGFloat = 800  // Maximum reasonable height to prevent excessive stretching
        
        return max(minHeight, min(maxHeight, max(chartHeight, summaryMetricHeight)))
    }
    
    private var weeklyStackedBarChart: some View {
        GeometryReader { geo in
            WeeklyStackedBarChartView(
                data: chartDataPreparer.weeklyStackedBarChartData()
            )
        }
        .frame(height: 300)
        .padding(Theme.spacingMedium)
        .background(Theme.Colors.surface.opacity(0.5))
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
    }
    
    private var stackedAreaChart: some View {
        StackedAreaChartCardView(
            data: chartDataPreparer.monthlyProjectTotals()
        )
    }

    // MARK - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Floating navigation button (always visible in center-right, even closer to edge)
                NavigationButton()
                    .position(x: geometry.size.width - 16, y: geometry.size.height / 2)
                    .zIndex(2)
                
                // Main content
                VStack(spacing: 0) {
                    // Sticky Active Session Bar (always visible at top)
                    if sessionManager.activeSession != nil {
                        ActiveSessionStatusView(sessionManager: sessionManager)
                            .padding(.horizontal, Theme.spacingLarge)
                            .padding(.top, Theme.spacingLarge)
                            .padding(.bottom, Theme.spacingSmall)
                            .background(Theme.Colors.background)
                            .zIndex(1) // Ensure it stays above content
                    }
                    
                    // Scrollable content below
                    ScrollView {
                        VStack(spacing: 32) {
                            // Hero Section (no longer includes active session)
                            HeroSectionView(
                                chartDataPreparer: chartDataPreparer,
                                editorialEngine: editorialEngine
                            )
                            .frame(maxWidth: .infinity)
                            
                            // This Year Section
                            thisYearSection
                            
                            // Weekly Stacked Bar Chart
                            weeklyStackedBarChart
                            
                            // Stacked Area Chart
                            stackedAreaChart
                        }
                        .padding(.vertical, Theme.spacingLarge)
                        .padding(.horizontal, Theme.spacingLarge)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.background)
                        .cornerRadius(Theme.Design.cornerRadius)
                    }
                }
                .padding(.top, 20)
                .padding(.trailing, 20)
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
                    
                    // Load all sessions from current year for dashboard charts
                    await MainActor.run {
                        Task {
                            await sessionManager.loadAllSessions()
                        }
                    }
                    
                    // Prepare data for initial display
                    chartDataPreparer.prepareAllTimeData(
                        sessions: sessionManager.allSessions,
                        projects: projectsViewModel.projects
                    )
                    
                    isLoading = false
                }
            }
            // Event-driven reload when session starts
            .onReceive(NotificationCenter.default.publisher(for: .sessionDidStart)) { _ in
                Task {
                    await MainActor.run {
                        chartDataPreparer.prepareAllTimeData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
                    }
                }
            }
            // Event-driven reload when session ends (FIX: Remove artificial delay)
            .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { _ in
                Task {
                    await MainActor.run {
                        Task {
                            await sessionManager.loadRecentSessions(limit: 40)
                        }
                        chartDataPreparer.prepareAllTimeData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .projectsDidChange)) { _ in
                Task {
                    await MainActor.run {
                        chartDataPreparer.prepareAllTimeData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
                    }
                }
            }
            .onChange(of: sessionManager.allSessions.count) { _ in
                // Only prepare data if not loading to prevent conflicts
                guard !isLoading else { return }
                Task {
                    await MainActor.run {
                        chartDataPreparer.prepareAllTimeData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
                    }
                }
            }
            .onChange(of: projectsViewModel.projects.count) { _ in
                // Only prepare data if not loading to prevent conflicts
                guard !isLoading else { return }
                Task {
                    await MainActor.run {
                        chartDataPreparer.prepareAllTimeData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
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
        WeeklyDashboardView()
            .frame(width: 1200, height: 1200)
            .preferredColorScheme(.dark)
    }
}
