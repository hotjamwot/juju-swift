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
    private let sliverCornerRadius: CGFloat = 3.0
    
    // MARK: - Derived Data
    
    /// Chart X-domain — first/last day from the day stacks.
    private var xDomain: ClosedRange<Date> {
        guard let first = dayStacks.first?.date, let last = dayStacks.last?.date else {
            let today = Calendar.current.startOfDay(for: Date())
            return today...Calendar.current.date(byAdding: .day, value: 1, to: today)!
        }
        return first...last
    }
    
    /// Set of dates that are milestone days — used for glow and sliver tint.
    private var milestoneDates: Set<Date> {
        Set(dayStacks.filter { $0.isMilestone }.map { $0.date })
    }
    
    /// Is the given day a milestone day?
    private func isMilestoneDay(_ date: Date) -> Bool {
        milestoneDates.contains(Calendar.current.startOfDay(for: date))
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
                .annotation(position: .overlay, alignment: .center) {
                    if isDayHovered(session.date) {
                        RoundedRectangle(cornerRadius: sliverCornerRadius + 1)
                            .stroke(Theme.Colors.warmAccent.opacity(0.25), lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                }
                .annotation(position: .overlay, alignment: .center) {
                    if isDayHovered(session.date) && isMilestoneDay(session.date) {
                        RoundedRectangle(cornerRadius: sliverCornerRadius)
                            .fill(Theme.Colors.milestone.opacity(0.15))
                            .allowsHitTesting(false)
                    }
                }
                .annotation(position: .overlay, alignment: .topTrailing) {
                    if session.isMilestone {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Theme.Colors.milestoneHighlight)
                            .offset(x: 4, y: 1)
                            .allowsHitTesting(false)
                    }
                }
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
                            if let hovered, hoveredDay?.id != hovered.id {
                                withAnimation(Theme.Design.spring) {
                                    hoveredDay = hovered
                                }
                            } else if hovered == nil, hoveredDay != nil {
                                withAnimation(Theme.Design.spring) {
                                    hoveredDay = nil
                                }
                            }
                        case .ended:
                            withAnimation(Theme.Design.spring) {
                                hoveredDay = nil
                            }
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
    ///
    /// The chart's X domain runs from the first day's `startOfDay` to the
    /// last day's `startOfDay`, and each day's sliver is centred on its
    /// `startOfDay`. A linear pixel→Date mapping therefore resolves the
    /// left half of a day's column to the previous day, and the outer
    /// halves of the first/last columns fall outside the domain entirely.
    ///
    /// Snapping to the nearest day stack (with a half-day tolerance) keeps
    /// the hover tightly aligned with the visual column the cursor is in,
    /// including the boundary columns, without changing the visual domain.
    private func dayAt(location: CGPoint, proxy: ChartProxy) -> DayStack? {
        guard let date: Date = proxy.value(atX: location.x) else { return nil }
        guard let nearest = dayStacks.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }) else { return nil }
        // Tolerance of half a day: anything further than 12h from the nearest
        // stack is considered outside any day's column (e.g. far padding).
        let halfDay: TimeInterval = 12 * 3600
        return abs(nearest.date.timeIntervalSince(date)) <= halfDay ? nearest : nil
    }
    
    /// Format a decimal hour for the Y-axis (e.g. 14.5 → "14", 6.0 → "6").
    private func formatAxisHour(_ hour: Double) -> String {
        let h = Int(hour.rounded())
        let period = h < 12 ? "am" : "pm"
        let display = h % 12 == 0 ? 12 : h % 12
        return "\(display)\(period)"
    }
}

