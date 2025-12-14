import SwiftUI
import Charts

/// Monthly Activity Grouped Bar Chart View
/// Displays a grouped bar chart showing the split of time between different activity types for each month
struct MonthlyActivityGroupedBarChartView: View {
    let groups: [MonthlyActivityGroup]
    
    @State private var selectedMonth: MonthlyActivityGroup?
    @State private var selectedActivity: ActivityBarData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            HStack {
                Spacer()
                
                if let selected = selectedMonth {
                    Text("Selected: \(selected.month)")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }
            
            if groups.isEmpty {
                Text("No data available")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
            } else {
                chartView
            }
        }
    }
    
    @ViewBuilder
    private var chartView: some View {
        let maxHours = groups.reduce(0) { maxSoFar, group in
            let groupMax = group.activities.reduce(0) { maxActivity, activity in
                max(maxActivity, activity.totalHours)
            }
            return max(maxSoFar, groupMax)
        }
        
        VStack(spacing: Theme.spacingLarge) {
            // Chart area
            GeometryReader { geometry in
                let chartWidth = max(100, geometry.size.width) // Ensure minimum width
                let chartHeight: CGFloat = 250
                let barWidth: CGFloat = 20
                let groupSpacing: CGFloat = 40
                let maxValue = max(maxHours, 1) // Ensure we don't divide by zero
                
                // Y-axis labels
                VStack(spacing: 0) {
                    ForEach(0..<6) { index in
                        HStack {
                            Text("\(String(format: "%.0f", maxValue * Double(5 - index) / 5.0))")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .frame(width: 40, alignment: .trailing)
                            
                            Rectangle()
                                .fill(Theme.Colors.divider.opacity(0.3))
                                .frame(height: 1)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .position(x: 20, y: chartHeight / 2)
                
                // Chart content
                VStack(spacing: 0) {
                    HStack(spacing: groupSpacing) {
                        ForEach(groups) { group in
                            MonthGroupView(
                                group: group,
                                maxHours: maxValue,
                                chartHeight: chartHeight,
                                barWidth: barWidth,
                                isSelected: selectedMonth?.id == group.id,
                                selectedActivity: selectedActivity,
                                onSelect: {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                        selectedMonth = selectedMonth?.id == group.id ? nil : group
                                    }
                                },
                                onActivitySelect: { activity in
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                        selectedActivity = selectedActivity?.id == activity.id ? nil : activity
                                    }
                                }
                            )
                        }
                    }
                    .frame(height: chartHeight)
                    
                    // X-axis labels (month names)
                    HStack(spacing: groupSpacing) {
                        ForEach(groups) { group in
                            Text(group.month.prefix(3).uppercased())
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .rotationEffect(.degrees(-45))
                                .frame(width: barWidth * CGFloat(group.activities.count) + CGFloat(max(1, group.activities.count - 1)) * 8)
                        }
                    }
                    .padding(.top, Theme.spacingSmall)
                }
                .padding(.leading, 60) // Space for Y-axis labels
            }
            .frame(maxHeight: .infinity)
            
            // Legend
            let legendActivities = selectedMonth?.activities ?? (groups.first?.activities ?? [])
            ActivityLegendView(
                activities: legendActivities,
                selectedActivity: $selectedActivity
            )
        }
    }
}

// MARK: - Month Group View
struct MonthGroupView: View {
    let group: MonthlyActivityGroup
    let maxHours: Double
    let chartHeight: CGFloat
    let barWidth: CGFloat
    let isSelected: Bool
    let selectedActivity: ActivityBarData?
    let onSelect: () -> Void
    let onActivitySelect: (ActivityBarData) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Bars
            HStack(spacing: 8) {
                ForEach(group.activities) { activity in
                    ActivityBarView(
                        activity: activity,
                        maxHours: maxHours,
                        chartHeight: chartHeight,
                        barWidth: barWidth,
                        isSelected: selectedActivity?.id == activity.id,
                        onSelect: {
                            onActivitySelect(activity)
                        }
                    )
                }
            }
            
            // Month label
            Text(group.month.prefix(3))
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.top, Theme.spacingSmall)
        }
        .padding(.horizontal, Theme.spacingExtraSmall)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Theme.Colors.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Activity Bar View
