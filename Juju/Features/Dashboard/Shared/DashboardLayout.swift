import SwiftUI

/// Dashboard Layout
/// A simple, responsive layout for dashboard charts
struct DashboardLayout: View {
    let topLeftContent: AnyView
    let topRightContent: AnyView
    let bottomContent: AnyView
    
    init<T: View, U: View, V: View>(
        @ViewBuilder topLeft: () -> T,
        @ViewBuilder topRight: () -> U,
        @ViewBuilder bottom: () -> V
    ) {
        self.topLeftContent = AnyView(topLeft())
        self.topRightContent = AnyView(topRight())
        self.bottomContent = AnyView(bottom())
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // Calculate available space (accounting for sidebar and padding)
            let availableWidth = max(0, width - 50 - 40) // sidebarWidth + dashboardPadding
            let availableHeight = max(0, height)
            
            // Top row: two charts side by side
            HStack(spacing: 24) {
                // Left chart (48% of available width)
                VStack {
                    topLeftContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Colors.surface.opacity(0.5))
                        .cornerRadius(Theme.Design.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .stroke(Theme.Colors.divider, lineWidth: 1)
                        )
                        .shadow(color: Theme.Colors.divider.opacity(0.2), radius: 8, x: 0, y: 2)
                }
                .frame(width: availableWidth * 0.48, height: availableHeight * 0.4)
                
                // Right chart (48% of available width)
                VStack {
                    topRightContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Colors.surface.opacity(0.5))
                        .cornerRadius(Theme.Design.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .stroke(Theme.Colors.divider, lineWidth: 1)
                        )
                        .shadow(color: Theme.Colors.divider.opacity(0.2), radius: 8, x: 0, y: 2)
                }
                .frame(width: availableWidth * 0.48, height: availableHeight * 0.4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            
            // Bottom row: full width chart
            VStack {
                Spacer()
                VStack {
                    bottomContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Colors.surface.opacity(0.5))
                        .cornerRadius(Theme.Design.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .stroke(Theme.Colors.divider, lineWidth: 1)
                        )
                        .shadow(color: Theme.Colors.divider.opacity(0.2), radius: 8, x: 0, y: 2)
                }
                .frame(width: availableWidth - 48, height: availableHeight * 0.5)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    DashboardLayout(
        topLeft: {
            VStack {
                Text("Top Left Chart")
                    .font(Theme.Fonts.header)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("This is the left chart")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        },
        topRight: {
            VStack {
                Text("Top Right Chart")
                    .font(Theme.Fonts.header)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("This is the right chart")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        },
        bottom: {
            VStack {
                Text("Bottom Chart")
                    .font(Theme.Fonts.header)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("This is the bottom chart")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    )
    .frame(width: 1200, height: 800)
    .background(Theme.Colors.background)
}
