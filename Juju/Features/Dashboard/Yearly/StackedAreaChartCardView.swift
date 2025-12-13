import SwiftUI
import Charts

struct StackedAreaChartCardView: View {
    // The view now expects weekly data instead of monthly data!
    let data: [ProjectSeriesData]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLarge) {
            Text("Weekly Trends")
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
        .background(Theme.Colors.surface.opacity(0.5))
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .padding(.bottom, Theme.spacingLarge) // Add bottom padding to prevent chart from pressing against window edge
    }

    @ViewBuilder
    private var chartView: some View {
        let chart = Chart(data) { series in // Loop through each project series
            ForEach(series.weeklyHours) { weeklyHour in // Loop through the weeks FOR THAT project
                AreaMark(
                    x: .value("Week", weeklyHour.weekNumber),
                    y: .value("Hours", weeklyHour.hours),
                    stacking: .center
                )
                // The foregroundStyle now correctly applies to the entire series
                .foregroundStyle(by: .value("Project", series.projectName))
                .interpolationMethod(.catmullRom)
            }
        }
        // Build the domain/range map from our series data
        .chartForegroundStyleScale(domain: data.map { $0.projectName },
                                     range: data.map { Color(hex: $0.color) })
        .chartYAxis { AxisMarks(stroke: StrokeStyle(lineWidth: 0)) }
        // Format the X-axis to show week numbers
        .chartXAxis {
            AxisMarks(values: Array(1...52)) { value in
                AxisGridLine()
                AxisTick()
                if let weekNumber = value.as(Int.self) {
                    AxisValueLabel {
                        Text("W\(weekNumber)")
                    }
                }
            }
        }
        .frame(height: 250)
        chart
    }
}


// MARK: Preview
#Preview {
    let mockData: [ProjectSeriesData] = [
        ProjectSeriesData(
            projectName: "Film",
            monthlyHours: [],
            weeklyHours: [
                WeeklyHour(weekNumber: 1, hours: 20),
                WeeklyHour(weekNumber: 2, hours: 10),
                WeeklyHour(weekNumber: 3, hours: 0)
            ],
            color: "#FFA500",
            emoji: "🎬"
        ),
        ProjectSeriesData(
            projectName: "Writing",
            monthlyHours: [],
            weeklyHours: [
                WeeklyHour(weekNumber: 1, hours: 15),
                WeeklyHour(weekNumber: 2, hours: 0),
                WeeklyHour(weekNumber: 3, hours: 12)
            ],
            color: "#800080",
            emoji: "✍️"
        ),
        ProjectSeriesData(
            projectName: "Design",
            monthlyHours: [],
            weeklyHours: [
                WeeklyHour(weekNumber: 1, hours: 0),
                WeeklyHour(weekNumber: 2, hours: 5),
                WeeklyHour(weekNumber: 3, hours: 8)
            ],
            color: "#0000FF",
            emoji: "🎨"
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
