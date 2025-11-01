import SwiftUI
import Charts

struct GroupedBarChartCardView: View {
    let data: [MonthlyBarData]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLarge) {
            Text("This Year")
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textSecondary)

            if data.isEmpty {
                Text("No data for this year")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 250)
            } else {
                Chart {
                    // Flatten the data structure
                    ForEach(data.flatMap { monthData in
                        monthData.projects.map { project in
                            (month: monthData.month, project: project)
                        }
                    }, id: \.project.id) { (month, project) in
                        BarMark(
                            x: .value("Month", month),
                            y: .value("Hours", project.hours)
                        )
                        .foregroundStyle(Color(hex: project.color))
                        .cornerRadius(Theme.Design.cornerRadius)
                    }
                }
                .chartYAxis {
                    AxisMarks(
                        stroke: StrokeStyle(lineWidth: 0)
                    )
                }
                .chartXAxis {
                    AxisMarks(
                        stroke: StrokeStyle(lineWidth: 0)
                    )
                }
                .frame(height: 250)
            }
        }
        .padding(Theme.spacingLarge)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius / 2)
        .shadow(radius: 2)
    }

    // Helper function to format duration
    private func formatDuration(total: Double) -> String {
        let hours = Int(total)
        let minutes = Int((total * 60).truncatingRemainder(dividingBy: 60))
        return "\(hours)h \(minutes)m"
    }
}

extension HorizontalAlignment {
    static let horizontal = HorizontalAlignment.center
}

extension VerticalAlignment {
    static let vertical = VerticalAlignment.center
}

extension EdgeInsets {
    static let zero = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
}

#Preview(body: {
    let mockData = [
        MonthlyBarData(month: "Jan", projects: [
            ProjectMonthlyData(projectName: "Film", hours: 20, color: "#FFA500"),
            ProjectMonthlyData(projectName: "Writing", hours: 15, color: "#800080")
        ]),
        MonthlyBarData(month: "Feb", projects: [
            ProjectMonthlyData(projectName: "Film", hours: 10, color: "#FFA500"),
            ProjectMonthlyData(projectName: "Design", hours: 5, color: "#0000FF")
        ])
    ]
    return GroupedBarChartCardView(data: mockData)
        .frame(width: 850, height: 350)
        .padding()
})
