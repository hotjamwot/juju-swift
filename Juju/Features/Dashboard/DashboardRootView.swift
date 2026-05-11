import SwiftUI
import Charts

struct DashboardRootView: View {
    @State private var selected: DashboardView = .charts
    @StateObject private var sidebarState = SidebarStateManager()
    @Environment(\.presentationMode) private var presentationMode
    
    // Navigation state for overview/yearly dashboard views
    @State private var dashboardViewType: DashboardViewType? = .overview
    
    // State objects for dashboard views to ensure proper state management
    @StateObject private var overviewDashboardState = ChartDataPreparer()
    @StateObject private var yearlyDashboardState = ChartDataPreparer()
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var projectsViewModel = ProjectsViewModel.shared
    @StateObject private var narrativeEngine = NarrativeEngine()
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Always show sidebar - it's now permanently small with icons only
                SidebarView(selectedView: $selected)

                // Main content
                VStack(spacing: 0) {
                    // Consistent top padding — provides breathing room when no active session bar
                    // (when active session is present, the bar itself provides this spacing)
                    Spacer().frame(height: sessionManager.activeSession == nil ? Theme.DashboardLayout.dashboardPadding : 0)
                    
                    // Main content
                    ZStack {
                        switch selected {
                        case .charts:
                            // Dashboard content with overview/yearly navigation using programmatic ScrollView
                            ZStack {
                                // ScrollView with both dashboards
                                ScrollView(.horizontal) {
                                    HStack(spacing: 0) {
// Overview Dashboard
                                        OverviewDashboardView(
                                            chartDataPreparer: overviewDashboardState,
                                            sessionManager: sessionManager,
                                            projectsViewModel: projectsViewModel,
                                            narrativeEngine: narrativeEngine
                                        )
                                        .id(DashboardViewType.overview)
                                        .containerRelativeFrame(.horizontal)
                                        
// Yearly Dashboard
                                        YearlyDashboardView(
                                            chartDataPreparer: yearlyDashboardState,
                                            sessionManager: sessionManager,
                                            projectsViewModel: projectsViewModel,
                                            narrativeEngine: narrativeEngine
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
                            ProjectStoryContainerView()
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
        .onReceive(NotificationCenter.default.publisher(for: .switchToOverviewView)) { _ in
            dashboardViewType = .overview
        }
        // Keyboard shortcuts for navigation
        .onAppear {
            // Priority 1: Ensure SessionManager has the full dataset loaded first.
            // This prevents race conditions where dashboard views might load partial
            // data (e.g., weekly only) into sessionManager.allSessions before the
            // full yearly data is loaded, leading to data loss if edits occur.
            Task {
                await sessionManager.loadAllSessions()
            }
            
            // Now that the full data is loaded, proceed with other setup.
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) {
                    switch event.keyCode {
                    case 123: // Left Arrow key
                        // Command + Left Arrow: Go to Overview
                        dashboardViewType = .overview
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
    static let switchToOverviewView = Notification.Name("switchToOverviewView")
}

// MARK: - Preview

struct DashboardRootView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardRootView()
            .frame(width: 1400, height: 1000)
            .preferredColorScheme(.dark)
    }
}