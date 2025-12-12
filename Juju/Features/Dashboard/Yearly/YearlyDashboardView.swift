// YearlyDashboardView.swift
// Juju
//
// Created by Hayden on 12/12/2025.
//

import SwiftUI
import Charts

/// Yearly Dashboard View
/// Dedicated view for all yearly charts and metrics
/// Now fully implemented with all yearly charts moved from WeeklyDashboardView
struct YearlyDashboardView: View {
    // MARK: - State objects
    @StateObject private var chartDataPreparer = ChartDataPreparer()
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var projectsViewModel = ProjectsViewModel.shared
    @StateObject private var editorialEngine = EditorialEngine()
    
    // MARK: - Loading state
    @State private var isLoading = false
    
    // MARK: - Component Views
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
                // Floating navigation button (always visible in center-right, same position as weekly, even closer to edge)
                Button(action: {
                    NotificationCenter.default.post(name: .switchToWeeklyView, object: nil)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.navigation) // Use shared NavigationButtonStyle
                .help("Back to Weekly Dashboard")
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
                                    Text("Loading yearly dashboard...")
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
                    
                    // Load all sessions for yearly dashboard charts
                    await MainActor.run {
                        Task {
                            await sessionManager.loadAllSessions()
                        }
                    }
                    
                    // Prepare YEARLY data for initial display
                    chartDataPreparer.prepareYearlyData(
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
                        chartDataPreparer.prepareYearlyData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
                    }
                }
            }
            // Event-driven reload when session ends
            .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { _ in
                Task {
                    await MainActor.run {
                        Task {
                            await sessionManager.loadRecentSessions(limit: 40)
                        }
                        chartDataPreparer.prepareYearlyData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .projectsDidChange)) { _ in
                Task {
                    await MainActor.run {
                        chartDataPreparer.prepareYearlyData(
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
                        chartDataPreparer.prepareYearlyData(
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
                        chartDataPreparer.prepareYearlyData(
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

#Preview {
    YearlyDashboardView()
}
