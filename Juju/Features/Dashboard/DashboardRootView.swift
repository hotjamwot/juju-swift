import SwiftUI
import Charts

struct DashboardRootView: View {
    @State private var selected: DashboardView = .charts
    @StateObject private var sidebarState = SidebarStateManager()
    @Environment(\.presentationMode) private var presentationMode
    
    // Navigation state for weekly/yearly dashboard views
    @State private var dashboardViewType: DashboardViewType = .weekly
    
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
                            // Dashboard content with weekly/yearly navigation
                            VStack(spacing: 0) {
                                // Chart content with floating elements
                                ZStack {
                                    switch dashboardViewType {
                                    case .weekly:
                                        WeeklyDashboardView()
                                            .transition(.opacity)
                                    case .yearly:
                                        YearlyDashboardView()
                                            .transition(.opacity)
                                    }
                                }
                                .animation(.easeInOut(duration: 0.2), value: dashboardViewType)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity)
                        case .sessions:
                            SessionsView()
                                .environmentObject(sidebarState)
                                .transition(.opacity)
                        case .projects:
                            ProjectsNativeView()
                                .environmentObject(sidebarState)
                                .transition(.opacity)
                        case .activityTypes:
                            ActivityTypesView()
                                .environmentObject(sidebarState)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: selected)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, Theme.spacingLarge)
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
