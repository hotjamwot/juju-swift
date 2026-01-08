import SwiftUI

/// View+DashboardExtensions.swift
/// 
/// **Purpose**: Provides dashboard-specific view composition utilities for consistent
/// UI styling, layout, and interaction patterns across dashboard views
/// 
/// **Key Responsibilities**:
/// - Apply consistent dashboard and chart padding
/// - Create loading overlays for dashboard views
/// - Provide common dashboard UI patterns
/// - Standardize dashboard view composition
/// 
/// **Dependencies**: SwiftUI framework for view composition
/// - Theme.swift for consistent styling
/// 
/// **AI Notes**:
/// - All methods are view modifiers for easy chaining
/// - Designed for use in dashboard views (WeeklyDashboardView, YearlyDashboardView)
/// - Uses Theme constants for consistent styling
/// - Provides both simple modifiers and complex view builders
/// - Non-destructive modifiers that can be chained

extension View {
    /// Apply consistent dashboard padding using Theme constants
    ///
    /// **AI Context**: This modifier provides standardized padding for all dashboard views,
    /// ensuring consistent spacing and layout across the application. It's used as the
    /// base padding for dashboard content areas.
    ///
    /// **Business Rules**:
    /// - Uses Theme.DashboardLayout.dashboardPadding for consistent spacing
    /// - Applies padding to all sides (horizontal and vertical)
    /// - Can be chained with other modifiers
    ///
    /// **Performance Notes**:
    /// - SwiftUI modifier is highly optimized
    /// - Minimal memory allocation
    /// - No layout calculations performed
    ///
    /// **Edge Cases**:
    /// - Works with any view type
    /// - Can be applied multiple times (accumulates)
    /// - Compatible with all other view modifiers
    ///
    /// - Returns: View with dashboard padding applied
    func dashboardPadding() -> some View {
        self.padding(.horizontal, Theme.DashboardLayout.dashboardPadding)
            .padding(.vertical, Theme.DashboardLayout.dashboardPadding)
    }
    
    /// Apply consistent chart padding using Theme constants
    ///
    /// **AI Context**: This modifier provides standardized padding specifically for chart
    /// components within dashboard views. It's used for individual chart views to ensure
    /// consistent spacing between chart elements.
    ///
    /// **Business Rules**:
    /// - Uses Theme.DashboardLayout.chartPadding for chart-specific spacing
    /// - Applies padding to all sides (horizontal and vertical)
    /// - Designed for use with chart components
    ///
    /// **Performance Notes**:
    /// - SwiftUI modifier is highly optimized
    /// - Minimal memory allocation
    /// - No layout calculations performed
    ///
    /// **Edge Cases**:
    /// - Works with any view type
    /// - Can be applied multiple times (accumulates)
    /// - Compatible with all other view modifiers
    ///
    /// - Returns: View with chart padding applied
    func chartPadding() -> some View {
        self.padding(.horizontal, Theme.DashboardLayout.chartPadding)
            .padding(.vertical, Theme.DashboardLayout.chartPadding)
    }
    
