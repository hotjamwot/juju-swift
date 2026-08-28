//
//  YearlyProjectBarChartView.swift
//  Juju
//
//  Created by Hayden on 16/12/2025.
//

import SwiftUI

/// Displays a dual-bar trend chart for projects: for each project, a solid bar
/// shows hours logged in the rolling last 90 days and a lighter bar shows the
/// yearly average per 90-day period (last 360 days ÷ 4). Comparing the two
/// bars reveals whether recent focus is above or below the yearly norm.
/// Purely visual — no on-chart numbers. Hovering anywhere on a row shows a
/// tooltip with the values and trend delta.
/// Renders ALL projects; when there are more than fit the card, the list
/// scrolls internally instead of cutting projects off.
struct YearlyProjectBarChartView: View {
    let data: [YearlyProjectChartData]
    @State private var hoveredIndex: Int? = nil
    @State private var showTooltip: Bool = false
    @State private var rowFrames: [Int: CGRect] = [:]
    
    static let sampleData: [YearlyProjectChartData] = [
        YearlyProjectChartData(projectName: "Writing Project", color: "#E100FF", emoji: "✍️", recent90DaysHours: 62.5, yearlyAvgPer90Days: 50.0),
        YearlyProjectChartData(projectName: "Editing", color: "#FF6B6B", emoji: "✂️", recent90DaysHours: 30.0, yearlyAvgPer90Days: 37.5),
        YearlyProjectChartData(projectName: "Planning", color: "#4ECDC4", emoji: "🧠", recent90DaysHours: 28.0, yearlyAvgPer90Days: 25.0),
        YearlyProjectChartData(projectName: "Admin", color: "#95E1D3", emoji: "🗂️", recent90DaysHours: 8.0, yearlyAvgPer90Days: 12.5)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if data.isEmpty {
                NoDataPlaceholder(minHeight: 200)
            } else {
                // Legend is rendered ONCE by the parent merged Trends card
                // (OverviewDashboardView) — both charts share one container.
                // Scale both bars against the largest value of either kind.
                let maxHours = data.map { max($0.recent90DaysHours, $0.yearlyAvgPer90Days) }.max() ?? 1
                
                DistributionChartScrollView(
                    data: data,
                    rowHeight: Theme.DashboardLayout.distributionRowMinHeight,
                    spacing: Theme.Spacing.sm
                ) { projectData, index in
                    row(for: projectData, index: index, maxHours: maxHours)
                }
                .onPreferenceChange(DistributionRowFrameKey.self) { frames in
                    rowFrames = frames
                }
                .padding(.vertical, Theme.Spacing.xs)
                // Keep the tooltip anchored to the chart card.
                .overlay {
                    GeometryReader { proxy in
                        if showTooltip, let index = hoveredIndex, index < data.count,
                           let frame = rowFrames[index] {
                            tooltipContent(for: data[index])
                                .fixedSize()
                                .position(
                                    x: min(max(frame.midX, 90), max(90, proxy.size.width - 90)),
                                    y: frame.midY - 20
                                )
                                .allowsHitTesting(false)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                }
            }
        }
        .padding(Theme.DashboardLayout.chartPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Presentation-only view: card chrome is applied by the parent merged
        // Trends card (see OverviewDashboardView) so both charts share one surface.
        .animation(Theme.Design.spring, value: hoveredIndex)
    }
    
    // MARK: - Row
    
    @ViewBuilder
    private func row(for projectData: YearlyProjectChartData, index: Int, maxHours: Double) -> some View {
        GeometryReader { geometry in
            // Name column (160) + HStack spacing (Theme.spacingMedium = 16) = 176;
            // the rest belongs to the bars. Keep in sync with the spacing constant
            // or the longest bar overflows the row's right edge and gets clipped.
            let chartWidth = geometry.size.width - 176
            HStack(spacing: Theme.spacingMedium) {
                HStack(spacing: Theme.spacingSmall) {
                    Text(projectData.emoji)
                        .font(Theme.Fonts.header)
                    
                    Text(projectData.projectName)
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                }
                .frame(width: 160, alignment: .leading)
                
                TrendBarPair(
                    recentHours: projectData.recent90DaysHours,
                    averageHours: projectData.yearlyAvgPer90Days,
                    maxHours: maxHours,
                    availableWidth: max(0, chartWidth),
                    color: projectData.colorSwiftUI,
                    isHovered: hoveredIndex == index
                )
            }
            // The whole row is the hover target — bars included.
            .frame(maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    hoveredIndex = index
                    showTooltip = true
                } else if hoveredIndex == index {
                    showTooltip = false
                    hoveredIndex = nil
                }
            }
        }
    }
    
    // MARK: - Tooltip
    
    /// Percentage difference of the last 90 days vs the yearly average.
    /// Nil when there is no baseline to compare against.
    private func trendDelta(for projectData: YearlyProjectChartData) -> Double? {
        guard projectData.yearlyAvgPer90Days > 0 else { return nil }
        return (projectData.recent90DaysHours - projectData.yearlyAvgPer90Days) / projectData.yearlyAvgPer90Days * 100
    }
    
    /// Numbers-only tooltip: the two comparable values plus the trend delta.
    @ViewBuilder
    private func tooltipContent(for projectData: YearlyProjectChartData) -> some View {
        TooltipContainer {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(projectData.emoji)
                        .font(Theme.Fonts.caption)
                    Text(projectData.projectName)
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                
                HStack(spacing: 6) {
                    Text("Last 90 days")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer(minLength: 8)
                    Text(String(format: "%.1fh", projectData.recent90DaysHours))
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                
                HStack(spacing: 6) {
                    Text("Yearly avg")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer(minLength: 8)
                    Text(String(format: "%.1fh", projectData.yearlyAvgPer90Days))
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                if let delta = trendDelta(for: projectData) {
                    HStack(spacing: 4) {
                        Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                            .font(Theme.Fonts.caption)
                        Text(String(format: "%.0f%% vs yearly avg", abs(delta)))
                            .font(Theme.Fonts.caption)
                    }
                    .foregroundColor(delta >= 0 ? Theme.Colors.positive : Theme.Colors.negative)
                }
            }
        }
    }
}