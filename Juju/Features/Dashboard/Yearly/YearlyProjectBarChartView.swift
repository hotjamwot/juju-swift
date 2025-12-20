//
//  YearlyProjectBarChartView.swift
//  Juju
//
//  Created by Hayden on 16/12/2025.
//

import SwiftUI

/// Displays a horizontal bar chart showing project distribution for the current year.
/// Shows project names and emojis on the left with left-aligned bars on the right.
struct YearlyProjectBarChartView: View {
    let data: [YearlyProjectChartData]
    @State private var hoveredIndex: Int? = nil
    
    static let sampleData: [YearlyProjectChartData] = [
        YearlyProjectChartData(projectName: "Writing Project", color: "#E100FF", emoji: "✍️", totalHours: 200.0, percentage: 40.0),
        YearlyProjectChartData(projectName: "Editing", color: "#FF6B6B", emoji: "✂️", totalHours: 150.0, percentage: 30.0),
        YearlyProjectChartData(projectName: "Planning", color: "#4ECDC4", emoji: "🧠", totalHours: 100.0, percentage: 20.0),
        YearlyProjectChartData(projectName: "Admin", color: "#95E1D3", emoji: "🗂️", totalHours: 50.0, percentage: 10.0)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if data.isEmpty {
                NoDataPlaceholder(minHeight: 200)
            } else {
                GeometryReader { geometry in
                    let maxHours = data.map { $0.totalHours }.max() ?? 1
                    let chartWidth = geometry.size.width - 220 // Reduced space for labels and hour count
                    
                    // Limit to 13 projects to fit in the frame (increased from 10 due to extra space)
                    let maxVisibleProjects = 13
                    let visibleData = Array(data.prefix(maxVisibleProjects))
                    let hiddenData = Array(data.dropFirst(maxVisibleProjects))
                    
                    // Calculate dynamic height per item to utilize full frame height
                    let totalSpacing = CGFloat(visibleData.count - 1) * 12
                    let availableHeight = geometry.size.height - totalSpacing
                    let itemHeight = max(28, availableHeight / CGFloat(visibleData.count))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(visibleData.enumerated()), id: \.offset) { index, projectData in
                            HStack(spacing: Theme.spacingMedium) {
                                // Project label with emoji (left aligned, smaller font)
                                HStack(spacing: Theme.spacingSmall) {
                                    Text(projectData.emoji)
                                        .font(.system(size: 16, design: .rounded))
                                    
                                    Text(projectData.projectName)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .lineLimit(1)
                                }
                                .frame(width: 160, alignment: .leading) 
                                
                                // Progress bar (standalone, no background)
                                Rectangle()
                                    .fill(projectData.colorSwiftUI)
                                    .frame(width: chartWidth * CGFloat(projectData.totalHours / maxHours), height: 6)
                                    .cornerRadius(3)
                                    .scaleEffect(hoveredIndex == index ? CGSize(width: 1.05, height: 1.2) : CGSize(width: 1, height: 1))
                                    .animation(.easeInOut(duration: Theme.Design.animationDuration), value: hoveredIndex)
                                    .shadow(color: projectData.colorSwiftUI.opacity(0.4), radius: 8, x: 0, y: 2)
                                    .onHover { hovering in
                                        hoveredIndex = hovering ? index : nil
                                    }
                                    .help("""
                                        Project: \(projectData.projectName)
                                        Total: \(projectData.totalHours, specifier: "%.1f") h (\(projectData.percentage, specifier: "%.1f") %)
                                        """)
                                
                                // Hour count right after bar
                                Text("\(projectData.totalHours, specifier: "%.1f") h")
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .frame(width: 40, alignment: .trailing) 
                            }
                            .frame(height: itemHeight)
                        }
                    }
                    
                    // Show hidden projects summary as overlay at bottom-right if there are more than 13
                    if !hiddenData.isEmpty {
                        VStack {
                            Spacer() // Push to bottom
                            HStack {
                                Spacer() // Push to right edge
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
                .padding(.vertical, Theme.spacingExtraSmall)
            }
        }
        .padding(Theme.DashboardLayout.chartPadding)
        .cornerRadius(Theme.DashboardLayout.chartCornerRadius)
    }
}


// MARK: - Preview
#Preview {
    return YearlyProjectBarChartView_PreviewsContent()
                .frame(width: 660, height: 400) // Matches yearly layout: 1200 * 0.55 = 660 width, approx 400 height for top-right chart
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
            // Load data just like DashboardNativeSwiftChartsView does
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
            // Update chart data when session data changes
            Task {
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onChange(of: projectsViewModel.projects.count) { _ in
            // Update chart data when project data changes
            Task {
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
    }
}
