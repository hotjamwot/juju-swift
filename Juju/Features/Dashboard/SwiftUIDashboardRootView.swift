import SwiftUI

struct SwiftUIDashboardRootView: View {
    @State private var selected: DashboardView = .charts
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        HStack(spacing: 0) {
            // Always show sidebar - it's now permanently small with icons only
            SidebarView(selectedView: $selected)
                .background(Theme.Colors.background)  // Match sidebar to dashboard background

            // Main content
            VStack(spacing: 0) {
                // Main content
                ZStack {
                    switch selected {
                    case .charts:
                        DashboardNativeSwiftChartsView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity)
                    case .sessions:
                        SessionsView()
                            .transition(.opacity)
                    case .projects:
                        ProjectsNativeView()
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selected)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Theme.spacingLarge)
                .padding(.bottom, Theme.spacingLarge)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.Colors.background)
        .ignoresSafeArea(edges: .top)
    }
    
    // MARK: - Helpers
    
    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}
