import SwiftUI
import Charts

struct SessionCalendarChartView: View {
    let sessions: [WeeklySession]
    
    let weekDays = [
        "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday", "Sunday"
    ]
    
    @State private var currentTime = Date()
    @State private var hoveredSession: WeeklySession? = nil
    @State private var showTooltip: Bool = false
    @State private var tooltipPosition: CGPoint = .zero
    
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
    
    // Current time indicator for the current day only
    private func currentTimeIndicator() -> some ChartContent {
        let calendar = Calendar.current
        let currentHour = Double(calendar.component(.hour, from: currentTime))
        let currentMinute = Double(calendar.component(.minute, from: currentTime))
        let currentDay = calendar.weekdaySymbols[calendar.component(.weekday, from: currentTime) - 1]
        
        if weekDays.contains(currentDay) {
            return RectangleMark(
                x: .value("Current Day", currentDay),
                yStart: .value("Current Time", currentHour + (currentMinute / 60.0) - 0.01),
                yEnd: .value("Current Time", currentHour + (currentMinute / 60.0) + 0.01)
            )
            .foregroundStyle(Theme.Colors.accentColor)
        } else {
            return RectangleMark(
                yStart: .value("Current Time", currentHour + (currentMinute / 60.0) - 0.01),
                yEnd: .value("Current Time", currentHour + (currentMinute / 60.0) + 0.01)
            )
            .foregroundStyle(Color.clear)
        }
    }
    
    // Session rectangle for a specific session with compact annotation
    private func sessionRectangle(for session: WeeklySession) -> some ChartContent {
        RectangleMark(
            x: .value("Day", session.day),
            yStart: .value("Start Hour", session.startHour),
            yEnd:   .value("End Hour",   session.endHour)
        )
        .foregroundStyle(
            Color(hex: session.projectColor).opacity(
                hoveredSession?.id == session.id ? 1.0 : 0.85
            )
        )
        .cornerRadius(Theme.Design.cornerRadius * 0.5)
        .annotation(position: .overlay, alignment: .center) {
            VStack(spacing: 2) {
                Image(systemName: session.activitySFSymbol)
                    .font(Theme.Fonts.caption)
                Text(session.projectName)
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Tooltip Content
    
    @ViewBuilder
    private func tooltipContent(for session: WeeklySession) -> some View {
        TooltipContainer {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.day)
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(String(format: "%.0f:00 – %.0f:00 • %.1fh",
                    session.startHour,
                    session.endHour,
                    session.duration))
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.accentColor)
                
                TooltipDivider()
                
                TooltipRow(
                    color: Color(hex: session.projectColor),
                    emoji: session.projectEmoji,
                    name: session.projectName,
                    hours: session.duration
                )
            }
        }
    }
    
    // MARK: - Tooltip Positioning
    
    private let tooltipWidth: CGFloat = 200
    private let tooltipHeight: CGFloat = 80
    private let tooltipPadding: CGFloat = 14
    
    private func tooltipTooltipX(in size: CGSize) -> CGFloat {
        let maxX = size.width - tooltipWidth / 2
        let minX = tooltipWidth / 2
        let idealX = tooltipPosition.x + tooltipPadding + tooltipWidth / 2
        // If tooltip would go off the right edge, place it to the left of cursor
        if idealX + tooltipWidth / 2 > size.width {
            return max(tooltipPosition.x - tooltipPadding - tooltipWidth / 2, minX)
        }
        return min(idealX, maxX)
    }
    
    private func tooltipTooltipY(in size: CGSize) -> CGFloat {
        let maxY = size.height - tooltipHeight / 2
        let minY = tooltipHeight / 2
        let idealY = tooltipPosition.y + tooltipHeight / 2 + 8
        // If tooltip would go off the bottom, place it above the cursor
        if idealY + tooltipHeight / 2 > size.height {
            return max(tooltipPosition.y - tooltipHeight / 2 - 8, minY)
        }
        return min(idealY, maxY)
    }
    
    // MARK: - Find session at pixel location (via ChartProxy)
    
    private func sessionAt(location: CGPoint, proxy: ChartProxy) -> WeeklySession? {
        // ChartProxy.value(atX:) and value(atY:) convert pixel positions
        // to chart domain values using the chart's own coordinate system.
        guard let day: String = proxy.value(atX: location.x),
              let hour: Double = proxy.value(atY: location.y) else {
            return nil
        }
        
        return sessions.first { session in
            session.day == day &&
            hour >= session.startHour &&
            hour <= session.endHour
        }
    }
    
    // MARK: Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if sessions.isEmpty {
                Text("No sessions this week")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart {
                    workingHoursShade()
                    
                    gridLine(for: 6.0)
                    gridLine(for: 23.0)
                    
                    currentTimeIndicator()
                    
                    ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                        sessionRectangle(for: session)
                    }
                }
                .chartYScale(domain: 5.5 ... 23.5)
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
                        .padding(.horizontal, Theme.DashboardLayout.chartInnerPadding)
                }
                .chartXScale(domain: weekDays)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    if let matched = sessionAt(location: location, proxy: proxy) {
                                        withAnimation(.easeOut(duration: 0.1)) {
                                            hoveredSession = matched
                                            showTooltip = true
                                            tooltipPosition = location
                                        }
                                    } else {
                                        withAnimation(.easeOut(duration: 0.1)) {
                                            showTooltip = false
                                            hoveredSession = nil
                                        }
                                    }
                                case .ended:
                                    withAnimation(.easeOut(duration: 0.1)) {
                                        showTooltip = false
                                        hoveredSession = nil
                                    }
                                }
                            }
                        
                        // Floating tooltip overlay
                        if showTooltip, let session = hoveredSession {
                            tooltipContent(for: session)
                                .fixedSize()
                                .position(
                                    x: tooltipTooltipX(in: geo.size),
                                    y: tooltipTooltipY(in: geo.size)
                                )
                                .allowsHitTesting(false)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                }
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
                currentTime = Date()
            }
        }
    }
}

#Preview(body: {
    let mockSessions: [WeeklySession] = [
        WeeklySession(day: "Monday", startHour: 9.0, endHour: 12.0, projectName: "Film", projectColor: "#FFA500", projectEmoji: "🎬", activitySFSymbol: "film"),
        WeeklySession(day: "Monday", startHour: 14.0, endHour: 16.0, projectName: "Writing", projectColor: "#800080", projectEmoji: "✍️", activitySFSymbol: "pencil"),
        WeeklySession(day: "Tuesday", startHour: 10.0, endHour: 11.5, projectName: "Admin", projectColor: "#0000FF", projectEmoji: "📋", activitySFSymbol: "folder"),
        WeeklySession(day: "Wednesday", startHour: 13.0, endHour: 17.0, projectName: "Film", projectColor: "#FFA500", projectEmoji: "🎬", activitySFSymbol: "film"),
        WeeklySession(day: "Monday", startHour: 23.0, endHour: 24.0, projectName: "Music", projectColor: "#00FF00", projectEmoji: "🎵", activitySFSymbol: "headphones"),
        WeeklySession(day: "Tuesday", startHour: 0.0, endHour: 1.0, projectName: "Music", projectColor: "#00FF00", projectEmoji: "🎵", activitySFSymbol: "headphones")
    ]
    return SessionCalendarChartView(sessions: mockSessions)
        .frame(width: 800, height: 350)
        .padding()
})