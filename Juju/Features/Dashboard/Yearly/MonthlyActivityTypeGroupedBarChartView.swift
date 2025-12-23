//
//  MonthlyActivityTypeGroupedBarChartView.swift
//  Juju
//
//  Created by Hayden on 20/12/2025.
//

import SwiftUI

/// Displays a horizontal grouped bar chart showing activity type distribution across months for the current year.
/// Shows months on Y-axis with grouped bars for each activity type using consistent accent color.
/// Only displays active (non-archived) activity types.
struct MonthlyActivityTypeGroupedBarChartView: View {
    let data: [MonthlyActivityTypeChartData]
    @State private var hoveredIndex: Int? = nil
    
    static let sampleData: [MonthlyActivityTypeChartData] = [
        MonthlyActivityTypeChartData(
            month: "January",
            monthNumber: 1,
            activityBreakdown: [
                MonthlyActivityTypeDataPoint(activityName: "Writing", emoji: "✍️", totalHours: 20.0, percentage: 40.0),
                MonthlyActivityTypeDataPoint(activityName: "Editing", emoji: "✂️", totalHours: 15.0, percentage: 30.0),
                MonthlyActivityTypeDataPoint(activityName: "Planning", emoji: "🧠", totalHours: 10.0, percentage: 20.0),
                MonthlyActivityTypeDataPoint(activityName: "Admin", emoji: "🗂️", totalHours: 5.0, percentage: 10.0)
            ],
            totalHours: 50.0
        ),
        MonthlyActivityTypeChartData(
            month: "February", 
            monthNumber: 2,
            activityBreakdown: [
                MonthlyActivityTypeDataPoint(activityName: "Writing", emoji: "✍️", totalHours: 18.0, percentage: 36.0),
                MonthlyActivityTypeDataPoint(activityName: "Editing", emoji: "✂️", totalHours: 16.0, percentage: 32.0),
                MonthlyActivityTypeDataPoint(activityName: "Planning", emoji: "🧠", totalHours: 12.0, percentage: 24.0),
                MonthlyActivityTypeDataPoint(activityName: "Admin", emoji: "🗂️", totalHours: 4.0, percentage: 8.0)
            ],
            totalHours: 50.0
        )
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if data.isEmpty {
                MonthlyActivityTypeNoDataPlaceholder(minHeight: 200)
            } else {
                GeometryReader { geometry in
                    let maxHours = data.map { $0.totalHours }.max() ?? 1
                    
                    // Calculate dynamic widths based on available space
                    let monthLabelWidth = min(30, geometry.size.width * 0.08)
                    let hourLabelWidth = min(60, geometry.size.width * 0.12)
                    let chartWidth = max(100, geometry.size.width - monthLabelWidth - hourLabelWidth - 20)
                    
                    // Calculate dynamic height per item
                    let totalSpacing = CGFloat(data.prefix(12).count - 1) * 12
                    let availableHeight = geometry.size.height - totalSpacing
                    let itemHeight = max(28, availableHeight / CGFloat(data.prefix(12).count))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(data.prefix(12).enumerated()), id: \.offset) { index, monthData in
                            HStack(spacing: 8) {
                                // Month label - left aligned with minimal padding
                                Text(monthData.month.prefix(3).uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .frame(width: monthLabelWidth, alignment: .trailing)
                                    .padding(.leading, 2)
                                
                                // Grouped bars - left aligned
                                HStack(spacing: 4) {
                                    ForEach(monthData.activityBreakdown) { activity in
                                        let width = chartWidth * CGFloat(activity.totalHours / maxHours) * 0.8 // Reduced width by 20%
                                        
                                        ZStack(alignment: .center) {
                                            Rectangle()
                                                .fill(Theme.Colors.accentColor)
                                                .frame(width: max(6, width), height: 6)
                                                .cornerRadius(3)
                                            
                                            Text(activity.emoji)
                                                .font(.system(size: 21, design: .rounded)) // 1.5x larger (14 * 1.5 = 21)
                                                .offset(x: 0, y: 0) // Centered both horizontally and vertically
                                        }
                                    }
                                }
                                .frame(width: chartWidth)
                                .alignmentGuide(.leading) { _ in 0 } // Ensure left alignment
                                
                                // Total hours
                                Text("\(monthData.totalHours, specifier: "%.1f") h")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .frame(width: hourLabelWidth, alignment: .leading)
                            }
                            .frame(height: itemHeight)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

// MARK: - No Data Placeholder
struct MonthlyActivityTypeNoDataPlaceholder: View {
    var minHeight: CGFloat = 200
    var body: some View {
        VStack(spacing: Theme.spacingMedium) {
            Text("No activity data yet")
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textPrimary)
            
            Text("Start tracking sessions with activity types to see your monthly distribution")
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
    MonthlyActivityTypeGroupedBarChartView(
        data: MonthlyActivityTypeGroupedBarChartView.sampleData
    )
    .frame(width: 600, height: 800) // Standard preview size
    .background(Theme.Colors.background)
    .padding()
}
