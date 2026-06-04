import SwiftUI
import Combine

struct SidebarView: View {
    @Binding var selectedView: DashboardView

    private let sidebarWidth: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            // Juju logo at the top
            Image("juju_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 28)
                .padding(.top, 48)
                .padding(.bottom, 24)

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
                    // Left-edge selection pill
                    if isSelected {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.Colors.accentColor)
                            .frame(width: 3, height: 20)
                            .padding(.leading, 2)
                    }

                    Image(systemName: target.icon)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                        .frame(width: 32, height: 32)
                        .background(
                            isHovered && !isSelected
                                ? RoundedRectangle(cornerRadius: 8)
                                    .fill(Theme.Colors.surface.opacity(0.5))
                                : nil
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .foregroundColor(isSelected ? .primary : Theme.Colors.textSecondary)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(target.rawValue)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
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
