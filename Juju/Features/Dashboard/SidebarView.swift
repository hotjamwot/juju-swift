import SwiftUI

enum DashboardView: String, CaseIterable, Identifiable {
    case charts   = "Charts"
    case sessions = "Sessions"
    case projects = "Projects"

    // MARK: - Icons
    var icon: String {
        switch self {
        case .charts:   return "chart.xyaxis.line"
        case .sessions: return "clock"
        case .projects: return "folder"
        }
    }

    // Required by Identifiable
    var id: String { rawValue }
}

// MARK: ── Sidebar button (re‑usable)
struct SidebarButton: View {
    @Binding var selected: DashboardView   // the parent's selection state
    let target: DashboardView              // the view that this button represents

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            // ❗️  Selection – this drives the right‑hand panel
            selected = target
        } label: {
            HStack(spacing: Theme.spacingMedium) {
                Image(systemName: target.icon)
                    .font(.system(size: 16, weight: .light))
                    .frame(width: 12, height: 12)

                Text(target.rawValue)
                    .font(Theme.Fonts.body)

                Spacer()
            }
            .foregroundColor(isSelected ? Color.accent.opacity(0.8) : (isHovered ? .secondary : .primary))
            .padding(.vertical, Theme.spacingLarge)
            .padding(.horizontal, Theme.spacingMedium)
            .background(
                ZStack {
                    if isSelected {          // ✅  Selected colour
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .fill(Color.background.opacity(0.8))
                    } else if isHovered {     // ☁️  Hover reveal
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .fill(colorScheme == .dark ?
                                  Theme.Colors.surface.opacity(0.6) :
                                    Theme.Colors.textSecondary)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: Theme.Design.animationDuration)) {
                isHovered = hovering
            }
        }
    }

    private var isSelected: Bool { selected == target }
}

// MARK: ── Sidebar container
struct SidebarView: View {
    @Binding var selectedView: DashboardView

    var body: some View {
        VStack(spacing: 10) {
            /* ----------- CONTENT ----------- */
            ForEach(DashboardView.allCases) { view in
                SidebarButton(selected: $selectedView, target: view)
                    .accessibilityLabel(view.rawValue)
                    .padding(.leading, Theme.spacingSmall)
            }

            Spacer()
        }
        .frame(width: 220)
        .background(Theme.Colors.sidebarBackground)
        .padding(.top, Theme.spacingExtraLarge)
    }
}

// MARK: ── Preview (optional)

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(selectedView: .constant(.charts))
            .frame(minWidth: 800, minHeight: 500)
    }
}
