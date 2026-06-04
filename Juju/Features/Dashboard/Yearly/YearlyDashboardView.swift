//
//  YearlyDashboardView.swift
//  Juju
//
//  Created by Hayden on 12/12/2025.
//

import SwiftUI
import Charts

/// Yearly Dashboard View — a vertical scrolling page within the horizontal
/// paging container in DashboardRootView.
///
/// Charts float freely at their natural height with consistent horizontal margins.
/// No card backgrounds — visual separation comes from spacing and typography.
/// The optional ActiveSessionStatusView pushes everything down when a session is live.
///
/// Design Philosophy (Scandinavian-Japanese Minimal):
/// - Consistent padding with overview dashboard
/// - Charts breathe with generous whitespace
/// - No redundant nesting — charts flow naturally in a LazyVStack
struct YearlyDashboardView: View {
    // MARK: - State objects (passed from DashboardRootView)
    @ObservedObject var chartDataPreparer: ChartDataPreparer
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var projectsViewModel: ProjectsViewModel
    @ObservedObject var narrativeEngine: NarrativeEngine
    
    // MARK: - Ideal heights
    private let monthlyChartMinHeight: CGFloat = 520
    private let projectChartMinHeight: CGFloat = 380
    private let activityChartMinHeight: CGFloat = 340
    
    // MARK: - Date Intervals
    private var currentYearInterval: DateInterval {
        let today = Date()
        guard let year = Calendar.current.dateInterval(of: .year, for: today) else {
            return DateInterval(start: today, end: today)
        }
        return year
    }
    
    // MARK: - Component Views
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: Theme.DashboardLayout.chartGap) {
                // Active Session Bar (appears at top when session is live,
                // naturally pushes all content down)
                if sessionManager.activeSession != nil {
                    ActiveSessionStatusView(sessionManager: sessionManager)
                }
                
                // Monthly Activity Type Grouped Bar Chart — full-height left column equivalent
                MonthlyActivityTypeGroupedBarChartView(
                    data: chartDataPreparer.monthlyActivityTypeTotals()
                )
                .frame(minHeight: monthlyChartMinHeight)
                .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                
                // Project Distribution Chart
                YearlyProjectBarChartView(
                    data: chartDataPreparer.yearlyProjectTotals()
                )
                .frame(minHeight: projectChartMinHeight)
                .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                
                // Activity Types Distribution Chart
                YearlyActivityTypeBarChartView(
                    data: chartDataPreparer.yearlyActivityTypeTotals()
                )
                .frame(minHeight: activityChartMinHeight)
                .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
            }
            .padding(.vertical, Theme.DashboardLayout.dashboardPadding)
        }
        .background(Theme.Colors.background)
        .onAppear {
            loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionDidStart)) { _ in
            Task {
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
            Task {
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
            Task {
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onChange(of: sessionManager.allSessions.count) { _ in
            Task {
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