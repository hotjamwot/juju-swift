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
/// On hover, shows a project breakdown tooltip matching the 90-day chart style.
struct YearlyActivityTypeBarChartView: View {
    let data: [ActivityDistributionItem]
    @State private var hoveredIndex: Int? = nil
    @State private var showTooltip: Bool = false
    
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
                GeometryReader { geometry in
                    let maxHours = data.map { $0.totalHours }.max() ?? 1
                    let chartWidth = geometry.size.width - 220
                    
                    let maxVisibleActivityTypes = 10
                    let visibleData = Array(data.prefix(maxVisibleActivityTypes))
                    let hiddenData = Array(data.dropFirst(maxVisibleActivityTypes))
                    
                    let totalSpacing = CGFloat(visibleData.count - 1) * Theme.Spacing.sm
                    let availableHeight = geometry.size.height - totalSpacing
                    let itemHeight = max(30, availableHeight / CGFloat(visibleData.count))
                    
                    ZStack(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            ForEach(Array(visibleData.enumerated()), id: \.offset) { index, activityData in
                                HStack(spacing: Theme.spacingMedium) {
                                    HStack(spacing: Theme.spacingSmall) {
                                        Image(systemName: activityData.sfSymbol)
                                            .font(.system(size: 16, design: .rounded))
                                        
                                        Text(activityData.activityName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 160, alignment: .leading)
                                    
                                    Rectangle()
                                        .fill(Theme.Colors.accentColor.opacity(hoveredIndex == index ? 1.0 : 0.85))
                                        .frame(width: chartWidth * CGFloat(activityData.totalHours / maxHours), height: 6)
                                        .cornerRadius(3)
                                        .animation(.easeInOut(duration: Theme.Design.animationDuration), value: hoveredIndex)
                                    
                                    Text("\(activityData.totalHours, specifier: "%.1f") h")
                                        .font(Theme.Fonts.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                        .frame(width: 40, alignment: .trailing)
                                }
                                .frame(height: itemHeight)
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
                        
                        // Tooltip overlay
                        if showTooltip, let index = hoveredIndex, index < visibleData.count {
                            let activityData = visibleData[index]
                            tooltipContent(for: activityData)
                                .fixedSize()
                                .position(x: geometry.size.width * 0.35, y: CGFloat(index) * (itemHeight + Theme.Spacing.sm) + itemHeight / 2 - 20)
                                .allowsHitTesting(false)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        
                        // Hidden activity types summary
                        if !hiddenData.isEmpty {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    HStack(spacing: Theme.spacingSmall) {
                                        Text("Activity types not shown:")
                                            .font(Theme.Fonts.caption)
                                            .foregroundColor(Theme.Colors.textSecondary)
                                        
                                        Text(hiddenData.map { $0.activityName }.joined(separator: ", "))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: geometry.size.width * 0.45)
                                    .padding(.bottom, 10)
                                }
                            }
                            .frame(height: itemHeight)
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
        }
        .padding(Theme.DashboardLayout.chartPadding)
        .cornerRadius(Theme.DashboardLayout.chartCornerRadius)
    }
    
    // MARK: - Tooltip
    
    @ViewBuilder
    private func tooltipContent(for activityData: ActivityDistributionItem) -> some View {
        TooltipContainer {
            VStack(alignment: .leading, spacing: 4) {
                Text(activityData.activityName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(String(format: "%.1fh total", activityData.totalHours))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.Colors.accentColor)
                
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

// MARK: - Preview
#Preview {
    return YearlyActivityTypeBarChartView_PreviewsContent()
                .frame(width: 540, height: 400)
        .background(Theme.Colors.background)
        .padding()
}

struct YearlyActivityTypeBarChartView_PreviewsContent: View {
    @StateObject var chartDataPreparer = ChartDataPreparer()
    @StateObject var sessionManager = SessionManager.shared
    @StateObject var projectsViewModel = ProjectsViewModel.shared
    
    var body: some View {
        YearlyActivityTypeBarChartView(
            data: chartDataPreparer.yearlyActivityTypeTotals()
        )
        .onAppear {
            Task {
                await projectsViewModel.loadProjects()
                await sessionManager.loadAllSessions()
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onChange(of: sessionManager.allSessions.count) { _ in
            Task {
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onChange(of: projectsViewModel.projects.count) { _ in
            Task {
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
    }
}