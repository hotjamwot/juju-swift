import SwiftUI

/// Unified Dashboard Layout
/// A flexible, responsive layout system for all dashboard charts with configurable parameters
///
/// Design Philosophy (Scandinavian-Japanese Minimal):
/// - Single source of padding: the parent view owns all padding, the layout only manages internal gaps
/// - Cards float on the surface without borders — subtlety through surface color, not lines
/// - Generous but controlled whitespace for calm, focused data reading
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
    let gap: CGFloat
    let topLeftWidthRatio: CGFloat  // New: controls the left column width in weekly layout

    init(
        layoutType: LayoutType,
        topHeightRatio: CGFloat = 0.4,
        bottomHeightRatio: CGFloat = 0.5,
        gap: CGFloat = Theme.DashboardLayout.chartGap,
        topLeftWidthRatio: CGFloat = 0.5
    ) {
        self.layoutType = layoutType
        self.topHeightRatio = topHeightRatio
        self.bottomHeightRatio = bottomHeightRatio
        self.gap = gap
        self.topLeftWidthRatio = topLeftWidthRatio
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
        self.gap = Theme.DashboardLayout.chartGap
        self.topLeftWidthRatio = 0.5
    }
    
    // Convenience initializer for weekly layout
    static func weekly(
        @ViewBuilder topLeft: () -> some View,
        @ViewBuilder topRight: () -> some View,
        @ViewBuilder bottom: () -> some View,
        topHeightRatio: CGFloat = 0.4,
        bottomHeightRatio: CGFloat = 0.6,
        topLeftWidthRatio: CGFloat = 0.5,
        gap: CGFloat = Theme.DashboardLayout.chartGap
    ) -> DashboardLayout {
        DashboardLayout(
            layoutType: .weekly(
                topLeft: AnyView(topLeft()),
                topRight: AnyView(topRight()),
                bottom: AnyView(bottom())
            ),
            topHeightRatio: topHeightRatio,
            bottomHeightRatio: bottomHeightRatio,
            gap: gap,
            topLeftWidthRatio: topLeftWidthRatio
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
            
            // Available space — no horizontal padding since the parent owns that
            let availableWidth = max(0, width)
            let availableHeight = max(0, height)
            
            switch layoutType {
            case .weekly(let topLeft, let topRight, let bottom):
                // Weekly layout: 2-column top row + full-width bottom
                VStack(spacing: gap) {
                    HStack(spacing: gap) {
                        ChartContainer(content: topLeft)
                            .frame(width: availableWidth * topLeftWidthRatio - gap / 2,
                                   height: availableHeight * topHeightRatio - gap / 2)

                        ChartContainer(content: topRight)
                            .frame(width: availableWidth * (1 - topLeftWidthRatio) - gap / 2,
                                   height: availableHeight * topHeightRatio - gap / 2)
                    }
                    .frame(height: availableHeight * topHeightRatio)
                    
                    ChartContainer(content: bottom)
                        .frame(width: availableWidth,
                               height: availableHeight * bottomHeightRatio - gap)
                }
                
            case .yearly(let left, let rightTop, let rightBottom):
                // Yearly layout: left column full height, right column stacked
                HStack(spacing: gap) {
                    // Left Column: Monthly distribution chart (full height)
                    ChartContainer(content: left)
                        .frame(width: availableWidth * Theme.DashboardLayout.yearlyLeftColumnRatio,
                               height: availableHeight)
                    
                    // Right Column: Stacked charts with explicit height allocation
                    // Top chart gets 60% of right column height, bottom gets 40%
                    VStack(spacing: gap) {
                        ChartContainer(content: rightTop)
                            .frame(maxWidth: .infinity, maxHeight: availableHeight * 0.6 - gap / 2)
                        
                        ChartContainer(content: rightBottom)
                            .frame(maxWidth: .infinity, maxHeight: availableHeight * 0.4 - gap / 2)
                    }
                    .frame(width: availableWidth * Theme.DashboardLayout.yearlyRightColumnRatio,
                           height: availableHeight)
                }
            }
        }
    }
    
    // Reusable chart container for consistent styling
    // Uses the new borderless card design: 12pt radius, cardSurface background, no borders
    private struct ChartContainer<Content: View>: View {
        let content: Content
        
        var body: some View {
            VStack {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(Theme.Spacing.md)  // 16pt — comfortable inner padding for all chart cards
            .background(Theme.Colors.cardSurface)
            .cornerRadius(Theme.Design.cornerRadius)
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

/// Bottom navigation circles for switching between overview and yearly dashboard views
/// Positioned at the bottom of the dashboard window, similar to the active session status bar
struct BottomNavigationCircles: View {
    @Binding var currentView: DashboardViewType?
    
    var body: some View {
        HStack(spacing: 16) {
            // Overview indicator circle
            Circle()
                .fill(currentView == .overview ? Theme.Colors.accentColor : Theme.Colors.textSecondary)
                .frame(width: 10, height: 10)
                .opacity(currentView == .overview ? 0.8 : 0.3)
                .scaleEffect(currentView == .overview ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: currentView)
                .contentShape(Circle()) // Make entire circle clickable
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentView = .overview
                    }
                }
                .help("Overview Dashboard")
            
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
        BottomNavigationCircles(currentView: .constant(.overview))
    }
    .frame(width: 400, height: 100)
    .background(Theme.Colors.background)
    .preferredColorScheme(.dark)
}