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
        .foregroundStyle(Theme.Colors.divider.opacity(0.3))
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
            .foregroundStyle(Theme.Colors.interactive)
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
        .annotation(position: .overlay, alignment: .topTrailing) {
            if session.isMilestone {
                Circle()
                    .fill(Theme.Colors.milestoneHighlight)
                    .frame(width: 4, height: 4)
                    .offset(x: 4, y: 1)
                    .allowsHitTesting(false)
            }
        }
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
    
    /// Convert a decimal hour (e.g. 9.5) to a formatted time string (e.g. "09:30").
    private func formatHour(_ hour: Double) -> String {
        let h = Int(floor(hour))
        let m = Int((hour - Double(h)) * 60 + 0.5)
        return String(format: "%02d:%02d", h, m)
    }
    
    @ViewBuilder
    private func tooltipContent(for session: WeeklySession) -> some View {
        TooltipContainer {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(formatHour(session.startHour)) – \(formatHour(session.endHour)) • \(session.duration, specifier: "%.1f")h")
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                if let action = session.action, !action.isEmpty {
                    Text(action)
                        .font(Theme.Fonts.body.weight(.semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)
                }
                
                if let phaseName = session.phaseName, !phaseName.isEmpty {
                    HStack(spacing: Theme.Spacing.xxs) {
                        Image(systemName: "play.circle")
                            .font(Theme.Fonts.caption)
                        Text(phaseName)
                            .font(Theme.Fonts.caption)
                    }
                    .padding(.horizontal, Theme.Spacing.xxs)
                    .padding(.vertical, Theme.Spacing.micro)
                    .background(Theme.Colors.divider.opacity(0.2))
                    .clipShape(Capsule())
                }
                
                let notesPreview = session.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                if !notesPreview.isEmpty {
                    Text(String(notesPreview.prefix(80)))
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
        }
    }
    
    // MARK: - Tooltip Positioning
    
    // Estimated tooltip footprint used by the edge-aware clamping helpers.
    // Deliberately generous — the tooltip can grow tall with action/phase/notes,
    // and overestimating keeps it fully inside the chart instead of clipped.
    private let tooltipWidth: CGFloat = 220
    private let tooltipHeight: CGFloat = 150
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
            hour >= session.startHour - 0.1 &&
            hour <= session.endHour + 0.1
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
                .chartXScale(domain: weekDays)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        ZStack {
                            Color.clear
                                .contentShape(Rectangle())
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        let matched = sessionAt(location: location, proxy: proxy)
                                        if let matched, hoveredSession?.id != matched.id {
                                            // Short ease — a spring on chart state makes
                                            // the marks wobble as hover moves between blocks.
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                hoveredSession = matched
                                                showTooltip = true
                                                tooltipPosition = location
                                            }
                                        } else if matched == nil, hoveredSession != nil {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                showTooltip = false
                                                hoveredSession = nil
                                            }
                                        }
                                    case .ended:
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            showTooltip = false
                                            hoveredSession = nil
                                        }
                                    }
                                }
                            
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
                // Real layout padding OUTSIDE the chart — padding the plot area
                // itself shrinks the frame post-layout and clips the marks.
                .padding(.horizontal, Theme.DashboardLayout.chartInnerPadding)
                .padding(.vertical, Theme.Spacing.xs)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
                currentTime = Date()
            }
        }
    }
}

