import SwiftUI

struct SidebarView: View {
    @Binding var selected: Tab
    @AppStorage("sidebarCollapsed") private var isCollapsed: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Toggle button
            Button {
                withAnimation(.easeInOut(duration: Theme.Design.animationDuration)) {
                    isCollapsed.toggle()
                }
            } label: {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.left")
                    .font(Theme.Fonts.icon)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .background(Theme.Colors.divider)
                .hidden()

            // Tab buttons
            VStack(spacing: Theme.spacingSmall) {
                ForEach(Tab.allCases) { tab in
                    TabButton(tab: tab, selected: $selected, isCollapsed: $isCollapsed)
                }
            }
            .padding(.top, Theme.spacingSmall)

            Spacer()
        }
        .frame(width: isCollapsed ? 44 : 200, alignment: .leading)
        .background(Theme.Colors.background)
        .animation(.easeInOut(duration: Theme.Design.animationDuration), value: isCollapsed)
    }
}
