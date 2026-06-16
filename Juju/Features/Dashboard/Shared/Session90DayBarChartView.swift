import SwiftUI

/// 90-day stacked bar chart showing daily project breakdowns.
///
/// Each day is a vertical bar, segmented by project with project colours.
/// Empty days render as a thin baseline mark. Today gets an accent underline.
/// Hover state is exposed via a binding so the parent can show an info panel.
struct Session90DayBarChartView: View {
    let dayStacks: [DayStack]
    /// When set, all bars except the one on this date are dimmed.
    var highlightedDate: Date? = nil
    /// Binding to the currently hovered day — set by the parent to drive the info panel.
    @Binding var hoveredDay: DayStack?
    
    // MARK: - Layout Constants
    
    private let barGap: CGFloat = 2
    private let barCornerRadius: CGFloat = 2
    private let minBarWidth: CGFloat = 2
    private let emptyDayHeight: CGFloat = 1
    private let segmentOpacity: Double = 0.85
    private let dimmedOpacity: Double = 0.2
    private let dividerWidth: CGFloat = 1
    
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
                GeometryReader { geo in
                    let paddedWidth = geo.size.width - Theme.DashboardLayout.chartInnerPadding * 2
                    let availableWidth = paddedWidth
                    let availableHeight = geo.size.height
                    
                    // Calculate bar dimensions
                    let totalBars = CGFloat(dayStacks.count)
                    let rawBarWidth = (availableWidth - (totalBars - 1) * barGap) / totalBars
                    let barWidth = max(minBarWidth, rawBarWidth)
                    
                    // Month label height
                    let monthLabelHeight: CGFloat = 14
                    let chartHeight = availableHeight - monthLabelHeight
                    
                    VStack(alignment: .leading, spacing: 0) {
                        // Month labels along top
                        GeometryReader { labelGeo in
                            monthLabels(availableWidth: labelGeo.size.width, barWidth: barWidth)
                        }
                        .frame(height: monthLabelHeight)
                        
                        // Bar chart area
                        GeometryReader { chartGeo in
                            barChartArea(
                                width: chartGeo.size.width,
                                height: chartGeo.size.height,
                                barWidth: barWidth
                            )
                        }
                        .frame(height: chartHeight)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onHover { hovering in
                        if !hovering {
                            hoveredDay = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Month Labels
    
    @ViewBuilder
    private func monthLabels(availableWidth: CGFloat, barWidth: CGFloat) -> some View {
        let stepWidth = barWidth + barGap
        
        ZStack(alignment: .leading) {
            ForEach(Array(monthTransitions.enumerated()), id: \.offset) { _, transition in
                let x = CGFloat(transition.index) * stepWidth
                    Text(transition.label)
                        .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                    .position(x: x + 16, y: 7)
            }
        }
        .frame(width: availableWidth, alignment: .leading)
    }
    
    /// The first day index where a new month begins.
    private var monthTransitions: [(index: Int, label: String)] {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        
        var transitions: [(index: Int, label: String)] = []
        var lastMonth: String = ""
        
        for (index, day) in dayStacks.enumerated() {
            let month = monthFormatter.string(from: day.date)
            if month != lastMonth {
                transitions.append((index: index, label: month))
                lastMonth = month
            }
        }
        return transitions
    }
    
    /// The x-position for divider lines that separate months.
    /// Skips the first transition (day 0) since there's no preceding month to separate from.
    private func monthDividerPositions(stepWidth: CGFloat) -> [CGFloat] {
        monthTransitions
            .dropFirst()  // first entry is the first month itself, not a boundary
            .map { CGFloat($0.index) * stepWidth - barGap / 2 }
    }
    
    // MARK: - Bar Chart Area
    
    @ViewBuilder
    private func barChartArea(width: CGFloat, height: CGFloat, barWidth: CGFloat) -> some View {
        let stepWidth = barWidth + barGap
        let totalContentWidth = stepWidth * CGFloat(dayStacks.count) - barGap
        
        ZStack(alignment: .topLeading) {
            // Baseline
            Rectangle()
                .fill(Theme.Colors.divider.opacity(0.2))
                .frame(width: totalContentWidth, height: 1)
                .position(x: totalContentWidth / 2, y: height - 1)
            
            // Month divider lines — subtle vertical rules at each month boundary
            ForEach(Array(monthDividerPositions(stepWidth: stepWidth)), id: \.self) { xPos in
                Rectangle()
                    .fill(Theme.Colors.divider.opacity(0.3))
                    .frame(width: dividerWidth, height: height)
                    .position(x: xPos, y: height / 2)
            }
            
            // Bars
            HStack(alignment: .bottom, spacing: barGap) {
                ForEach(dayStacks) { day in
                    barView(for: day, barWidth: barWidth, maxChartHeight: height)
                        .frame(width: barWidth)
                }
            }
            .frame(width: totalContentWidth, alignment: .leading)
        }
        .frame(width: width, height: height, alignment: .bottomLeading)
    }
    
    // MARK: - Single Bar
    
    @ViewBuilder
    private func barView(for day: DayStack, barWidth: CGFloat, maxChartHeight: CGFloat) -> some View {
        let totalHours = day.totalHours
        let hasData = !day.segments.isEmpty
        let isToday = day.isToday
        let isHovered = hoveredDay?.id == day.id
        
        // Dimming: if a highlighted date is set, dim all bars except that day
        let isDimmed: Bool = {
            guard let highlighted = highlightedDate else { return false }
            return !Calendar.current.isDate(day.date, inSameDayAs: highlighted)
        }()
        
        let barOpacity: Double = {
            if isDimmed { return dimmedOpacity }
            return 1.0
        }()
        
        VStack(spacing: 0) {
            if hasData {
                // Stacked segments — proportional to max hours in the dataset
                let maxHours = dayStacks.map { $0.totalHours }.max() ?? 1
                let maxHeight = max(maxHours > 0 ? (totalHours / maxHours) * (maxChartHeight - 4) : 0, 4)
                
                VStack(spacing: 0) {
                    ForEach(day.segments) { segment in
                        let proportion = totalHours > 0 ? segment.hours / totalHours : 0
                        let segmentHeight = max(proportion * maxHeight, 2)
                        
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color(hex: segment.color).opacity(isHovered ? 1.0 : segmentOpacity))
                            .frame(height: segmentHeight)
                    }
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: barCornerRadius,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: barCornerRadius
                    )
                )
            } else {
                // Empty day — thin ghost mark
                Rectangle()
                    .fill(Theme.Colors.cardSurface.opacity(0.5))
                    .frame(height: emptyDayHeight)
            }
        }
        .frame(width: barWidth, alignment: .bottom)
        .opacity(barOpacity)
        .background(alignment: .bottom) {
            if isToday {
                Rectangle()
                    .fill(Theme.Colors.accentColor)
                    .frame(width: barWidth, height: 2)
                    .offset(y: 1)
            }
        }
        .overlay(alignment: .top) {
            if day.isMilestone {
                Image(systemName: "diamond.fill")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.milestone)
                    .offset(y: -3)
            }
        }
        .zIndex(hoveredDay?.id == day.id ? 10 : 0)
        .onHover { hovering in
            if hovering {
                hoveredDay = day
            } else if hoveredDay?.id == day.id {
                hoveredDay = nil
            }
        }
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
    for i in 0..<90 {
        guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
        var segments: [ProjectSegment] = []
        
        if Double.random(in: 0...1) > 0.2 {
            segments.append(ProjectSegment(projectID: projectA.id, projectName: projectA.name, emoji: projectA.emoji, color: projectA.color, hours: Double.random(in: 0.5...3)))
        }
        if Double.random(in: 0...1) > 0.4 {
            segments.append(ProjectSegment(projectID: projectB.id, projectName: projectB.name, emoji: projectB.emoji, color: projectB.color, hours: Double.random(in: 0.5...4)))
        }
        if Double.random(in: 0...1) > 0.3 {
            segments.append(ProjectSegment(projectID: projectC.id, projectName: projectC.name, emoji: projectC.emoji, color: projectC.color, hours: Double.random(in: 0.5...2.5)))
        }
        
        mockStacks.append(DayStack(date: date, segments: segments))
    }
    
    @State var hoveredDay: DayStack? = nil
    return Session90DayBarChartView(dayStacks: mockStacks.reversed(), hoveredDay: $hoveredDay)
        .padding()
        .frame(width: 900, height: 180)
        .background(Theme.Colors.background)
}