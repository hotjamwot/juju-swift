import SwiftUI

struct SwiftUIDashboardRootView: View {
    private enum Tab {
        case charts, sessions, projects
    }

    @State private var selected: Tab = .charts
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ZStack {
            // Dark grey background
            Color(Theme.background)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top navigation bar
                HStack(spacing: 0) {
                    // Left logo
                    Image("AppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .opacity(0.8)
                        .padding(.leading, Theme.spacingLarge)

                    Spacer()

                    // Centered tab picker
                    Picker("", selection: $selected) {
                        Text("Juju").tag(Tab.charts)
                        Text("Sessions").tag(Tab.sessions)
                        Text("Projects").tag(Tab.projects)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 300)
                    .tint(.white)
                    .padding(.vertical, Theme.spacingExtraSmall)

                    Spacer()
                        .frame(width: 36)
                        .padding(.trailing, Theme.spacingLarge)
                }
                .frame(height: 42)
                .background(Color(Theme.background))
                .overlay(Divider().background(Theme.surface), alignment: .bottom)

                // Main content
                ZStack {
                    switch selected {
                    case .charts:
                        DashboardNativeSwiftChartsView()
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
                .padding(.horizontal, Theme.spacingLarge)
                .padding(.bottom, Theme.spacingLarge)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Helpers

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }

    private func cleanupWebTabIfNeeded() {
        if selected == .charts {
            // Attempt to clean up the WebView when the window is closing
            NotificationCenter.default.post(name: .cleanupWebView, object: nil)
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let cleanupWebView = Notification.Name("cleanupWebView")
}
