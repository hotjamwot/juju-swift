import SwiftUI
import Charts
import Foundation

struct YearlyTotalBarChartView: View {
    let data: [ProjectChartData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            Text("This Year")
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textSecondary)
            
            if data.isEmpty {
                Text("No data for this year")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 300)
            } else {
                // Sort data descending by total hours
                let sortedData = data.sorted { $0.totalHours > $1.totalHours }
                
                GeometryReader { geometry in
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(sortedData.indices, id: \.self) { index in
                            let projectData = sortedData[index]
                            let maxValue = sortedData.first?.totalHours ?? 1
                            let barWidth = (projectData.totalHours / maxValue) * (geometry.size.width - 100)
                            
                            HStack(spacing: 12) {
                                // Project label with icon
                                HStack(spacing: 8) {
                                    // Project icon (placeholder - will be replaced with actual icon)
                                    Circle()
                                        .fill(Color(hex: projectData.color))
                                        .frame(width: 16, height: 16)
                                    
                                    Text(projectData.projectName)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                }
                                .frame(width: 150, alignment: .leading)
                                
                                // Bar chart
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 20)
                                        .cornerRadius(4)
                                    
                                    Rectangle()
                                        .fill(Color(hex: projectData.color))
                                        .frame(width: barWidth, height: 20)
                                        .cornerRadius(4)
                                    
                                    // Value label at the end of the bar
                                    Text("\(String(format: "%.1f", projectData.totalHours)) h")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .padding(.horizontal, 8)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: CGFloat(sortedData.count) * 40 + 20)
            }
        }
        .padding(Theme.spacingMedium)
    }
}

#Preview {
    YearlyTotalBarChartView(data: [
        ProjectChartData(projectName: "Work", color: "#4E79A7", totalHours: 120, percentage: 45.0),
        ProjectChartData(projectName: "Personal", color: "#F28E2C", totalHours: 80, percentage: 30.0),
        ProjectChartData(projectName: "Learning", color: "#E15759", totalHours: 40, percentage: 15.0),
        ProjectChartData(projectName: "Other", color: "#76B7B2", totalHours: 20, percentage: 7.5),
        ProjectChartData(projectName: "Hobby", color: "#59A14F", totalHours: 60, percentage: 22.5)
    ])
    .frame(width: 800, height: 350)
    .padding()
}
