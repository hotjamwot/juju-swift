import SwiftUI

struct TabButton: View {
    let tab: Tab
    @Binding var selected: Tab          // the currently chosen tab
    @State private var isHovering = false

    // MARK: – Body
    var body: some View {
        let isSelected = selected == tab
        let systemIcon = iconFor(tab)

        Button {
            withAnimation(.easeInOut(duration: Theme.Design.animationDuration)) { selected = tab }
        } label: {
            Image(systemName: systemIcon)
                .font(Theme.Fonts.icon)
                .foregroundColor(isSelected
                                     ? Theme.Tab.selectedIcon.swiftUIColor
                                     : Theme.Tab.icon.swiftUIColor)
                .padding(Theme.spacingSmall)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 48, height: 48)           // a clean square → pill with corner radius
        .background(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .fill(isSelected
                          ? Theme.Tab.selectedBackground.swiftUIColor
                          : (isHovering ? Theme.Tab.hoverBackground.swiftUIColor : Theme.Tab.background.swiftUIColor))
        )
        .shadow(color: isSelected ? Theme.Tab.glow.swiftUIColor : .clear,
                radius: 4, x: 0, y: 0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: Theme.Design.animationDuration)) { isHovering = hovering }
        }
    }

    // MARK: – Icon helper
    private func iconFor(_ tab: Tab) -> String {
        switch tab {
        case .charts:   return "chart.bar.doc.horizontal"
        case .sessions: return "list.dash"
        case .projects: return "folder"
        }
    }
}
