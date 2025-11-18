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

struct DashboardNativeSwiftChartsView: View {
    // MARK: - State objects
    @StateObject private var chartDataPreparer = ChartDataPreparer()
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var projectsViewModel = ProjectsViewModel.shared
    
    // MARK: - Loading state
    @State private var isLoading = false
    
    // MARK: - Component Views
    private var heroSection: some View {
        HeroSectionView(
            chartDataPreparer: chartDataPreparer,
            totalHours: chartDataPreparer.weeklyTotalHours()
        )
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
        ScrollView {
            VStack(spacing: 32) {
                // Hero Section
                heroSection
                
                // This Year Section
                thisYearSection
                
                // Weekly Stacked Bar Chart
                weeklyStackedBarChart
                
                // Stacked Area Chart
                stackedAreaChart
            }
            .padding(.vertical, Theme.spacingLarge)
            .padding(.horizontal, 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.background)
            .cornerRadius(Theme.Design.cornerRadius)
        }
        .padding(.top, 20)
        .padding(.trailing, 20)
        .background(Theme.Colors.background)
        
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
                
                // Load only recent sessions first for faster initial display (FIX: Lazy loading)
                await MainActor.run {
                    sessionManager.loadRecentSessions(limit: 40)
                }
                
                // Prepare minimal data for initial display
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
                
                isLoading = false
                
                // Load full dataset in background (FIX: Background loading)
                Task.detached {
                    let allSessions = await SessionManager.shared.loadAllSessions()
                    await MainActor.run {
                        SessionManager.shared.allSessions = allSessions
                        chartDataPreparer.prepareAllTimeData(
                            sessions: allSessions,
                            projects: projectsViewModel.projects
                        )
                    }
                }
            }
        }
        // Event-driven reload when session ends (FIX: Remove artificial delay)
        .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { _ in
            Task {
                await MainActor.run {
                    sessionManager.loadRecentSessions(limit: 40)
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

struct DashboardNativeSwiftChartsView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardNativeSwiftChartsView()
            .frame(width: 1200, height: 1200)
            .preferredColorScheme(.dark)
    }
}
