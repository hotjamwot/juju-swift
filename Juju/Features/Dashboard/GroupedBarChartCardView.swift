import SwiftUI
import Charts

struct StackedAreaChartCardView: View {
    // The view now expects the new data shape!
    let data: [ProjectSeriesData]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLarge) {
            Text("Monthly Trends")
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textSecondary)

            if data.isEmpty {
                Text("No data for this year")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 250)
            } else {
                chartView
            }
        }
        .padding(Theme.spacingLarge)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }

    @ViewBuilder
    private var chartView: some View {
        // This chart implementation is now clean and correct!
        let chart = Chart(data) { series in // Loop through each project series
            ForEach(series.monthlyHours) { monthlyHour in // Loop through the months FOR THAT project
                AreaMark(
                    x: .value("Month", monthlyHour.date, unit: .month), // Use the Date
                    y: .value("Hours", monthlyHour.hours),
                    stacking: .center
                )
                // The foregroundStyle now correctly applies to the entire series
                .foregroundStyle(by: .value("Project", series.projectName))
                .interpolationMethod(.catmullRom) // Or .cardinal like the example
            }
        }
        // Build the domain/range map from our series data
        .chartForegroundStyleScale(domain: data.map { $0.projectName },
                                     range: data.map { Color(hex: $0.color) })
        .chartYAxis { AxisMarks(stroke: StrokeStyle(lineWidth: 0)) }
        // Format the X-axis to show month abbreviations
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                AxisGridLine()
                AxisTick()
                if let date = value.as(Date.self) {
                    // FIX: Wrap the Text view in an AxisValueLabel
                    AxisValueLabel {
                        Text(date.formatted(.dateTime.month(.narrow)))
                    }
                }
            }
        }
        .frame(height: 250)
            chart
    }
}


#Preview {
    
    func dateFor(month: Int) -> Date {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return calendar.date(from: DateComponents(year: year, month: month))!
    }
    
    let mockData: [ProjectSeriesData] = [
        ProjectSeriesData(
            projectName: "Film",
            monthlyHours: [
                MonthlyHour(date: dateFor(month: 1), hours: 20), // Jan
                MonthlyHour(date: dateFor(month: 2), hours: 10), // Feb
                MonthlyHour(date: dateFor(month: 3), hours: 0)   // Mar (add 0 to make the line continuous)
            ],
            color: "#FFA500"
        ),
        ProjectSeriesData(
            projectName: "Writing",
            monthlyHours: [
                MonthlyHour(date: dateFor(month: 1), hours: 15), // Jan
                MonthlyHour(date: dateFor(month: 2), hours: 0),   // Feb (add 0)
                MonthlyHour(date: dateFor(month: 3), hours: 12)  // Mar
            ],
            color: "#800080"
        ),
        ProjectSeriesData(
            projectName: "Design",
            monthlyHours: [
                MonthlyHour(date: dateFor(month: 1), hours: 0),   // Jan (add 0)
                MonthlyHour(date: dateFor(month: 2), hours: 5),  // Feb
                MonthlyHour(date: dateFor(month: 3), hours: 8)   // Mar
            ],
            color: "#0000FF"
        )
    ]
    
    // Use a ZStack to provide a background color for better visibility
    return ZStack {
        Color(NSColor.windowBackgroundColor) // A neutral background
        
        StackedAreaChartCardView(data: mockData)
            .frame(width: 850, height: 350)
            .padding()
    }
}
