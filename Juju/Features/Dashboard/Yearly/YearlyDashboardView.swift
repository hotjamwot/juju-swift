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
    @ObservedObject var editorialEngine: EditorialEngine
    
    
    // MARK: - Date Intervals
    private var currentYearInterval: DateInterval {
        let today = Date()
        guard let year = Calendar.current.dateInterval(of: .year, for: today) else {
            return DateInterval(start: today, end: today)
        }
        return year
    }
    
    // MARK: - Component Views
    // Note: Removed old layout helper functions since we're using the new grid system
    
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
                            // Monthly Activity Breakdown Chart - REMOVED
                            // Keeping frame with placeholder text
                            VStack {
                                Text("Charts coming soon")
                                    .font(Theme.Fonts.header)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                
                                Text("Monthly activity breakdown chart will be available soon")
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                        },
                        rightTop: {
                            // Project Distribution Chart - REMOVED
                            // Keeping frame with placeholder text
                            VStack {
                                Text("Charts coming soon")
                                    .font(Theme.Fonts.header)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                
                                Text("Project distribution chart will be available soon")
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                        },
                        rightBottom: {
                            // Activity Distribution Chart - REMOVED
                            // Keeping frame with placeholder text
                            VStack {
                                Text("Charts coming soon")
                                    .font(Theme.Fonts.header)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                
                                Text("Activity distribution chart will be available soon")
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                        }
                    )
                    .frame(maxHeight: sessionManager.activeSession != nil ? .infinity : nil) // Add responsive height when active session is present
                }
                .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                .padding(.bottom, Theme.DashboardLayout.dashboardPadding)
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
                await MainActor.run {
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
            await projectsViewModel.loadProjects()
            await MainActor.run {
                chartDataPreparer.prepareYearlyData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
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
        editorialEngine: EditorialEngine()
    )
}
