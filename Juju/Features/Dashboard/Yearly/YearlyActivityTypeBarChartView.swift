//
//  YearlyActivityTypeBarChartView.swift
//  Juju
//
//  Created by Hayden on 16/12/2025.
//

import SwiftUI

/// Displays a horizontal bar chart showing activity type distribution for the current year.
/// Shows activity names and emojis on the left with left-aligned bars on right using consistent accent color.
/// Only displays active (non-archived) activity types.
/// Renders ALL activity types; when there are more than fit the card, the list scrolls
/// internally instead of cutting activities off.
/// On hover, shows a project breakdown tooltip matching the 90-day chart style.
struct YearlyActivityTypeBarChartView: View {
    let data: [ActivityDistributionItem]
    @State private var hoveredIndex: Int? = nil
    @State private var showTooltip: Bool = false
    @State private var rowFrames: [Int: CGRect] = [:]
    
    static let sampleData: [ActivityDistributionItem] = [
        ActivityDistributionItem(activityName: "Writing", sfSymbol: "pencil", totalHours: 200.0, percentage: 40.0, projectBreakdown: []),
        ActivityDistributionItem(activityName: "Editing", sfSymbol: "scissors", totalHours: 150.0, percentage: 30.0, projectBreakdown: []),
        ActivityDistributionItem(activityName: "Planning", sfSymbol: "brain.head.profile", totalHours: 100.0, percentage: 20.0, projectBreakdown: []),
        ActivityDistributionItem(activityName: "Admin", sfSymbol: "folder", totalHours: 50.0, percentage: 10.0, projectBreakdown: [])
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
                ) { activityData, index in
                    row(for: activityData, index: index, maxHours: maxHours)
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
        .animation(Theme.Design.spring, value: hoveredIndex)
    }
    
    // MARK: - Row
    
    @ViewBuilder
    private func row(for activityData: ActivityDistributionItem, index: Int, maxHours: Double) -> some View {
        GeometryReader { geometry in
            let chartWidth = geometry.size.width - 220
            HStack(spacing: Theme.spacingMedium) {
                // Tooltip triggers only when hovering the item name, not the bar.
                HStack(spacing: Theme.spacingSmall) {
                    Image(systemName: activityData.sfSymbol)
                        .font(Theme.Fonts.header)
                    
                    Text(activityData.activityName)
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
                    .fill(Theme.Colors.textPrimary.opacity(hoveredIndex == index ? 1.0 : 0.85))
                    .frame(width: max(0, chartWidth) * CGFloat(activityData.totalHours / maxHours), height: hoveredIndex == index ? 8 : 6)
                    .animation(Theme.Design.spring, value: hoveredIndex)
                    .cornerRadius(Theme.Design.blockCornerRadius)
                
                Text("\(activityData.totalHours, specifier: "%.1f") h")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 40, alignment: .trailing)
            }
            .frame(maxHeight: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Tooltip
    
    @ViewBuilder
    private func tooltipContent(for activityData: ActivityDistributionItem) -> some View {
        TooltipContainer {
            VStack(alignment: .leading, spacing: 4) {
                Text(activityData.activityName)
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(String(format: "%.1fh total", activityData.totalHours))
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                if !activityData.projectBreakdown.isEmpty {
                    TooltipDivider()
                    
                    ForEach(activityData.projectBreakdown, id: \.projectName) { proj in
                        TooltipRow(
                            color: Color(hex: proj.color),
                            emoji: proj.emoji,
                            name: proj.projectName,
                            hours: proj.hours
                        )
                    }
                }
            }
        }
    }
}

// MARK: - No Data Placeholder
struct NoDataPlaceholder: View {
    var minHeight: CGFloat = 200
    var body: some View {
        VStack(spacing: Theme.spacingMedium) {
            Text("No activity data yet")
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textPrimary)
            
            Text("Start tracking sessions with activity types to see your distribution")
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.DashboardLayout.chartCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.DashboardLayout.chartCornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: Theme.DashboardLayout.chartBorderWidth)
        )
    }
}