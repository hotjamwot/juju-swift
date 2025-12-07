import SwiftUI
import Combine

// MARK: ──  Dashboard navigation items
enum DashboardView: String, CaseIterable, Identifiable {
    case charts        = "Charts"
    case sessions      = "Sessions"
    case projects      = "Projects"
    case activityTypes = "Activity Types"

    var icon: String {
        switch self {
        case .charts:        return "chart.xyaxis.line"
        case .sessions:      return "clock"
        case .projects:      return "folder"
        case .activityTypes: return "tag"
        }
    }

    var id: String { rawValue }
}

struct SidebarView: View {
    @Binding var selectedView: DashboardView

    // Sidebar width you want to keep
    private let sidebarWidth: CGFloat = 50

    var body: some View {
        VStack(spacing: Theme.spacingMedium) {
            // Juju logo at the top
            Image("juju_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 32)
                .padding(.top, 64)
                .padding(.bottom, 32)
            
            ForEach(DashboardView.allCases) { view in
                SidebarButton(
                    selected: $selectedView,
                    target:   view
                )
            }
            
            // Another spacer to keep buttons centered
            Spacer()
        }
        .padding(.top, 32)
        .frame(width: sidebarWidth)
        .background(Theme.Colors.background)
    }

    // MARK: ──  Sidebar button (inner type)
    struct SidebarButton: View {
        @Binding var selected: DashboardView
        let target: DashboardView

        @State private var iconScale: CGFloat = 1.0
        @State private var isHovered = false          // needed for hover‑background
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            Button {
                selected = target
            } label: {
                VStack(alignment: .center) {
                    Image(systemName: target.icon)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 32, height: 32)
                        .background(backgroundView)
                        .cornerRadius(Theme.Design.cornerRadius)
                        .scaleEffect(iconScale)
                        .animation(.easeInOut(duration: Theme.Design.animationDuration),
                                   value: iconScale)
                }
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.vertical, Theme.spacingMedium)
                .frame(maxWidth: .infinity, alignment: .center)
            } // <-- close label here
            .buttonStyle(.plain)
            .focusable(false)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(target.rawValue)       // native macOS tooltip
            .onHover { hovering in
                isHovered = hovering
                iconScale = hovering ? 1.2 : 1.0
            }
        }

        // ----︎ background for selection / hover
        private var backgroundView: some View {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .fill(Theme.Colors.background.opacity(0.8))
                } else if isHovered {
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .fill(
                            colorScheme == .dark
                                ? Theme.Colors.background.opacity(0.4)
                                : Theme.Colors.textSecondary
                        )
                }
            }
        }

        private var isSelected: Bool { selected == target }
    }
}

// MARK: ──  Preview

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(selectedView: .constant(.charts))
            .frame(minWidth: 400, minHeight: 800)
    }
}
