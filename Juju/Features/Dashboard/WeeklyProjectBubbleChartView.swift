import SwiftUI
import Charts

/// Displays a bubble-style chart showing project totals for the current week.
struct WeeklyProjectBubbleChartView: View {
    @ObservedObject var chartDataPreparer: ChartDataPreparer

    var body: some View {
        let data = chartDataPreparer.weeklyProjectTotals()

        VStack(alignment: .leading, spacing: 12) {
            Text("This Week’s Projects")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)

            if data.isEmpty {
                Text("No sessions this week")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
            } else {
                chartContent(data: data)
            }
        }
        .padding(.vertical, 8)
    }

    private func chartContent(data: [ProjectChartData]) -> some View {
        Chart(data, id: \.projectName) { item in
            PointMark(
                x: .value("Project", item.projectName),
                y: .value("Total Hours", item.totalHours)
            )
            .foregroundStyle(Color(hex: item.color))
            .symbol {
                Circle().fill(Color(hex: item.color))
            }
            .symbolSize(by: .value("Total Hours", sqrt(item.totalHours))) // scaled size for readability
            .annotation(position: .overlay, alignment: .center) {
                Text(item.projectName)
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                    .padding(2)
            }
            .accessibilityLabel(item.projectName)
            .accessibilityValue("\(item.totalHours, specifier: "%.1f") hours total")
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}
