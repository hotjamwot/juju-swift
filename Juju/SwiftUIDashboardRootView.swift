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
            Color(red: 0.10, green: 0.10, blue: 0.12)
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
                        .padding(.leading, 16)

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
                    .padding(.vertical, 6)

                    Spacer()
                        .frame(width: 36)
                        .padding(.trailing, 16)
                }
                .frame(height: 42)
                .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                .overlay(Divider().background(Color.white.opacity(0.15)), alignment: .bottom)

                // Main content
                ZStack {
                    switch selected {
                    case .charts:
                        NativeSwiftChartsView()
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
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
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
