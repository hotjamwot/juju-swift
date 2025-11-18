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
    
// Mark: Body
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            
            Chart {
                // Add continuous workday background highlighting (9 AM - 5 PM) across entire chart
                RectangleMark(
                    xStart: .value("Start", "Monday"),
                    xEnd: .value("End", "Sunday"),
                    yStart: .value("Start", 9.0),
                    yEnd: .value("End", 17.0)
                )
                .foregroundStyle(Color.gray.opacity(0.08))
                .cornerRadius(2)
                
                // Add subtle grid lines only for key hours: 6 AM, 9 AM, 5 PM, 11 PM
                ForEach([6.0, 23.0], id: \.self) { hour in
                    RuleMark(
                        y: .value("Hour", hour)
                    )
                    .foregroundStyle(Color.gray.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [3, 6]))
                }
                
                ForEach(sessions) { session in
                    RectangleMark(
                        x: .value("Day", session.day),
                        yStart: .value("Start Hour", session.startHour),
                        yEnd:   .value("End Hour",   session.endHour)
                    )
                    .foregroundStyle(Color(hex: session.projectColor))
                    .cornerRadius(Theme.Design.cornerRadius / 4)
                    .annotation(position: .overlay, alignment: .center) {
                        HStack(spacing: 4) {
                            Text(session.projectEmoji)
                                .font(.caption)
                            Text("\(session.duration, specifier: "%.1f")h")
                                .font(Theme.Fonts.caption)
                                .bold()
                        }
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                    }
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

            .frame(height: 280)
            
            if sessions.isEmpty {
                Text("No sessions this week")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 280)
            }
        }
    }
}

#Preview(body: {
    let mockSessions: [WeeklySession] = [
        WeeklySession(day: "Monday", startHour: 9.0, endHour: 12.0, projectName: "Film", projectColor: "#FFA500", projectEmoji: "🎬"),
        WeeklySession(day: "Monday", startHour: 14.0, endHour: 16.0, projectName: "Writing", projectColor: "#800080", projectEmoji: "✍️"),
        WeeklySession(day: "Tuesday", startHour: 10.0, endHour: 11.5, projectName: "Admin", projectColor: "#0000FF", projectEmoji: "📋"),
        WeeklySession(day: "Wednesday", startHour: 13.0, endHour: 17.0, projectName: "Film", projectColor: "#FFA500", projectEmoji: "🎬")
    ]
    return SessionCalendarChartView(sessions: mockSessions)
        .frame(width: 800, height: 350)
        .padding()
})