    /// Create a loading overlay for dashboard views
    ///
    /// **AI Context**: This modifier provides a standardized loading state for dashboard views
    /// when data is being fetched or processed. It shows a progress indicator with a message
    /// while blocking interaction with the underlying content.
    ///
    /// **Business Rules**:
    /// - Shows overlay when isLoading is true
    /// - Displays progress indicator and loading message
    /// - Blocks interaction with underlying content
    /// - Uses Theme constants for consistent styling
    ///
    /// **Performance Notes**:
    /// - Conditional overlay (no overhead when not loading)
    /// - Uses efficient overlay composition
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - Works with any view type
    /// - Can be applied multiple times (last one wins)
    /// - Compatible with most other view modifiers
    ///
    /// - Parameters:
    ///   - isLoading: Boolean indicating whether to show loading overlay
    ///   - message: Custom loading message (defaults to "Loading...")
    /// - Returns: View with conditional loading overlay
    @ViewBuilder
    func loadingOverlay(isLoading: Bool, message: String = "Loading...") -> some View {
        if isLoading {
            self.overlay(
                Rectangle()
                    .fill(Theme.Colors.background.opacity(0.8))
                    .overlay(
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text(message)
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Colors.surface)
                        .cornerRadius(Theme.Design.cornerRadius)
                    )
            )
        } else {
            self
        }
    }
    
    /// Create a chart container with consistent styling
    ///
    /// **AI Context**: This modifier provides standardized styling for chart containers,
    /// including background, border, and corner radius. It's used to create visually
    /// consistent chart components across dashboard views.
    ///
    /// **Business Rules**:
    /// - Applies surface background color
    /// - Adds subtle border using divider color
    /// - Uses Theme corner radius for consistency
    /// - Provides chart-specific padding
    ///
    /// **Performance Notes**:
    /// - SwiftUI modifiers are highly optimized
    /// - Minimal memory allocation
    /// - Efficient layer composition
    ///
    /// **Edge Cases**:
    /// - Works with any view type
    /// - Can be combined with other modifiers
    /// - Maintains view hierarchy for accessibility
    ///
    /// - Returns: View styled as chart container
    func chartContainer() -> some View {
        self
            .background(Theme.Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                    .stroke(Theme.Colors.divider, lineWidth: 1)
            )
            .chartPadding()
    }
    
    /// Create a dashboard card with consistent styling
    ///
    /// **AI Context**: This modifier provides standardized styling for dashboard cards,
    /// which are used to group related content and visualizations. It creates a
    /// visually distinct container that stands out from the background.
    ///
    /// **Business Rules**:
    /// - Applies surface background color
    /// - Adds subtle border using divider color
    /// - Uses Theme corner radius for consistency
    /// - Provides dashboard-specific padding
    ///
    /// **Performance Notes**:
    /// - SwiftUI modifiers are highly optimized
    /// - Minimal memory allocation
    /// - Efficient layer composition
    ///
    /// **Edge Cases**:
    /// - Works with any view type
    /// - Can be combined with other modifiers
    /// - Maintains view hierarchy for accessibility
    ///
    /// - Returns: View styled as dashboard card
    func dashboardCard() -> some View {
        self
            .background(Theme.Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                    .stroke(Theme.Colors.divider, lineWidth: 1)
            )
            .dashboardPadding()
    }
    
    /// Add a subtle shadow for depth effect
    ///
    /// **AI Context**: This modifier adds a subtle shadow to views to create a sense
    /// of depth and separation from the background. It's used for important UI
    /// elements that should stand out visually.
    ///
    /// **Business Rules**:
    /// - Uses Theme divider color with opacity for subtle effect
    /// - Applies standard shadow radius for consistency
    /// - Can be combined with other styling modifiers
    ///
    /// **Performance Notes**:
    /// - SwiftUI shadow is hardware accelerated
    /// - Minimal performance impact
    /// - Efficient rendering
    ///
    /// **Edge Cases**:
    /// - Works with any view type
    /// - Can be applied multiple times (last one wins)
    /// - Compatible with most other view modifiers
    ///
    /// - Returns: View with subtle shadow effect
    func subtleShadow() -> some View {
        self.shadow(color: Theme.Colors.divider.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    /// Create a responsive dashboard layout container
    ///
    /// **AI Context**: This modifier provides a responsive container that adapts to
    /// different screen sizes and orientations. It's used as the base container
    /// for dashboard views to ensure proper layout behavior.
    ///
    /// **Business Rules**:
    /// - Uses ZStack for layered layout
    /// - Provides full width and height
    /// - Applies background color
    /// - Supports responsive design patterns
    ///
    /// **Performance Notes**:
    /// - ZStack is highly optimized for layering
    /// - Minimal memory allocation
    /// - Efficient layout calculations
    ///
    /// **Edge Cases**:
    /// - Works with any view type
    /// - Adapts to different container sizes
    /// - Maintains aspect ratio when needed
    ///
    /// - Returns: View wrapped in responsive dashboard container
    func dashboardContainer() -> some View {
        ZStack {
            Theme.Colors.background
            self
        }
        .ignoresSafeArea()
    }
    
    /// Add a header with title and optional subtitle
    ///
    /// **AI Context**: This modifier adds a standardized header section to views,
    /// commonly used in dashboard views to provide context and navigation.
    /// It creates a visually distinct header area with consistent styling.
    ///
    /// **Business Rules**:
    /// - Uses large, bold text for title
    /// - Optional subtitle with smaller text
    /// - Aligned to leading edge
    /// - Provides appropriate spacing
    ///
    /// **Performance Notes**:
    /// - VStack is highly optimized for vertical layouts
    /// - Minimal memory allocation
    /// - Efficient text rendering
    ///
    /// **Edge Cases**:
    /// - Works with any view type
    /// - Optional subtitle can be nil
    /// - Maintains accessibility for text content
    ///
    /// - Parameters:
    ///   - title: Main header title
    ///   - subtitle: Optional subtitle (defaults to nil)
    /// - Returns: View with header section
    func withHeader(title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            Text(title)
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textPrimary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Divider()
                .background(Theme.Colors.divider)
            
            self
        }
        .dashboardPadding()
    }
    
    /// Create a section with consistent styling
    ///
    /// **AI Context**: This modifier creates a visually distinct section within
    /// a larger view, commonly used to group related content or separate
    /// different types of information.
    ///
    /// **Business Rules**:
    /// - Adds top and bottom spacing
    /// - Can include optional section title
    /// - Maintains consistent styling
    /// - Works with any view type
    ///
    /// **Performance Notes**:
    /// - VStack is highly optimized for vertical layouts
    /// - Minimal memory allocation
    /// - Efficient layout calculations
    ///
    /// **Edge Cases**:
    /// - Works with any view type
    /// - Optional title can be nil
    /// - Maintains accessibility for content
    ///
    /// - Parameters:
    ///   - title: Optional section title (defaults to nil)
    /// - Returns: View wrapped in styled section
    func section(title: String? = nil) -> some View {
        VStack(spacing: Theme.spacingSmall) {
            if let title = title {
                Text(title)
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            self
        }
        .padding(.vertical, Theme.spacingMedium)
    }
    
    /// Add a footer with action buttons
    ///
    /// **AI Context**: This modifier adds a footer section with action buttons,
    /// commonly used in dashboard views for navigation or additional actions.
    /// It provides a consistent pattern for footer actions.
    ///
    /// **Business Rules**:
    /// - Places buttons at bottom of view
    /// - Uses HStack for horizontal button layout
    /// - Provides appropriate spacing between buttons
    /// - Maintains consistent styling
    ///
    /// **Performance Notes**:
    /// - VStack is highly optimized for vertical layouts
    /// - HStack is highly optimized for horizontal layouts
    /// - Minimal memory allocation
    ///
    /// **Edge Cases**:
    /// - Works with any view type
    /// - Can accommodate multiple buttons
    /// - Maintains accessibility for button actions
    ///
    /// - Parameters:
    ///   - buttons: ViewBuilder for footer buttons
    /// - Returns: View with footer section
    @ViewBuilder
    func withFooter(@ViewBuilder buttons: @escaping () -> some View) -> some View {
        VStack(spacing: 0) {
            self
            Divider()
                .background(Theme.Colors.divider)
            HStack {
                Spacer()
                buttons()
                Spacer()
            }
            .padding(.vertical, Theme.spacingSmall)
            .padding(.horizontal, Theme.spacingMedium)
        }
    }
}