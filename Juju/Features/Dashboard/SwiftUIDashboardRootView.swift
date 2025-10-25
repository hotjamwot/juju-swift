import SwiftUI

struct SwiftUIDashboardRootView: View {
    @State private var selected: DashboardView = .charts
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        ZStack {
            // Dark grey background
            Color(Theme.Colors.background)
                .ignoresSafeArea()
            
            HStack(spacing: 0) {
                SidebarView(selectedView: $selected)
                    .background(Color(Theme.Colors.sidebarBackground))
                
                Divider()
                    .hidden()
                
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
        }
    }
    
    // MARK: - Helpers
    
    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}
