import SwiftUI

// MARK: - Reusable Tooltip Components

/// Styled tooltip container matching the 90-day chart tooltip appearance.
/// Reused by calendar and yearly charts for visual consistency.
struct TooltipContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.Design.blockCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Design.blockCornerRadius)
                    .stroke(Theme.Colors.divider.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Theme.Colors.divider.opacity(0.25), radius: 6, x: 0, y: 3)
    }
}

/// Tooltip row: colour dot + identifier + hours.
struct TooltipRow: View {
    let color: Color
    let emoji: String?
    let name: String
    let hours: Double
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            if let emoji = emoji {
                Text(emoji)
                    .font(Theme.Fonts.caption)
            }
            Text(name)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(String(format: "%.1fh", hours))
                .font(Theme.Fonts.caption.weight(.semibold))
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}

/// Tooltip divider matching the 90-day chart style.
struct TooltipDivider: View {
    var body: some View {
        Divider()
            .background(Theme.Colors.divider.opacity(0.4))
            .padding(.vertical, 1)
    }
}

// MARK: - Distribution Chart Row Frames

/// Coordinate space name for the yearly distribution charts' scrollable list.
/// Anchored to the scroll view so row frames resolve viewport-relative
/// (following scroll position) — the tooltip can then position itself directly
/// from the reported rows without extra math. Kept outside the generic view
/// because generic types cannot hold static stored properties.
private enum DistributionScrollSpace {
    static let name = "DistributionChartScrollView"
}

/// Preference key used by the yearly distribution charts to track each row's
/// frame within the scrollable chart content. `DistributionChartScrollView`
/// reads the accumulated frames so the floating tooltip can be positioned over
/// the hovered row even after the internal scroll view has been scrolled.
struct DistributionRowFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Trend Chart Components

/// Legend for the dual-bar trend charts: solid swatch = last 90 days,
/// light swatch = yearly average per 90-day period.
struct TrendChartLegend: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.xxs) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.textPrimary)
                    .frame(width: 12, height: 5)
                Text("Last 90 days")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            HStack(spacing: Theme.Spacing.xxs) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.textPrimary.opacity(0.3))
                    .frame(width: 12, height: 5)
                Text("Yearly avg")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(.bottom, Theme.Spacing.xs)
    }
}

/// A pair of directly comparable horizontal bars for trend charts.
///
/// Top bar (solid): hours in the rolling last 90 days.
/// Bottom bar (light): yearly average per 90-day period (360-day total ÷ 4).
/// Both scale against the same `maxHours` so relative lengths are meaningful.
struct TrendBarPair: View {
    let recentHours: Double
    let averageHours: Double
    let maxHours: Double
    let availableWidth: CGFloat
    /// Base colour for both bars; the average bar is rendered at low opacity.
    let color: Color
    let isHovered: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Recent (solid) bar
            Rectangle()
                .fill(color.opacity(isHovered ? 1.0 : 0.85))
                .frame(
                    width: availableWidth * CGFloat(min(recentHours / maxHours, 1)),
                    height: isHovered ? 5 : 4
                )
                .cornerRadius(Theme.Design.blockCornerRadius)
            
            // Yearly average (light) bar
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(
                    width: availableWidth * CGFloat(min(averageHours / maxHours, 1)),
                    height: isHovered ? 5 : 4
                )
                .cornerRadius(Theme.Design.blockCornerRadius)
        }
        .animation(Theme.Design.spring, value: isHovered)
    }
}

/// A scrollable, bounded row list for the yearly distribution charts.
///
/// The list's content frames are published through `DistributionRowFrameKey`
/// in the `scrollSpace` coordinate space (anchored to the ScrollView), so
/// tooltips can track rows while scrolling. The row content (name, bar, hours)
/// is provided by the `rowContent` closure, keeping the shared
/// scroll/tooltip mechanics in one place.
struct DistributionChartScrollView<RowContent: View, RowData: Identifiable>: View {
    let data: [RowData]
    let rowHeight: CGFloat
    let spacing: CGFloat
    @ViewBuilder var rowContent: (RowData, Int) -> RowContent

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: spacing) {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, rowData in
                    rowContent(rowData, index)
                        .frame(height: rowHeight)
                        .id(index)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: DistributionRowFrameKey.self,
                                    value: [index: geo.frame(in: .named(DistributionScrollSpace.name))]
                                )
                            }
                        )
                }
            }
        }
        // Anchor the named space to the ScrollView so row frames resolve
        // viewport-relative (following scroll position) — the tooltip can then
        // position itself directly from the reported rows without extra math.
        .coordinateSpace(name: DistributionScrollSpace.name)
    }
}
