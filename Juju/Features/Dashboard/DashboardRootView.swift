import SwiftUI
import Charts

struct DashboardRootView: View {
    @State private var selected: DashboardView = .charts
    @StateObject private var sidebarState = SidebarStateManager()
    @Environment(\.presentationMode) private var presentationMode
    
    // State objects for dashboard views to ensure proper state management
    @StateObject private var chartDataPreparer = ChartDataPreparer()
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
                    // Main content
                    ZStack {
                        switch selected {
                        case .charts:
                            // Single dashboard view — overview with all charts
                            OverviewDashboardView(
                                chartDataPreparer: chartDataPreparer,
                                sessionManager: sessionManager,
                                projectsViewModel: projectsViewModel,
                                narrativeEngine: narrativeEngine
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .onAppear {
            // Ensure SessionManager has the full dataset loaded first.
            Task {
                await sessionManager.loadAllSessions()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}

// MARK: - Preview

struct DashboardRootView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardRootView()
            .frame(width: 1400, height: 1000)
            .preferredColorScheme(.dark)
    }
}

// MARK: - Navigation Enum

/// Navigation destinations for the dashboard sidebar.
enum DashboardView: String, CaseIterable, Identifiable {
    case charts
    case sessions
    case projects
    case activityTypes

    var id: String { rawValue }

    /// SF Symbol name shown in the sidebar.
    var icon: String {
        switch self {
        case .charts:        return "chart.bar"
        case .sessions:      return "list.bullet"
        case .projects:      return "folder"
        case .activityTypes: return "tag"
        }
    }
}
