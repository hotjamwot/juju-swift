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
    // MARK: - State objects
    @StateObject private var chartDataPreparer = ChartDataPreparer()
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var projectsViewModel = ProjectsViewModel.shared
    @StateObject private var editorialEngine = EditorialEngine()
    
    // MARK: - Loading state (removed - not needed for yearly dashboard)
    
    // MARK: - Date Intervals
    private var currentYearInterval: DateInterval {
        let today = Date()
        guard let year = Calendar.current.dateInterval(of: .year, for: today) else {
            return DateInterval(start: today, end: today)
        }
        return year
    }
    
    // MARK: - Component Views
    private var projectTotalsChart: some View {
        YearlyTotalBarChartView(
            data: chartDataPreparer.yearlyProjectTotals()
        )
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
    
    private var activityDistributionChart: some View {
        YearlyActivityPieChartView(
            data: chartDataPreparer.yearlyActivityTotals()
        )
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
    
    
    private var stackedAreaChart: some View {
        StackedAreaChartCardView(
            data: chartDataPreparer.weeklyProjectTotalsForStackedArea()
        )
    }

    // MARK - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content background
                Theme.Colors.background
                
                // Main content
                VStack(spacing: 0) {
                    // Sticky Active Session Bar (always visible at top)
                    if sessionManager.activeSession != nil {
                        ActiveSessionStatusView(sessionManager: sessionManager)
                            .padding(.horizontal, Theme.spacingLarge)
                            .padding(.top, Theme.spacingLarge)
                            .padding(.bottom, Theme.spacingSmall)
                            .background(Theme.Colors.background)
                            .zIndex(1)
                    }
                    
                    // Non-scrolling content
                    VStack(spacing: 32) {
                        // Top Row: Project Totals and Activity Distribution
                        HStack(spacing: Theme.spacingLarge) {
                            projectTotalsChart
                                .layoutPriority(2)
                                .frame(maxHeight: .infinity)
                            
                            activityDistributionChart
                                .layoutPriority(1)
                                .frame(maxHeight: .infinity)
                        }
                        
                        // Stacked Area Chart
                        stackedAreaChart
                    }
                    .padding(.vertical, Theme.spacingLarge)
                    .padding(.horizontal, Theme.spacingLarge)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.Design.cornerRadius)
                }
                .padding(.top, 20)
                .padding(.trailing, 20)
                .background(Theme.Colors.background)
                
                // Floating navigation button (back to weekly dashboard)
                BackNavigationButton()
                    .position(x: 16, y: geometry.size.height / 2)
                    .zIndex(2)
                
            }
        }
        .onAppear {
            loadData()
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { _ in
            Task {
                let allSessions = await sessionManager.loadAllSessions()
                await MainActor.run {
                    chartDataPreparer.prepareYearlyData(
                        sessions: allSessions,
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

    // MARK: - Data Loading
    private func loadData() {
        Task {
            await loadProjectsAndSessions()
        }
    }
    
    private func loadProjectsAndSessions() async {
        await projectsViewModel.loadProjects()
        
        // Load only current year sessions for yearly dashboard (more efficient)
        let currentYearSessions = await sessionManager.loadSessions(in: currentYearInterval)
        
        await prepareYearlyData(sessions: currentYearSessions)
    }
    
    private func prepareYearlyData(sessions: [SessionRecord]) async {
        await MainActor.run {
            chartDataPreparer.prepareYearlyData(
                sessions: sessions,
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
    YearlyDashboardView()
}