struct ActivityBarView: View {
    let activity: ActivityBarData
    let maxHours: Double
    let chartHeight: CGFloat
    let barWidth: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var barHeight: CGFloat {
        let percentage = activity.totalHours / maxHours
        return CGFloat(percentage) * chartHeight
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Bar
            RoundedRectangle(cornerRadius: 4)
                .fill(activity.color)
                .frame(width: barWidth, height: max(4, barHeight))
                .scaleEffect(y: isSelected ? 1.05 : 1.0, anchor: .bottom)
                .animation(.easeInOut(duration: 0.3), value: isSelected)
                .shadow(color: isSelected ? activity.color.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect()
                }
            
            // Value label
            Text("\(String(format: "%.1f", activity.totalHours))")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.top, Theme.spacingExtraSmall)
        }
    }
}

// MARK: - Activity Legend View
struct ActivityLegendView: View {
    let activities: [ActivityBarData]
    @Binding var selectedActivity: ActivityBarData?
    
    var body: some View {
        VStack(spacing: Theme.spacingSmall) {
            Text("Activity Types")
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.bottom, Theme.spacingSmall)
            
            HStack(spacing: Theme.spacingMedium) {
                ForEach(activities) { activity in
                    HStack(spacing: Theme.spacingSmall) {
                        Circle()
                            .fill(activity.color)
                            .frame(width: 10, height: 10)
                            .opacity(selectedActivity == nil || selectedActivity?.id == activity.id ? 1.0 : 0.3)
                        
                        Text(activity.emoji)
                            .font(.system(size: 12))
                        
                        Text(activity.activityName)
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .opacity(selectedActivity == nil || selectedActivity?.id == activity.id ? 1.0 : 0.6)
                    }
                    .padding(.horizontal, Theme.spacingSmall)
                    .padding(.vertical, Theme.spacingExtraSmall)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedActivity?.id == activity.id ? Theme.Colors.accentColor.opacity(0.1) : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedActivity = selectedActivity?.id == activity.id ? nil : activity
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.spacingMedium)
    }
}

// MARK: - Preview
#Preview {
    let mockGroups: [MonthlyActivityGroup] = [
        MonthlyActivityGroup(
            month: "January",
            monthNumber: 1,
            activities: [
                ActivityBarData(activityName: "Creative", emoji: "🎨", totalHours: 40, color: Color(hex: "#FF6B6B")),
                ActivityBarData(activityName: "Analytical", emoji: "🧠", totalHours: 30, color: Color(hex: "#4ECDC4")),
                ActivityBarData(activityName: "Administrative", emoji: "📝", totalHours: 20, color: Color(hex: "#45B7D1"))
            ]
        ),
        MonthlyActivityGroup(
            month: "February",
            monthNumber: 2,
            activities: [
                ActivityBarData(activityName: "Creative", emoji: "🎨", totalHours: 35, color: Color(hex: "#FF6B6B")),
                ActivityBarData(activityName: "Analytical", emoji: "🧠", totalHours: 35, color: Color(hex: "#4ECDC4")),
                ActivityBarData(activityName: "Administrative", emoji: "📝", totalHours: 25, color: Color(hex: "#45B7D1")),
                ActivityBarData(activityName: "Learning", emoji: "📚", totalHours: 10, color: Color(hex: "#96CEB4"))
            ]
        ),
        MonthlyActivityGroup(
            month: "March",
            monthNumber: 3,
            activities: [
                ActivityBarData(activityName: "Creative", emoji: "🎨", totalHours: 45, color: Color(hex: "#FF6B6B")),
                ActivityBarData(activityName: "Analytical", emoji: "🧠", totalHours: 25, color: Color(hex: "#4ECDC4")),
                ActivityBarData(activityName: "Administrative", emoji: "📝", totalHours: 15, color: Color(hex: "#45B7D1")),
                ActivityBarData(activityName: "Communication", emoji: "💬", totalHours: 15, color: Color(hex: "#FFEAA7"))
            ]
        )
    ]
    
    return MonthlyActivityGroupedBarChartView(groups: mockGroups)
        .frame(width: 1000, height: 500)
        .background(Theme.Colors.background)
}
