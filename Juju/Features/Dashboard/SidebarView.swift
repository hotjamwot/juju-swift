import SwiftUI
import Combine // Import Combine for the Timer

// MARK: ──  Dashboard navigation items
enum DashboardView: String, CaseIterable, Identifiable {
    case charts   = "Charts"
    case sessions = "Sessions"
    case projects = "Projects"

    // — icon for each enum case
    var icon: String {
        switch self {
        case .charts:   return "chart.xyaxis.line"
        case .sessions: return "clock"
        case .projects: return "folder"
        }
    }

    // Identifiable requirement
    var id: String { rawValue }
}

// MARK: ──  Sidebar view
struct SidebarView: View {
    @Binding var selectedView: DashboardView

    // ─────  sizes that drive the width
    private let sidebarWidth: CGFloat = 60

    var body: some View {
        VStack(spacing: 0) {
            Spacer()   // center icons vertically

            ForEach(DashboardView.allCases) { view in
                SidebarButton(
                    selected: $selectedView,
                    target:   view
                )
            }

            Spacer()
        }
        .frame(width: sidebarWidth)
        .background(Theme.Colors.background)
    }

    // MARK: ──  Sidebar button (defined inside this file)
    struct SidebarButton: View {
        @Binding var selected: DashboardView
        let target: DashboardView

        @State private var isHovered = false
        @State private var tooltipTimer: Timer? = nil
        @State private var iconScale: CGFloat = 1.0
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            Button {
                selected = target
            } label: {
                VStack(alignment: .center) {
                    // ---- icon – always visible
                    Image(systemName: target.icon)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                        .background(backgroundView)
                        .cornerRadius(Theme.Design.cornerRadius)
                        .scaleEffect(iconScale)
                        .animation(.easeInOut(duration: 0.2), value: iconScale) // Animate scale

                }
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.vertical, Theme.spacingMedium)
                .frame(maxWidth: .infinity, alignment: .center)
                .overlay(
                    // Tooltip
                    VStack {
                        Spacer()
                        if isHovered {
                            Text(target.rawValue)
                                .font(Theme.Fonts.caption)
                                .padding(4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(4)
                                .opacity(1)
                                .offset(y: 40)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                )
            }
            .buttonStyle(.plain)
            .focusable(false)
            .frame(maxWidth: .infinity, alignment: .center)
            .onHover { hovering in
                if hovering {
                    startTooltipTimer()
                    iconScale = 1.4 // Grow on hover
                } else {
                    cancelTooltipTimer()
                    iconScale = 1.0 // Shrink back
                }
            }
        }

        func startTooltipTimer() {
            tooltipTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                isHovered = true
                tooltipTimer?.invalidate()
                tooltipTimer = nil
            }
        }

        func cancelTooltipTimer() {
            isHovered = false
            tooltipTimer?.invalidate()
            tooltipTimer = nil
            
        }


        // background for selection / hover
        private var backgroundView: some View {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .fill(Color.background.opacity(0.8))
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



// MARK: ── Preview (optional)

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(selectedView: .constant(.charts))
            .frame(minWidth: 800, minHeight: 500)
    }
}
