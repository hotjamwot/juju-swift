import SwiftUI
import Charts

/// Activity Distribution Bar Chart View
/// Displays a horizontal bar chart showing the main activity types used
struct ActivityDistributionBarChartView: View {
    let data: [ActivityTypeBarChartData]
    
    @State private var selectedActivity: ActivityTypeBarChartData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            HStack {
                Spacer()
                
                if let selected = selectedActivity {
                    Text("\(selected.emoji) \(selected.activityName)")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }
            
            if data.isEmpty {
                Text("No data available")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                chartView
            }
        }
    }
    
    @ViewBuilder
    private var chartView: some View {
        let totalHours = data.reduce(0, { $0 + $1.totalHours })
        
        VStack(spacing: Theme.spacingMedium) {
            ForEach(data) { activity in
                ActivityBarRowView(
                    activity: activity,
                    totalHours: totalHours,
                    isSelected: selectedActivity?.id == activity.id,
                    onSelect: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedActivity = selectedActivity?.id == activity.id ? nil : activity
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Activity Bar Row View
struct ActivityBarRowView: View {
    let activity: ActivityTypeBarChartData
    let totalHours: Double
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var barWidth: CGFloat {
        guard totalHours > 0 else { return 0 }
        let percentage = activity.totalHours / totalHours
        return CGFloat(percentage) * 100 // Scale to 100% width
    }
    
    var body: some View {
        HStack(spacing: Theme.spacingMedium) {
            // Activity info
            HStack(spacing: Theme.spacingSmall) {
                Text(activity.emoji)
                    .font(.system(size: 16, weight: .medium))
                
                Text(activity.activityName)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: 150, alignment: .leading)
            
            // Progress bar
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Colors.divider.opacity(0.3))
                    .frame(height: 16)
                
                // Progress bar
                RoundedRectangle(cornerRadius: 8)
                    .fill(activity.colorSwiftUI)
                    .frame(width: barWidth, height: 16)
                    .scaleEffect(x: isSelected ? 1.05 : 1.0, y: 1.0, anchor: .leading)
                    .animation(.easeInOut(duration: 0.3), value: isSelected)
                    .shadow(color: isSelected ? activity.colorSwiftUI.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity)
            
            // Hours and percentage
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", activity.totalHours))h")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("\(String(format: "%.1f", activity.percentage))%")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, Theme.spacingSmall)
        .padding(.vertical, Theme.spacingExtraSmall)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Theme.Colors.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .animation(.easeInOut(duration: 0.3), value: isSelected)
    }
}

// MARK: - Preview
#Preview {
    let mockData: [ActivityTypeBarChartData] = [
        ActivityTypeBarChartData(
            activityName: "Creative",
            emoji: "🎨",
            totalHours: 120,
            percentage: 45.0,
            color: Color(hex: "#FF6B6B")
        ),
        ActivityTypeBarChartData(
            activityName: "Analytical",
            emoji: "🧠",
            totalHours: 80,
            percentage: 30.0,
            color: Color(hex: "#4ECDC4")
        ),
        ActivityTypeBarChartData(
            activityName: "Administrative",
            emoji: "📝",
            totalHours: 40,
            percentage: 15.0,
            color: Color(hex: "#45B7D1")
        ),
        ActivityTypeBarChartData(
            activityName: "Learning",
            emoji: "📚",
            totalHours: 20,
            percentage: 7.5,
            color: Color(hex: "#96CEB4")
        ),
        ActivityTypeBarChartData(
            activityName: "Communication",
            emoji: "💬",
            totalHours: 10,
            percentage: 2.5,
            color: Color(hex: "#FFEAA7")
        )
    ]
    
    return ActivityDistributionBarChartView(data: mockData)
        .frame(width: 800, height: 400)
        .background(Theme.Colors.background)
}
