//
//  YearlyProjectBarChartView.swift
//  Juju
//
//  Created by Hayden on 16/12/2025.
//

import SwiftUI

/// Displays a horizontal bar chart showing project distribution for the current year.
/// Shows project names and emojis on the left with left-aligned bars on the right.
/// On hover, shows an activity type breakdown tooltip matching the 90-day chart style.
struct YearlyProjectBarChartView: View {
    let data: [YearlyProjectChartData]
    @State private var hoveredIndex: Int? = nil
    @State private var showTooltip: Bool = false
    @State private var tooltipPosition: CGPoint = .zero
    
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
                GeometryReader { geometry in
                    let maxHours = data.map { $0.totalHours }.max() ?? 1
                    let chartWidth = geometry.size.width - 220
                    
                    let maxVisibleProjects = 13
                    let visibleData = Array(data.prefix(maxVisibleProjects))
                    let hiddenData = Array(data.dropFirst(maxVisibleProjects))
                    
                    let totalSpacing = CGFloat(visibleData.count - 1) * Theme.Spacing.sm
                    let availableHeight = geometry.size.height - totalSpacing
                    let itemHeight = max(30, availableHeight / CGFloat(visibleData.count))
                    
                    ZStack(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            ForEach(Array(visibleData.enumerated()), id: \.offset) { index, projectData in
                                HStack(spacing: Theme.spacingMedium) {
                                    HStack(spacing: Theme.spacingSmall) {
                                        Text(projectData.emoji)
                                            .font(.system(size: 16, design: .rounded))
                                        
                                        Text(projectData.projectName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 160, alignment: .leading)
                                    
                                    Rectangle()
                                        .fill(projectData.colorSwiftUI.opacity(hoveredIndex == index ? 1.0 : 0.85))
                                        .frame(width: chartWidth * CGFloat(projectData.totalHours / maxHours), height: 6)
                                        .cornerRadius(3)
                                        .animation(.easeInOut(duration: Theme.Design.animationDuration), value: hoveredIndex)
                                    
                                    Text("\(projectData.totalHours, specifier: "%.1f") h")
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
                            let projectData = visibleData[index]
                            tooltipContent(for: projectData)
                                .fixedSize()
                                .position(x: geometry.size.width * 0.35, y: CGFloat(index) * (itemHeight + Theme.Spacing.sm) + itemHeight / 2 - 20)
                                .allowsHitTesting(false)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        
                        // Hidden projects summary
                        if !hiddenData.isEmpty {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    HStack(spacing: Theme.spacingSmall) {
                                        Text("Projects not shown:")
                                            .font(Theme.Fonts.caption)
                                            .foregroundColor(Theme.Colors.textSecondary)
                                        
                                        Text(hiddenData.map { $0.projectName }.joined(separator: ", "))
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
    private func tooltipContent(for projectData: YearlyProjectChartData) -> some View {
        TooltipContainer {
            VStack(alignment: .leading, spacing: 4) {
                Text(projectData.projectName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(String(format: "%.1fh total", projectData.totalHours))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.Colors.accentColor)
                
                if !projectData.activityBreakdown.isEmpty {
                    TooltipDivider()
                    
                    ForEach(projectData.activityBreakdown, id: \.activityName) { act in
                        HStack(spacing: 6) {
                            Image(systemName: act.sfSymbol)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text(act.activityName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(String(format: "%.1fh", act.hours))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
            }
        }
    }
}


// MARK: - Preview
#Preview {
    return YearlyProjectBarChartView_PreviewsContent()
                .frame(width: 660, height: 400)
        .background(Theme.Colors.background)
        .padding()
}

struct YearlyProjectBarChartView_PreviewsContent: View {
    @StateObject var chartDataPreparer = ChartDataPreparer()
    @StateObject var sessionManager = SessionManager.shared
    @StateObject var projectsViewModel = ProjectsViewModel.shared
    
    var body: some View {
        YearlyProjectBarChartView(
            data: chartDataPreparer.yearlyProjectTotals()
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