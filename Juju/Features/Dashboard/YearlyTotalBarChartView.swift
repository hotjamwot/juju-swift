import SwiftUI
import Charts
import Foundation

struct YearlyTotalBarChartView: View {
    let data: [ProjectChartData]
    
    var body: some View {
        if data.isEmpty {
            Text("No data for this year")
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 300)
        } else {
            // Sort data descending by total hours
            let sortedData = data.sorted { $0.totalHours > $1.totalHours }
            
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    Spacer(minLength: 0) // This will push content to center
                    
                    VStack(alignment: .leading, spacing: Theme.spacingMedium) {
                        ForEach(sortedData.indices, id: \.self) { index in
                            let projectData = sortedData[index]
                            let maxValue = sortedData.first?.totalHours ?? 1
                            let barWidth = (projectData.totalHours / maxValue) * (geometry.size.width - 150) // Adjusted for text space
                            
                            HStack(spacing: Theme.spacingMedium) {
                                HStack(spacing: Theme.spacingExtraSmall) {
                                    
                                    HStack(spacing: Theme.spacingSmall) {
                                        Text(projectData.emoji)
                                            .font(Theme.Fonts.body)
                                        
                                        Text(projectData.projectName)
                                            .font(Theme.Fonts.body)
                                            .foregroundColor(Theme.Colors.textPrimary)
                                    }
                                }
                                .frame(width: Theme.spacingLarge * 6, alignment: .leading)
                                
                                ZStack(alignment: .leading) {
                                    // Invisible background bar for left alignment (very transparent)
                                    Rectangle()
                                        .fill(Theme.Colors.divider.opacity(0.00)) // Almost invisible for alignment
                                        .frame(height: Theme.Design.cornerRadius + 2)
                                        .cornerRadius(Theme.Design.cornerRadius)
                                    
                                    // Main colored bar
                                    Rectangle()
                                        .fill(Color(hex: projectData.color))
                                        .frame(width: barWidth, height: Theme.Design.cornerRadius + 2)
                                        .cornerRadius(Theme.Design.cornerRadius)
                                    
                                    // Text positioned inside the bar if wide enough, otherwise outside
                                    if barWidth > 60 {
                                        Text("\(String(format: "%.1f", projectData.totalHours)) h")
                                            .font(Theme.Fonts.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, Theme.spacingExtraSmall)
                                            .frame(maxWidth: barWidth - 8, alignment: .trailing)
                                            .offset(x: 4) // Small offset to prevent clipping
                                    } else {
                                        // Text outside the bar when bar is too small
                                        Text("\(String(format: "%.1f", projectData.totalHours)) h")
                                            .font(Theme.Fonts.body)
                                            .foregroundColor(Theme.Colors.textPrimary)
                                            .frame(minWidth: 50, alignment: .trailing)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.spacingMedium)
                    
                    Spacer(minLength: 0) // This will push content to center
                }
            }
        }
    }
}

#Preview {
    YearlyTotalBarChartView(data: [
        ProjectChartData(projectName: "Work", color: "#4E79A7", emoji: "💼", totalHours: 120, percentage: 45.0),
        ProjectChartData(projectName: "Personal", color: "#F28E2C", emoji: "🏠", totalHours: 80, percentage: 30.0),
        ProjectChartData(projectName: "Learning", color: "#E15759", emoji: "📚", totalHours: 40, percentage: 15.0),
        ProjectChartData(projectName: "Other", color: "#76B7B2", emoji: "📁", totalHours: 20, percentage: 7.5),
        ProjectChartData(projectName: "Hobby", color: "#59A14F", emoji: "🎨", totalHours: 60, percentage: 22.5)
    ])
    .frame(width: 1000, height: 300)
    .padding()
    .background(Theme.Colors.background)
}
