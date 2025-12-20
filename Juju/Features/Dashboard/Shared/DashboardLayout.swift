import SwiftUI

/// Unified Dashboard Layout
/// A flexible, responsive layout system for all dashboard charts with configurable parameters
struct DashboardLayout: View {
    enum LayoutType {
        case weekly(
            topLeft: AnyView,
            topRight: AnyView,
            bottom: AnyView
        )
        case yearly(
            left: AnyView,
            rightTop: AnyView,
            rightBottom: AnyView
        )
    }
    
    let layoutType: LayoutType
    
    // Configurable layout parameters
    let topHeightRatio: CGFloat
    let bottomHeightRatio: CGFloat
    let spacing: CGFloat
    let gap: CGFloat
    
    init(
        layoutType: LayoutType,
        topHeightRatio: CGFloat = 0.4,
        bottomHeightRatio: CGFloat = 0.5,
        spacing: CGFloat = Theme.DashboardLayout.dashboardPadding,
        gap: CGFloat = Theme.DashboardLayout.chartGap
    ) {
        self.layoutType = layoutType
        self.topHeightRatio = topHeightRatio
        self.bottomHeightRatio = bottomHeightRatio
        self.spacing = spacing
        self.gap = gap
    }
    
    // Convenience initializers
    private init(
        layoutType: LayoutType,
        topHeightRatio: CGFloat = 0.4,
        bottomHeightRatio: CGFloat = 0.5
    ) {
        self.layoutType = layoutType
        self.topHeightRatio = topHeightRatio
        self.bottomHeightRatio = bottomHeightRatio
        self.spacing = Theme.DashboardLayout.dashboardPadding
        self.gap = Theme.DashboardLayout.chartGap
    }
    
    // Convenience initializer for weekly layout
    static func weekly(
        @ViewBuilder topLeft: () -> some View,
        @ViewBuilder topRight: () -> some View,
        @ViewBuilder bottom: () -> some View,
        topHeightRatio: CGFloat = 0.45,
        bottomHeightRatio: CGFloat = 0.55
    ) -> DashboardLayout {
        DashboardLayout(
            layoutType: .weekly(
                topLeft: AnyView(topLeft()),
                topRight: AnyView(topRight()),
                bottom: AnyView(bottom())
            ),
            topHeightRatio: topHeightRatio,
            bottomHeightRatio: bottomHeightRatio
        )
    }
    
    // Convenience initializer for yearly layout
    static func yearly(
        @ViewBuilder left: () -> some View,
        @ViewBuilder rightTop: () -> some View,
        @ViewBuilder rightBottom: () -> some View
    ) -> DashboardLayout {
        DashboardLayout(
            layoutType: .yearly(
                left: AnyView(left()),
                rightTop: AnyView(rightTop()),
                rightBottom: AnyView(rightBottom())
            )
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // Calculate available space
            let availableWidth = max(0, width - (spacing * 2))
            let availableHeight = max(0, height - (spacing * 2))
            
            switch layoutType {
            case .weekly(let topLeft, let topRight, let bottom):
                // Weekly layout: 2x2 grid with extra bottom padding for navigation circles
                VStack(spacing: gap) {
                    HStack(spacing: gap) {
                        ChartContainer(content: topLeft)
                            .frame(width: availableWidth * 0.48, height: availableHeight * topHeightRatio)
                        
                        ChartContainer(content: topRight)
                            .frame(width: availableWidth * 0.48, height: availableHeight * topHeightRatio)
                    }
                    
                    ChartContainer(content: bottom)
                        .frame(width: availableWidth, height: availableHeight * bottomHeightRatio)
                }
                .padding(.horizontal, spacing)
                .padding(.top, spacing)
                .padding(.bottom, spacing + 40) // Extra padding for navigation circles
                
            case .yearly(let left, let rightTop, let rightBottom):
                // Yearly layout: left column full height, right column stacked
                HStack(spacing: gap) {
                    // Left Column: Monthly distribution chart (full height)
                    ChartContainer(content: left)
                        .frame(width: availableWidth * Theme.DashboardLayout.yearlyLeftColumnRatio, height: availableHeight)
                    
                    // Right Column: Stacked charts with explicit height allocation
                    // Top chart gets 60% of right column height, bottom chart gets 40%
                    VStack(spacing: gap) {
                        ChartContainer(content: rightTop)
                            .frame(maxWidth: .infinity, maxHeight: availableHeight * 0.6)
                        
                        ChartContainer(content: rightBottom)
                            .frame(maxWidth: .infinity, maxHeight: availableHeight * 0.4)
                    }
                    .frame(width: availableWidth * Theme.DashboardLayout.yearlyRightColumnRatio, height: availableHeight)
                }
                .padding(.horizontal, spacing)
                .padding(.vertical, spacing)
            }
        }
    }
    
    // Reusable chart container for consistent styling
    private struct ChartContainer<Content: View>: View {
        let content: Content
        
        var body: some View {
            VStack {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(Theme.DashboardLayout.chartPadding)
            .background(Theme.Colors.surface.opacity(0.3)) // Reduced opacity for cleaner look
            .cornerRadius(Theme.DashboardLayout.chartCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.DashboardLayout.chartCornerRadius)
                    .stroke(Theme.Colors.divider, lineWidth: Theme.DashboardLayout.chartBorderWidth)
            )
            // Removed shadow for cleaner, flatter aesthetic
        }
    }
}

// MARK: - Preview
#Preview {
    DashboardLayout.weekly(
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

// MARK: - Bottom Navigation Circles

/// Bottom navigation circles for switching between weekly and yearly dashboard views
/// Positioned at the bottom of the dashboard window, similar to the active session status bar
struct BottomNavigationCircles: View {
    @Binding var currentView: DashboardViewType?
    
    var body: some View {
        HStack(spacing: 16) {
            // Weekly indicator circle
            Circle()
                .fill(currentView == .weekly ? Theme.Colors.accentColor : Theme.Colors.textSecondary)
                .frame(width: 10, height: 10)
                .opacity(currentView == .weekly ? 0.8 : 0.3)
                .scaleEffect(currentView == .weekly ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: currentView)
                .contentShape(Circle()) // Make entire circle clickable
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentView = .weekly
                    }
                }
                .help("Weekly Dashboard")
            
            // Yearly indicator circle
            Circle()
                .fill(currentView == .yearly ? Theme.Colors.accentColor : Theme.Colors.textSecondary)
                .frame(width: 10, height: 10)
                .opacity(currentView == .yearly ? 0.8 : 0.3)
                .scaleEffect(currentView == .yearly ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: currentView)
                .contentShape(Circle()) // Make entire circle clickable
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentView = .yearly
                    }
                }
                .help("Yearly Dashboard")
        }
        .padding(.bottom, 8)
        .padding(.top, 4)
        .padding(.horizontal, 16)
    }
}

// MARK: - Yearly Dashboard Layout Preview
#Preview {
    DashboardLayout.yearly(
        left: {
            VStack {
                Text("Monthly Distribution")
                    .font(Theme.Fonts.header)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Full-height monthly chart")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        },
        rightTop: {
            VStack {
                Text("Project Distribution")
                    .font(Theme.Fonts.header)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Top-right chart")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        },
        rightBottom: {
            VStack {
                Text("Activity Types")
                    .font(Theme.Fonts.header)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Bottom-right chart")
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

// MARK: - Bottom Navigation Circles Preview
#Preview {
    VStack {
        Spacer()
        BottomNavigationCircles(currentView: .constant(.weekly))
    }
    .frame(width: 400, height: 100)
    .background(Theme.Colors.background)
    .preferredColorScheme(.dark)
}
