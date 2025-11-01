import SwiftUI
import Charts

struct SessionCalendarChartView: View {
    let sessions: [WeeklySession]
    
    let weekDays = [
        "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday", "Sunday"
    ]
    
    let dayToLetter: [String: String] = [
            "Monday":    "M",
            "Tuesday":   "T",
            "Wednesday": "W",
            "Thursday":  "T",
            "Friday":    "F",
            "Saturday":  "S",
            "Sunday":    "S"
        ]
    
// Mark: Body
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLarge) {
            Text("This Week")
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textSecondary)
            
            Chart(sessions) { session in
                RectangleMark(
                    x: .value("Day", session.day),
                    yStart: .value("Start Hour", session.startHour),
                    yEnd:   .value("End Hour",   session.endHour)
                )
                .foregroundStyle(Color(hex: session.projectColor))
                .cornerRadius(8)
                .annotation(position: .overlay, alignment: .center) {
                    Text("\(session.duration, specifier: "%.1f")h")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(.white)
                        .bold()
                }
            }
            .chartYScale(domain: 6.0 ... 23.0)
            .chartYAxis {
                AxisMarks(values: .automatic) { value in
                    if let hour = value.as(Double.self) {
                        AxisValueLabel(String(format: "%.0f", hour))
                    }
                }
            }

            .chartXAxis {
                AxisMarks(values: weekDays) { value in
                    let day = value.as(String.self) ?? ""
                    let label = dayToLetter[day] ?? day
                    AxisValueLabel(label)
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(.clear)
            }
            .chartXScale(domain: weekDays)

            .frame(height: 200)
            if sessions.isEmpty {
                Text("No sessions this week")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 200)
            }
        }
        .padding(Theme.spacingLarge)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
        .shadow(radius: 2)
    }
}

#Preview(body: {
    let mockSessions: [WeeklySession] = [
        WeeklySession(day: "Monday", startHour: 9.0, endHour: 12.0, projectName: "Film", projectColor: "#FFA500"),
        WeeklySession(day: "Monday", startHour: 14.0, endHour: 16.0, projectName: "Writing", projectColor: "#800080"),
        WeeklySession(day: "Tuesday", startHour: 10.0, endHour: 11.5, projectName: "Admin", projectColor: "#0000FF"),
        WeeklySession(day: "Wednesday", startHour: 13.0, endHour: 17.0, projectName: "Film", projectColor: "#FFA500")
    ]
    return SessionCalendarChartView(sessions: mockSessions)
        .frame(width: 800, height: 250)
        .padding()
})
