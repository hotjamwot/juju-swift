//
//  YearlyProjectBarChartView.swift
//  Juju
//
//  Created by Hayden on 16/12/2025.
//

import SwiftUI

/// Displays a horizontal bar chart showing project distribution for the current year.
/// Shows project names and emojis on the left with left-aligned bars on the right.
/// Renders ALL projects; when there are more than fit the card, the list scrolls
/// internally instead of cutting projects off.
/// On hover, shows an activity type breakdown tooltip matching the 90-day chart style.
struct YearlyProjectBarChartView: View {
    let data: [YearlyProjectChartData]
    @State private var hoveredIndex: Int? = nil
    @State private var showTooltip: Bool = false
    @State private var rowFrames: [Int: CGRect] = [:]
    
    static let sampleData: [YearlyProjectChartData] = [
        YearlyProjectChartData(projectName: "Writing Project", color: "#E100FF", emoji: "✍️", totalHours: 200.0, percentage: 40.0, activityBreakdown: []),
        YearlyProjectChartData(projectName: "Editing", color: "#FF6B6B", emoji: "✂️", totalHours: 150.0, percentage: 30.0, activityBreakdown: []),
        YearlyProjectChartData(projectName: "Planning", color: "#4ECDC4", emoji: "🧠", totalHours: 100.0, percentage: 20.0, activityBreakdown: []),
        YearlyProjectChartData(projectName: "Admin", color: "#95E1D3", emoji: "🗂️", totalHours: 50.0, percentage: 10.0, activityBreakdown: [])
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if data.isEmpty {
                NoDataPlaceholder(minHeight: 200)
            } else {
                let maxHours = data.map { $0.totalHours }.max() ?? 1
                
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
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.DashboardLayout.chartCornerRadius)
        .subtleShadow()
        .animation(.easeInOut(duration: Theme.Design.animationDuration), value: hoveredIndex)
    }
    
    // MARK: - Row
    
    @ViewBuilder
    private func row(for projectData: YearlyProjectChartData, index: Int, maxHours: Double) -> some View {
        GeometryReader { geometry in
            let chartWidth = geometry.size.width - 220
            HStack(spacing: Theme.spacingMedium) {
                // Tooltip triggers only when hovering the item name, not the bar.
                HStack(spacing: Theme.spacingSmall) {
                    Text(projectData.emoji)
                        .font(Theme.Fonts.header)
                    
                    Text(projectData.projectName)
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                }
                .frame(width: 160, alignment: .leading)
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
                
                Rectangle()
                    .fill(projectData.colorSwiftUI.opacity(hoveredIndex == index ? 1.0 : 0.85))
                    .frame(width: max(0, chartWidth) * CGFloat(projectData.totalHours / maxHours), height: 6)
                    .cornerRadius(Theme.Design.blockCornerRadius)
                
                Text("\(projectData.totalHours, specifier: "%.1f") h")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 40, alignment: .trailing)
            }
            .frame(maxHeight: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Tooltip
    
    @ViewBuilder
    private func tooltipContent(for projectData: YearlyProjectChartData) -> some View {
        TooltipContainer {
            VStack(alignment: .leading, spacing: 4) {
                Text(projectData.projectName)
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(String(format: "%.1fh total", projectData.totalHours))
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                if !projectData.activityBreakdown.isEmpty {
                    TooltipDivider()
                    
                    ForEach(projectData.activityBreakdown, id: \.activityName) { act in
                        HStack(spacing: 6) {
                            Image(systemName: act.sfSymbol)
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text(act.activityName)
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(String(format: "%.1fh", act.hours))
                                .font(Theme.Fonts.caption.weight(.semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
            }
        }
    }
}