import SwiftUI
import Combine

struct SidebarView: View {
    @Binding var selectedView: DashboardView

    private let sidebarWidth: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            // Juju logo at the top — rendered in textPrimary, not accentColor,
            // per the editorial philosophy: the logo is content, not decoration.
            Image("juju_logo")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 28)
                .padding(.top, Theme.Spacing.xxl)  // 48pt — generous breathing room at the top
                .padding(.bottom, Theme.Spacing.lg) // 24pt — space before navigation buttons

            // Tight button group
            VStack(spacing: 2) {
                ForEach(DashboardView.allCases) { view in
                    SidebarButton(
                        selected: $selectedView,
                        target:   view
                    )
                }
            }

            Spacer()
        }
        .frame(width: sidebarWidth)
        .background(Theme.Colors.background)
    }

    // MARK: ── Sidebar button (inner type)

    struct SidebarButton: View {
        @Binding var selected: DashboardView
        let target: DashboardView

        @State private var isHovered = false

        var body: some View {
            Button {
                withAnimation(.easeInOut(duration: Theme.Design.animationDuration)) {
                    selected = target
                }
            } label: {
                ZStack(alignment: .leading) {
                    // Left-edge selection pill — off-white, not accent colour.
                    // Per editorial philosophy: interactive states use opacity shifts.
                    if isSelected {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.Colors.interactive)
                            .frame(width: 3, height: 24)
                            .padding(.leading, 2)
                    }

                    Image(systemName: target.icon)
                        .font(Theme.Fonts.body.weight(isSelected ? .semibold : .regular))
                        .frame(width: 32, height: 32)
                        .background(
                            isHovered && !isSelected
                                ? RoundedRectangle(cornerRadius: 8)
                                    .fill(Theme.Colors.interactiveSelected)
                                : nil
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .foregroundColor(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(target.rawValue)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: Theme.Design.animationDuration)) {
                    isHovered = hovering
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
