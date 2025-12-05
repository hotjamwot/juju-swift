import SwiftUI
import Charts

struct SessionCalendarChartView: View {
    let sessions: [WeeklySession]
    
    let weekDays = [
        "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday", "Sunday"
    ]
    
    let dayToLetter: [String: String] = [
            "Monday":    "MON",
            "Tuesday":   "TUE",
            "Wednesday": "WED",
            "Thursday":  "THU",
            "Friday":    "FRI",
            "Saturday":  "SAT",
            "Sunday":    "SUN"
        ]
    
    // Calculate total duration for each day
    private var dailyTotals: [String: Double] {
        var totals: [String: Double] = [:]
        for session in sessions {
            totals[session.day, default: 0] += session.duration
        }
        return totals
    }
    
    // Grid line for a specific hour
    private func gridLine(for hour: Double) -> some ChartContent {
        RuleMark(
            y: .value("Hour", hour)
        )
        .foregroundStyle(Color.gray.opacity(0.3))
        .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [3, 6]))
    }
    
    // Session rectangle for a specific session
    private func sessionRectangle(for session: WeeklySession) -> some ChartContent {
        RectangleMark(
            x: .value("Day", session.day),
            yStart: .value("Start Hour", session.startHour),
            yEnd:   .value("End Hour",   session.endHour)
        )
        .foregroundStyle(Color(hex: session.projectColor))
        .cornerRadius(Theme.Design.cornerRadius / 4)
        .annotation(position: .overlay, alignment: .center) {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.activityEmoji)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.background)
                        .cornerRadius(Theme.Design.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .stroke(Theme.Colors.divider, lineWidth: 1)
                        )
                    
                    Text(session.projectEmoji)
                        .font(.caption2)
                }
                
                Text("\(session.duration, specifier: "%.1f")h")
                    .font(Theme.Fonts.caption)
                    .bold()
            }
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
        }
    }
    
// Mark: Body
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            
            Chart {
                // Add subtle grid lines only for key hours: 6 AM, 9 AM, 5 PM, 11 PM
                gridLine(for: 6.0)
                gridLine(for: 23.0)
                
                ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                    sessionRectangle(for: session)
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
                    
                    AxisValueLabel {
                        VStack(spacing: 2) {
                            Text(label)
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                            if let dailyTotal = dailyTotals[day], dailyTotal > 0 {
                                Text("\(dailyTotal, specifier: "%.1f")h")
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(.clear)
                }
            .chartXScale(domain: weekDays)

            .frame(height: 380)
            
            if sessions.isEmpty {
                Text("No sessions this week")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 380)
            }
        }
    }
}

#Preview(body: {
    let mockSessions: [WeeklySession] = [
        WeeklySession(day: "Monday", startHour: 9.0, endHour: 12.0, projectName: "Film", projectColor: "#FFA500", projectEmoji: "🎬", activityEmoji: "🎬"),
        WeeklySession(day: "Monday", startHour: 14.0, endHour: 16.0, projectName: "Writing", projectColor: "#800080", projectEmoji: "✍️", activityEmoji: "✍️"),
        WeeklySession(day: "Tuesday", startHour: 10.0, endHour: 11.5, projectName: "Admin", projectColor: "#0000FF", projectEmoji: "📋", activityEmoji: "🗂️"),
        WeeklySession(day: "Wednesday", startHour: 13.0, endHour: 17.0, projectName: "Film", projectColor: "#FFA500", projectEmoji: "🎬", activityEmoji: "🎬")
    ]
    return SessionCalendarChartView(sessions: mockSessions)
        .frame(width: 800, height: 350)
        .padding()
})
