import SwiftUI

struct SwiftUIDashboardRootView: View {
    @State private var selected: Tab = .charts
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ZStack {
            // Dark grey background
            Color(Theme.Colors.background)
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

                    // CENTERED TAB BAR
                    HStack(spacing: Theme.spacingSmall) {
                        ForEach(Tab.allCases) { tab in
                            TabButton(tab: tab, selected: $selected)
                        }
                    }
                    .frame(maxWidth: 260)          // tweak if you want a tighter band
                    .padding(.vertical, Theme.spacingSmall)
                    Spacer()
                        .frame(width: 36)
                        .padding(.trailing, Theme.spacingLarge)
                }
                .frame(height: 42)
                .background(Theme.Colors.background)
                .overlay(Divider().background(Theme.Colors.divider), alignment: .bottom)
                
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Theme.spacingLarge)
                .padding(.bottom, Theme.spacingLarge)
            }
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
