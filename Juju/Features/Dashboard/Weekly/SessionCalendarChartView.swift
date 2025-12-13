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
    
    // Working hours shaded area (9 AM to 5 PM)
    private func workingHoursShade() -> some ChartContent {
        RectangleMark(
            xStart: .value("Start Day", weekDays.first!),
            xEnd: .value("End Day", weekDays.last!),
            yStart: .value("Start Hour", 9.0),
            yEnd: .value("End Hour", 17.0)
        )
        .foregroundStyle(Theme.Colors.divider.opacity(0.15))
        .cornerRadius(Theme.Design.cornerRadius / 2)
    }
    
    // Session rectangle for a specific session
    private func sessionRectangle(for session: WeeklySession) -> some ChartContent {
        RectangleMark(
            x: .value("Day", session.day),
            yStart: .value("Start Hour", session.startHour),
            yEnd:   .value("End Hour",   session.endHour)
        )
        .foregroundStyle(Color(hex: session.projectColor))
        .cornerRadius(Theme.Design.cornerRadius * 0.5) // Adjusted corner radius (between /4 and full)
        .annotation(position: .overlay, alignment: .center) {
            VStack(spacing: 6) {
                // Activity emoji on top (larger and prominent)
                Text(session.activityEmoji)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Project name (centered, single line)
                Text(session.projectName)
                    .font(Theme.Fonts.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
    
// Mark: Body
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            if sessions.isEmpty {
                Text("No sessions this week")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(maxHeight: .infinity) // Allow flexible height to adapt to available space
            } else {
                Chart {
                    // Working hours shaded area (9 AM to 5 PM)
                    workingHoursShade()
                    
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

                .frame(maxHeight: .infinity) // Allow flexible height to adapt to available space
            }
        }
        .padding(Theme.spacingLarge) // Increased padding inside the pane
        .background(Theme.Colors.surface.opacity(0.5))
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
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
