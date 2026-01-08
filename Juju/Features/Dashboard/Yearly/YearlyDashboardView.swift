// YearlyDashboardView.swift
// Juju
//
// Created by Hayden on 12/12/2025.
//

import SwiftUI
import Charts

/// Yearly Dashboard View
/// Dedicated view for all yearly charts and metrics
struct YearlyDashboardView: View {
    // MARK: - State objects (passed from DashboardRootView)
    @ObservedObject var chartDataPreparer: ChartDataPreparer
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var projectsViewModel: ProjectsViewModel
    @ObservedObject var narrativeEngine: NarrativeEngine
    
    
    // MARK: - Date Intervals
    private var currentYearInterval: DateInterval {
        let today = Date()
        guard let year = Calendar.current.dateInterval(of: .year, for: today) else {
            return DateInterval(start: today, end: today)
        }
        return year
    }
    
    // MARK: - Component Views    
    // MARK - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content background
                Theme.Colors.background
                
                // Main content
                VStack(spacing: 0) {
                    // Active Session Bar (always visible at top)
                    if sessionManager.activeSession != nil {
                        ActiveSessionStatusView(sessionManager: sessionManager)
                            .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                            .padding(.top, Theme.DashboardLayout.dashboardPadding)
                            .padding(.bottom, Theme.DashboardLayout.chartPadding) // Reduced padding
                    }
                    
                    // Dashboard charts using optimized two-column layout
                    DashboardLayout.yearly(
                        left: {
                            // Monthly Activity Type Grouped Bar Chart
                            MonthlyActivityTypeGroupedBarChartView(
                                data: chartDataPreparer.monthlyActivityTypeTotals()
                            )
                        },
                        rightTop: {
                            // Project Distribution Chart
                            YearlyProjectBarChartView(
                                data: chartDataPreparer.yearlyProjectTotals()
                            )
                        },
                        rightBottom: {
                            // Activity Types Distribution Chart
                            YearlyActivityTypeBarChartView(
                                data: chartDataPreparer.yearlyActivityTypeTotals()
                            )
                        }
                    )
                    .frame(maxHeight: sessionManager.activeSession != nil ? .infinity : nil) // Add responsive height when active session is present
                }
                .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                .padding(.bottom, Theme.DashboardLayout.dashboardPadding)
                .background(Theme.Colors.background)
            }
        }
        .onAppear {
            loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionDidStart)) { _ in
            // Update chart data when session starts - use optimized yearly loading
            Task {
                let yearInterval = Calendar.current.dateInterval(of: .year, for: Date()) ?? DateInterval(start: Date(), end: Date())
                let yearlySessions = await sessionManager.loadSessions(in: yearInterval)
                
                chartDataPreparer.prepareAllTimeData(
                    sessions: yearlySessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { _ in
            // Update chart data when session ends - use optimized yearly loading
            Task {
                let yearInterval = Calendar.current.dateInterval(of: .year, for: Date()) ?? DateInterval(start: Date(), end: Date())
                let yearlySessions = await sessionManager.loadSessions(in: yearInterval)
                
                chartDataPreparer.prepareAllTimeData(
                    sessions: yearlySessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .projectsDidChange)) { _ in
            // Update chart data when projects change
            Task {
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onChange(of: sessionManager.allSessions.count) { _ in
            // Update chart data when session data changes
            Task {
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onChange(of: projectsViewModel.projects.count) { _ in
            // Update chart data when project data changes
            Task {
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
    }

    // MARK: - Data Loading
    private func loadData() {
        Task {
            await projectsViewModel.loadProjects()
            
            // Use optimized query-based loading for yearly sessions only
            let yearInterval = Calendar.current.dateInterval(of: .year, for: Date()) ?? DateInterval(start: Date(), end: Date())
            let yearlySessions = await sessionManager.loadSessions(in: yearInterval)
            
            chartDataPreparer.prepareAllTimeData(
                sessions: yearlySessions,
                projects: projectsViewModel.projects
            )
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

// MARK: - Back Navigation Button Component

/// Floating navigation button for navigating back to weekly dashboard
/// This button is embedded directly in YearlyDashboardView for better encapsulation
struct BackNavigationButton: View {
    var body: some View {
        Button(action: {
            // Navigate back to weekly dashboard
            NotificationCenter.default.post(name: .switchToWeeklyView, object: nil)
        }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
        }
        .buttonStyle(.navigation) // Use shared NavigationButtonStyle
        .help("Back to Weekly Dashboard")
    }
}

#Preview {
    YearlyDashboardView(
        chartDataPreparer: ChartDataPreparer(),
        sessionManager: SessionManager.shared,
        projectsViewModel: ProjectsViewModel.shared,
        narrativeEngine: NarrativeEngine()
    )
    .environmentObject(SidebarStateManager())
    .frame(width: 1200, height: 700) // Dashboard preview size
    .background(Theme.Colors.background)
}
