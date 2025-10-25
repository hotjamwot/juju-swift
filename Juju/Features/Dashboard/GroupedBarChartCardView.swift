import SwiftUI
import Charts

struct GroupedBarChartCardView: View {
    let data: [MonthlyBarData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Rhythm")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            if data.isEmpty {
                Text("No data for this year")
                    .foregroundColor(.secondary)
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
                            .foregroundStyle(by: .value("Project", project.projectName))
                            .annotation(position: .top, alignment: .center) {
                                Text("\(project.hours, specifier: "%.1f")")
                                    .font(.caption)
                                    .foregroundColor(.primary)
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
        .padding()
        .background(Color(Theme.Colors.background))
        .cornerRadius(12)
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
