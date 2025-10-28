import SwiftUI

struct SwiftUIDashboardRootView: View {
    @State private var selected: DashboardView = .charts
    @State private var sidebarOpen = false
    @State private var isHoveringSidebarButton = false
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            if sidebarOpen {
                SidebarView(selectedView: $selected)
                    .frame(width: 220)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .background(Theme.Colors.sidebarBackground)
                    .onHover { hovering in
                        if !hovering && !isHoveringSidebarButton {
                            withAnimation(.easeInOut) {
                                sidebarOpen = false
                            }
                        }
                    }
            } else {
                // Empty space for hover area
                Rectangle()
                    .fill(.clear)
                    .frame(width: 48)
                    .onHover { hovering in
                        isHoveringSidebarButton = hovering
                        if hovering {
                            withAnimation(.easeInOut) {
                                sidebarOpen = true
                            }
                        }
                    }
            }

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

// MARK: - TooltipView
struct TooltipView: View {
    let text: String
    @State private var show = false

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(6)
            .background(.ultraThinMaterial)
            .cornerRadius(6)
            .opacity(show ? 1 : 0)
            .offset(y: -40)
            .onHover { hovering in
                withAnimation(.easeInOut) { show = hovering }
            }
    }
}
