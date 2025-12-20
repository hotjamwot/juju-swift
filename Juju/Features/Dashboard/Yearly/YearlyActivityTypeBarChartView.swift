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
struct YearlyActivityTypeBarChartView: View {
    let data: [YearlyActivityTypeChartData]
    @State private var hoveredIndex: Int? = nil
    
    static let sampleData: [YearlyActivityTypeChartData] = [
        YearlyActivityTypeChartData(activityName: "Writing", emoji: "✍️", totalHours: 200.0, percentage: 40.0),
        YearlyActivityTypeChartData(activityName: "Editing", emoji: "✂️", totalHours: 150.0, percentage: 30.0),
        YearlyActivityTypeChartData(activityName: "Planning", emoji: "🧠", totalHours: 100.0, percentage: 20.0),
        YearlyActivityTypeChartData(activityName: "Admin", emoji: "🗂️", totalHours: 50.0, percentage: 10.0)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if data.isEmpty {
                NoDataPlaceholder(minHeight: 200)
            } else {
                GeometryReader { geometry in
                    let maxHours = data.map { $0.totalHours }.max() ?? 1
                    let chartWidth = geometry.size.width - 220 // Space for labels and hour count
                    
                    // Limit to 10 activity types to fit in the frame
                    let maxVisibleActivityTypes = 10
                    let visibleData = Array(data.prefix(maxVisibleActivityTypes))
                    let hiddenData = Array(data.dropFirst(maxVisibleActivityTypes))
                    
                    // Calculate dynamic height per item to utilize full frame height
                    let totalSpacing = CGFloat(visibleData.count - 1) * 12
                    let availableHeight = geometry.size.height - totalSpacing
                    let itemHeight = max(28, availableHeight / CGFloat(visibleData.count))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(visibleData.enumerated()), id: \.offset) { index, activityData in
                            HStack(spacing: Theme.spacingMedium) {
                                // Activity label with emoji (left aligned, smaller font)
                                HStack(spacing: Theme.spacingSmall) {
                                    Text(activityData.emoji)
                                        .font(.system(size: 16, design: .rounded))
                                    
                                    Text(activityData.activityName)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .lineLimit(1)
                                }
                                .frame(width: 160, alignment: .leading)
                                
                                // Progress bar using consistent accent color (no individual colors per activity type)
                                Rectangle()
                                    .fill(Theme.Colors.accentColor) // Use consistent accent color for all bars
                                    .frame(width: chartWidth * CGFloat(activityData.totalHours / maxHours), height: 6)
                                    .cornerRadius(3)
                                    .scaleEffect(hoveredIndex == index ? CGSize(width: 1.05, height: 1.2) : CGSize(width: 1, height: 1))
                                    .animation(.easeInOut(duration: Theme.Design.animationDuration), value: hoveredIndex)
                                    .shadow(color: Theme.Colors.accentColor.opacity(0.4), radius: 8, x: 0, y: 2)
                                    .onHover { hovering in
                                        hoveredIndex = hovering ? index : nil
                                    }
                                    .help("""
                                        Activity: \(activityData.activityName)
                                        Total: \(activityData.totalHours, specifier: "%.1f") h (\(activityData.percentage, specifier: "%.1f") %)
                                        """)
                                
                                // Hour count right after bar
                                Text("\(activityData.totalHours, specifier: "%.1f") h")
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .frame(height: itemHeight)
                        }
                    }
                    
                    // Show hidden activity types summary as overlay at bottom-right if there are more than 10
                    if !hiddenData.isEmpty {
                        VStack {
                            Spacer() // Push to bottom
                            HStack {
                                Spacer() // Push to right edge
                                HStack(spacing: Theme.spacingSmall) {
                                    Text("Activity types not shown:")
                                        .font(Theme.Fonts.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                    
                                    Text(hiddenData.map { $0.activityName }.joined(separator: ", "))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: geometry.size.width * 0.45) // Limited to 45% width only
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
                .frame(width: 540, height: 400) // Matches yearly layout: 1200 * 0.45 = 540 width, approx 400 height for bottom-right chart
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
