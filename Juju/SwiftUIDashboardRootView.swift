import SwiftUI

struct SwiftUIDashboardRootView: View {
    // Keep track of which tab is selected
    private enum Tab {
        case charts, sessions, projects
    }
    @State private var selected: Tab = .charts

    var body: some View {
        VStack(spacing: 0) {
            // Removed projects toolbar as part of refactoring
            // if selected == .projects {
            //     ProjectsToolbarView()
            // }
            
            TabView(selection: $selected) {
                WebDashboardView()
                    .tabItem { Text("Juju") }
                    .tag(Tab.charts)

                SessionsView()
                    .tabItem { Text("Sessions") }
                    .tag(Tab.sessions)

                ProjectsNativeView()
                    .tabItem { Text("Projects") }
                    .tag(Tab.projects)
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
}

// Removed ProjectsToolbarView as part of refactoring - toolbar functionality eliminated
