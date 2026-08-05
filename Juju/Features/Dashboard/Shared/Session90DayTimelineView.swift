import SwiftUI
import Charts

/// 90-day timeline chart showing when sessions occur across the day.
///
/// Each session renders as a thin vertical sliver positioned by its decimal
/// start/end hour within its calendar-day column. The Y-axis is a fixed
/// time-of-day range matching the weekly calendar chart; the X-axis is the
/// 90-day lookback window with month transition labels.
///
/// Hovering anywhere within a day column (not just a sliver) exposes the
/// hovered day via the `hoveredDay` binding so the parent can show the
/// `DaySessionInfoPanel`. Empty days show no slivers but remain hoverable.
struct Session90DayTimelineView: View {
    let dayStacks: [DayStack]
    let sessions: [DayTimelineSession]
    /// Binding to the currently hovered day — set by the parent to drive the info panel.
    @Binding var hoveredDay: DayStack?
    
    // MARK: - Constants
    
    /// Fixed time-of-day Y-axis range — matches SessionCalendarChartView.
    private let yDomain: ClosedRange<Double> = 6.0...23.0
    /// Hour grid line positions.
    private let gridHours: [Double] = [6.0, 9.0, 12.0, 15.0, 18.0, 21.0, 23.0]
    /// Background opacity for un-hovered slivers.
    private let sliverOpacity: Double = 0.85
    /// Corner radius for slivers.
    private let sliverCornerRadius: CGFloat = 1.5
    
    // MARK: - Derived Data
    
    /// Chart X-domain — first/last day from the day stacks.
    private var xDomain: ClosedRange<Date> {
        guard let first = dayStacks.first?.date, let last = dayStacks.last?.date else {
            let today = Calendar.current.startOfDay(for: Date())
            return today...Calendar.current.date(byAdding: .day, value: 1, to: today)!
        }
        return first...last
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if dayStacks.isEmpty {
                Spacer()
                Text("No data yet")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                chart
            }
        }
        .onHover { hovering in
            if !hovering {
                hoveredDay = nil
            }
        }
    }
    
    // MARK: - Chart
    
    private var chart: some View {
        Chart {
            // Hour grid lines — dotted rules across the full width.
            ForEach(gridHours, id: \.self) { hour in
                RuleMark(y: .value("Hour", hour))
                    .foregroundStyle(Theme.Colors.divider.opacity(0.15))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 6]))
            }
            
            // Session slivers — thin vertical blocks at their time-of-day.
            ForEach(sessions) { session in
                RectangleMark(
                    x: .value("Day", session.date),
                    yStart: .value("Start Hour", session.startHour),
                    yEnd: .value("End Hour", session.endHour)
                )
                .foregroundStyle(
                    Color(hex: session.projectColor).opacity(
                        isDayHovered(session.date) ? 1.0 : sliverOpacity
                    )
                )
                .cornerRadius(sliverCornerRadius)
            }
        }
        .chartXScale(domain: xDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisGridLine()
                    .foregroundStyle(Theme.Colors.divider.opacity(0.1))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(values: gridHours) { value in
                AxisGridLine()
                    .foregroundStyle(Theme.Colors.divider.opacity(0.1))
                AxisValueLabel {
                    if let hour = value.as(Double.self) {
                        Text(formatAxisHour(hour))
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(.clear)
                .padding(.horizontal, Theme.DashboardLayout.chartInnerPadding)
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let hovered = dayAt(location: location, proxy: proxy)
                            withAnimation(.easeOut(duration: 0.1)) {
                                hoveredDay = hovered
                            }
                        case .ended:
                            withAnimation(.easeOut(duration: 0.1)) {
                                hoveredDay = nil
                            }
                        }
                    }
                
                // Subtle highlight behind today's column.
                if let today = dayStacks.first(where: { Calendar.current.isDateInToday($0.date) }) {
                    if let x = proxy.position(forX: today.date) {
                        Rectangle()
                            .fill(Theme.Colors.divider.opacity(0.08))
                            .frame(width: 20, height: geo.size.height)
                            .position(x: x, y: geo.size.height / 2)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Is the given day the currently hovered day?
    private func isDayHovered(_ date: Date) -> Bool {
        guard let day = hoveredDay else { return false }
        return Calendar.current.isDate(day.date, inSameDayAs: date)
    }
    
    /// Resolve the hovered day stack from a pixel location via the chart proxy.
    private func dayAt(location: CGPoint, proxy: ChartProxy) -> DayStack? {
        guard let date: Date = proxy.value(atX: location.x) else { return nil }
        let startOfDay = Calendar.current.startOfDay(for: date)
        return dayStacks.first { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }
    }
    
    /// Format a decimal hour for the Y-axis (e.g. 14.5 → "14", 6.0 → "6").
    private func formatAxisHour(_ hour: Double) -> String {
        let h = Int(hour.rounded())
        let period = h < 12 ? "am" : "pm"
        let display = h % 12 == 0 ? 12 : h % 12
        return "\(display)\(period)"
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    let projectA = Project(name: "Writing", color: "#E15759", order: 0, emoji: "📝")
    let projectB = Project(name: "Design", color: "#4E79A7", order: 1, emoji: "🎨")
    let projectC = Project(name: "Coding", color: "#59A14F", order: 2, emoji: "💻")
    
    var mockStacks: [DayStack] = []
    var mockSessions: [DayTimelineSession] = []
    
    for i in 0..<90 {
        guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
        var dayProjects: [DayProjectInfo] = []
        var daySessions: [SessionRecord] = []
        
        let project = [projectA, projectB, projectC].randomElement()!
        
        if Double.random(in: 0...1) > 0.25 {
            let startHour = Double.random(in: 7...20)
            let endHour = min(startHour + Double.random(in: 0.5...3), 23.0)
            dayProjects.append(DayProjectInfo(id: project.id, name: project.name, color: project.color, emoji: project.emoji))
            mockSessions.append(DayTimelineSession(
                date: date,
                startHour: startHour,
                endHour: endHour,
                projectID: project.id,
                projectName: project.name,
                projectColor: project.color,
                projectEmoji: project.emoji
            ))
            
            let startDate = calendar.date(bySettingHour: Int(startHour), minute: Int((startHour.truncatingRemainder(dividingBy: 1)) * 60), second: 0, of: date)!
            let endDate = calendar.date(bySettingHour: Int(endHour), minute: Int((endHour.truncatingRemainder(dividingBy: 1)) * 60), second: 0, of: date)!
            daySessions.append(SessionRecord(
                startDate: startDate,
                endDate: endDate,
                projectID: project.id,
                activityTypeID: nil,
                action: "Mock session",
                notes: ""
            ))
        }
        
        mockStacks.append(DayStack(date: date, sessions: daySessions, projects: dayProjects))
    }
    
    @State var hoveredDay: DayStack? = nil
    return Session90DayTimelineView(
        dayStacks: mockStacks.reversed(),
        sessions: mockSessions.reversed(),
        hoveredDay: $hoveredDay
    )
    .padding()
    .frame(width: 900, height: 300)
    .background(Theme.Colors.background)
}