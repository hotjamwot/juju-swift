import SwiftUI

struct SwiftUIDashboardRootView: View {
    enum Tab: Hashable { case charts, sessions, projects }
    @State private var selected: Tab = .charts

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selected) {
                WebDashboardView()
                    .tabItem { Text("Juju") }
                    .tag(Tab.charts)

                // Placeholder SwiftUI views to be implemented in next phases
                SessionsNativeView()
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

// Temporary placeholders; will be replaced with real implementations
struct SessionsNativeView: View { var body: some View { Text("Sessions (SwiftUI)").frame(maxWidth: .infinity, maxHeight: .infinity) } }
struct ProjectsNativeView: View { var body: some View { Text("Projects (SwiftUI)").frame(maxWidth: .infinity, maxHeight: .infinity) } }


