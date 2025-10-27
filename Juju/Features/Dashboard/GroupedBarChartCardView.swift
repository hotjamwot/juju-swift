import SwiftUI
import Charts

struct GroupedBarChartCardView: View {
    let data: [MonthlyBarData]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingExtraLarge) {
            Text("Your Rhythm")
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textPrimary)
            
            if data.isEmpty {
                Text("No data for this year")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 250)
            } else {
                Chart {
                    ForEach(data, id: \.month) { monthData in
                        ForEach(monthData.projects, id: \.projectName) { project in
                            BarMark(
                                x: .value("Month", monthData.month),
                                y: .value("Hours", project.hours)
                            )
                            .foregroundStyle(Color(hex: project.color))
                            .annotation(position: .top, alignment: .center) {
                                Text("\(project.hours, specifier: "%.1f")")
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                        }
                    }
                }
                .frame(height: 250)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
            }
        }
        .padding(Theme.spacingLarge)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
        .shadow(radius: 2)
    }
}

#Preview(body: {
    let mockData = MonthlyBarData(month: "Jan", projects: [
        ProjectMonthlyData(projectName: "Film", hours: 20, color: "#FFA500"),
        ProjectMonthlyData(projectName: "Writing", hours: 15, color: "#800080")
    ])
    return GroupedBarChartCardView(data: [mockData])
        .frame(width: 800, height: 300)
        .padding()
})
