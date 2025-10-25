import SwiftUI
import Charts

struct SessionCalendarChartView: View {
    let sessions: [WeeklySession]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week's Sessions")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            if sessions.isEmpty {
                Text("No sessions this week")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 200)
            } else {
                Chart(sessions) { session in
                    RectangleMark(
                        x: .value("Day", session.day),
                        yStart: .value("Start Hour", session.startHour),
                        yEnd: .value("End Hour", session.endHour)
                    )
                    .foregroundStyle(Color(hex: session.projectColor))
                    .annotation(position: .overlay, alignment: .center) {
                        Text("\(session.duration, specifier: "%.1f")h")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .bold()
                    }
                }
                .chartYScale(domain: 0.0 ... 24.0)
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(values: .stride(by: 2.0)) { value in
                        AxisGridLine()
                        if let hour = value.as(Double.self) {
                            AxisValueLabel(String(format: "%.0f", hour))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel(value.as(String.self) ?? "")
                        AxisGridLine()
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea.background(Color.gray.opacity(0.1))
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
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
