import SwiftUI
import Charts

struct DashboardRootView: View {
    @State private var selected: DashboardView = .charts
    @StateObject private var sidebarState = SidebarStateManager()
    @Environment(\.presentationMode) private var presentationMode
    
    // Navigation state for weekly/yearly dashboard views
    @State private var dashboardViewType: DashboardViewType? = .weekly
    
    // State objects for dashboard views to ensure proper state management
    @StateObject private var weeklyDashboardState = ChartDataPreparer()
    @StateObject private var yearlyDashboardState = ChartDataPreparer()
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var projectsViewModel = ProjectsViewModel.shared
    @StateObject private var editorialEngine = EditorialEngine()
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Always show sidebar - it's now permanently small with icons only
                SidebarView(selectedView: $selected)

                // Main content
                VStack(spacing: 0) {
                    // Main content
                    ZStack {
                        switch selected {
                        case .charts:
                            // Dashboard content with weekly/yearly navigation using programmatic ScrollView
                            ZStack {
                                // ScrollView with both dashboards
                                ScrollView(.horizontal) {
                                    HStack(spacing: 0) {
                                        // Weekly Dashboard
                                        WeeklyDashboardView(
                                            chartDataPreparer: weeklyDashboardState,
                                            sessionManager: sessionManager,
                                            projectsViewModel: projectsViewModel,
                                            editorialEngine: editorialEngine
                                        )
                                        .id(DashboardViewType.weekly)
                                        .containerRelativeFrame(.horizontal)
                                        
                                        // Yearly Dashboard
                                        YearlyDashboardView(
                                            chartDataPreparer: yearlyDashboardState,
                                            sessionManager: sessionManager,
                                            projectsViewModel: projectsViewModel,
                                            editorialEngine: editorialEngine
                                        )
                                        .id(DashboardViewType.yearly)
                                        .containerRelativeFrame(.horizontal)
                                    }
                                }
                                .scrollTargetLayout()
                                .scrollTargetBehavior(.paging)
                                .scrollIndicators(.hidden)
                                .scrollPosition(id: $dashboardViewType)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .transition(.opacity)
                                
                                // Bottom navigation circles overlay
                                .overlay(
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            BottomNavigationCircles(currentView: $dashboardViewType)
                                            Spacer()
                                        }
                                    }
                                    .padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
                                    .padding(.bottom, 16)
                                )
                            }
                        case .sessions:
                            SessionsView()
                                .environmentObject(sidebarState)
                                .transition(.opacity)
                        case .projects:
                            ProjectsView()
                                .environmentObject(sidebarState)
                                .transition(.opacity)
                        case .activityTypes:
                            ActivityTypeView()
                                .environmentObject(sidebarState)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: selected)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.background)
            }
            .ignoresSafeArea(edges: .top)
            
            // Sidebar overlay
            SidebarEditView()
                .environmentObject(sidebarState)
                .environmentObject(ProjectsViewModel.shared)
                .environmentObject(ActivityTypesViewModel.shared)
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToYearlyView)) { _ in
            dashboardViewType = .yearly
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToWeeklyView)) { _ in
            dashboardViewType = .weekly
        }
        // Keyboard shortcuts for navigation
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) {
                    switch event.keyCode {
                    case 123: // Left Arrow key
                        // Command + Left Arrow: Go to Weekly
                        dashboardViewType = .weekly
                        return nil
                    case 124: // Right Arrow key
                        // Command + Right Arrow: Go to Yearly
                        dashboardViewType = .yearly
                        return nil
                    default:
                        break
                    }
                }
                return event
            }
        }
    }
    
    // MARK: - Helpers
    
    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let switchToYearlyView = Notification.Name("switchToYearlyView")
    static let switchToWeeklyView = Notification.Name("switchToWeeklyView")
}

// MARK: - Preview

struct DashboardRootView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardRootView()
            .frame(width: 1400, height: 1000)
            .preferredColorScheme(.dark)
    }
}
