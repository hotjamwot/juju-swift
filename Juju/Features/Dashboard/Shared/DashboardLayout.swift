import SwiftUI

// MARK: - Deprecated: Dashboard Layout
//
// ⚠️ DashboardLayout has been replaced by direct ScrollView + LazyVStack layouts
//    in OverviewDashboardView and YearlyDashboardView. Each chart now sits at its
//    natural height with consistent horizontal padding.
//
//    This struct is kept only for the BottomNavigationCircles component below.
//    Remove the DashboardLayout portion entirely in a future cleanup pass.

@available(*, deprecated, message: "Use ScrollView + LazyVStack directly in OverviewDashboardView/YearlyDashboardView")
struct DashboardLayout: View {
    // Legacy — no longer used. Kept to avoid breaking compilation until fully removed.
    enum LayoutType {
        case weekly(topLeft: AnyView, topRight: AnyView, bottom: AnyView)
        case yearly(left: AnyView, rightTop: AnyView, rightBottom: AnyView)
    }
    
    let layoutType: LayoutType
    let topHeightRatio: CGFloat
    let bottomHeightRatio: CGFloat
    let gap: CGFloat
    let topLeftWidthRatio: CGFloat

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
        EmptyView()
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Text("DashboardLayout is deprecated")
            .font(Theme.Fonts.header)
            .foregroundColor(Theme.Colors.textPrimary)
        Text("Charts now use ScrollView + LazyVStack directly")
            .font(Theme.Fonts.body)
            .foregroundColor(Theme.Colors.textSecondary)
    }
    .frame(width: 600, height: 300)
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