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
            // Update chart data when session starts
            Task {
                // Filter sessions for the current year from the already loaded allSessions
                let yearlySessions = sessionManager.allSessions.filter { session in
                    currentYearInterval.contains(session.startDate)
                }
                chartDataPreparer.prepareAllTimeData(
                    sessions: yearlySessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { _ in
            // Update chart data when session ends
            Task {
                // Filter sessions for the current year from the already loaded allSessions
                let yearlySessions = sessionManager.allSessions.filter { session in
                    currentYearInterval.contains(session.startDate)
                }
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
                // Filter sessions for the current year from the already loaded allSessions
                let yearlySessions = sessionManager.allSessions.filter { session in
                    currentYearInterval.contains(session.startDate)
                }
                chartDataPreparer.prepareAllTimeData(
                    sessions: yearlySessions,
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
            
            // Rely on the fact that DashboardRootView has already called
            // sessionManager.loadAllSessions() to populate allSessions.
            // We now filter from this complete dataset.
            
            // Filter sessions for the current year from the already loaded allSessions
            let yearlySessions = sessionManager.allSessions.filter { session in
                currentYearInterval.contains(session.startDate)
            }
            
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
