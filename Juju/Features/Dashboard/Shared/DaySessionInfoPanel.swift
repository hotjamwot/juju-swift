import SwiftUI

/// DaySessionInfoPanel.swift
/// Purpose: Horizontal timeline rail-and-card panel below the 90-day timeline chart.
///
/// Connector behavior summary:
/// - Connectors use a vertical-first routing: vertical from the rail, then horizontal to card.
/// - `anchorOffset` (20px) places the card to the right of its anchor so connectors may start
///   vertical-only from the rail.
/// - When a card lies left of its anchor, the connector pivots at a minimum vertical reach
///   (`minVerticalReach`, ~28px) to avoid drawing underneath the card background.
/// - When exactly two sessions exist for a day, both default to the upper row.
///
/// Tuning knobs: see `anchorOffset`, `minVerticalReach`, `cardHeight`, and `cardToBarGap`.
/// AI Notes: Pure presentation view — resolves activity types and phase names via
/// singletons because DayStack does not carry that enriched data. Project colours
/// come from `DayStack.projects` (built by `ChartDataPreparer.prepare90DayTimeline`).
struct DaySessionInfoPanel: View {
    /// The day stack to display — driven by chart hover.
    let dayStack: DayStack?
    
    // MARK: - Timeline Constants
    
    /// Padding added to each side of the session time range (in hours).
    private let timelinePaddingHours: Double = 0.5
    /// Height of the thin timeline bar in points.
    private let barHeight: CGFloat = 2
    /// Fixed height for every session card (above or below the rail).
    private let cardHeight: CGFloat = 118
    /// Vertical gap between cards and the timeline bar.
    private let cardToBarGap: CGFloat = 52
    /// Small gap between connector line and card/rail edge.
    private let connectorInset: CGFloat = 2
    
    // MARK: - Dynamic Timeline Range
    
    /// Default day window for the rail — 7am to 7pm.
    private let defaultDayStartHour: Double = 7.0
    private let defaultDayEndHour: Double = 19.0
    
    /// Computes the rail start/end hours for the timeline window.
    ///
    /// The rail defaults to a 7am–7pm day. If any session falls outside that
    /// window, the rail stretches (with `timelinePaddingHours` of breathing
    /// room) to accommodate the earliest/latest session, so out-of-hours work
    /// is still visible without cramping in-hours days.
    private func computeTimelineRange(sessions: [SessionRecord]) -> (start: Double, end: Double, total: Double) {
        let calendar = Calendar.current
        let hours = sessions.flatMap { session -> [Double] in
            let startComps = calendar.dateComponents([.hour, .minute], from: session.startDate)
            let endComps = calendar.dateComponents([.hour, .minute], from: session.endDate)
            let startHour = Double(startComps.hour ?? 0) + Double(startComps.minute ?? 0) / 60.0
            let endHour = Double(endComps.hour ?? 0) + Double(endComps.minute ?? 0) / 60.0
            return [startHour, endHour]
        }
        guard let minHour = hours.min(), let maxHour = hours.max() else {
            return (start: defaultDayStartHour, end: defaultDayEndHour, total: defaultDayEndHour - defaultDayStartHour)
        }
        // Start with the default 7am–7pm window, then stretch only as far as
        // the sessions require (with padding). Clamp to the 0–24 day bounds.
        let start = max(min(minHour - timelinePaddingHours, defaultDayStartHour), 0)
        let end = min(max(maxHour + timelinePaddingHours, defaultDayEndHour), 24)
        return (start: start, end: end, total: end - start)
    }
    
    // MARK: - Formatting Helpers
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let day = dayStack {
                dayContent(day)
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
        .subtleShadow()
        .animation(.easeOut(duration: 0.12), value: dayStack?.id)
    }
    
    // MARK: - Placeholder
    
    @ViewBuilder
    private var placeholder: some View {
        EmptyView()
    }
    
    // MARK: - Day Content
    
    @ViewBuilder
    private func dayContent(_ day: DayStack) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            summaryBar(day)
            
            if day.sessions.isEmpty {
                Text("No sessions")
                    .font(Theme.Fonts.narrative)
                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                    .padding(.vertical, Theme.Spacing.xxs)
            } else {
                timelineContainer(day.sessions)
            }
        }
    }
    
    @ViewBuilder
    private func summaryBar(_ day: DayStack) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary)
            
            if day.totalHours > 0 {
                Text(formattedHours(day.totalHours) + " total")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.8))
            }
            
            Spacer()
            
            if day.isMilestone {
                HStack(spacing: Theme.Spacing.micro) {
                    Image(systemName: "star.fill")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.milestone)
                    Text("Milestone")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.milestone)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Design.blockCornerRadius)
                .fill(Theme.Colors.background)
        )
    }
    
    // MARK: - Timeline Container

    /// Lays out session cards positioned at their time on the rail, alternating above and below.
    /// Cards are aligned to the timeline; overlapping cards are nudged apart.
    /// Subtle neutral anchors and colour dots keep the rail lightweight.
    private func timelineContainer(_ sessions: [SessionRecord]) -> some View {
        let sorted = sessions.sorted(by: { $0.startDate < $1.startDate })
        let aboveSessions: [SessionRecord]
        let belowSessions: [SessionRecord]
        if sorted.count == 2 {
            aboveSessions = sorted
            belowSessions = []
        } else {
            aboveSessions = sorted.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
            belowSessions = sorted.enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
        }
        let range = computeTimelineRange(sessions: sorted)
        
        return GeometryReader { geo in
            let width = geo.size.width
            let noteLimit = notePreviewLength(sessionCount: sorted.count)
            let cardW = adaptiveCardWidth(sessionCount: sorted.count)
            let cardBackgroundWidth = cardW + Theme.Spacing.sm * 2
            let hasAbove = !aboveSessions.isEmpty
            let hasBelow = !belowSessions.isEmpty
            let topGap = hasAbove ? cardToBarGap : Theme.Spacing.lg
            let bottomGap = hasBelow ? cardToBarGap : Theme.Spacing.lg
            let railY = (hasAbove ? cardHeight : 0) + topGap + barHeight / 2
            let aboveCardTopY: CGFloat = 0
            let belowCardTopY = railY + barHeight / 2 + bottomGap
            let belowCardY = belowCardTopY + cardHeight / 2
            
            // Precompute time-based X positions with collision resolution
            let abovePositions = resolvedCardPositions(for: aboveSessions, width: width, range: range, cardBackgroundWidth: cardBackgroundWidth)
            let belowPositions = resolvedCardPositions(for: belowSessions, width: width, range: range, cardBackgroundWidth: cardBackgroundWidth)
            
            ZStack(alignment: .topLeading) {
                // Time markers — subtle hour ticks along the rail
                timeMarkers(width: width, railY: railY, range: range)
                
                // Timeline bar
                timelineBar(sessions: sorted, width: width, range: range)
                    .frame(width: width, height: barHeight)
                    .position(x: width / 2, y: railY)
                
                Group {
                    // Connector lines — above cards: ensure a minimum upward reach when card lies left of anchor
                    ForEach(Array(aboveSessions.enumerated()), id: \.element.id) { index, session in
                        let cardCenterX = abovePositions[index]
                        let cardLeftX = max(cardCenterX - cardBackgroundWidth / 2, Theme.Spacing.xl)
                        let anchorX = xPosition(for: session, width: width, range: range)
                        let connectorColor = Theme.Colors.textSecondary.opacity(0.18)
                        let segmentColor = Color(hex: projectInfo(for: session)?.color ?? "#999999")
                        let targetY = aboveCardTopY + cardHeight * 0.28

                        // If the card is to the left of the anchor, force a sensible vertical reach
                        let minVerticalReach: CGFloat = 28
                        if cardLeftX < anchorX {
                            let pivotY = railY - minVerticalReach
                            Path { path in
                                path.move(to: CGPoint(x: anchorX, y: railY))
                                path.addLine(to: CGPoint(x: anchorX, y: pivotY))
                                path.addLine(to: CGPoint(x: cardLeftX, y: pivotY))
                                path.addLine(to: CGPoint(x: cardLeftX, y: targetY))
                            }
                            .strokedPath(StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                            .foregroundColor(connectorColor)
                        } else {
                            Path { path in
                                path.move(to: CGPoint(x: anchorX, y: railY))
                                path.addLine(to: CGPoint(x: anchorX, y: targetY))
                                path.addLine(to: CGPoint(x: cardLeftX, y: targetY))
                            }
                            .strokedPath(StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                            .foregroundColor(connectorColor)
                        }

                        Circle()
                            .fill(segmentColor)
                            .frame(width: 6, height: 6)
                            .position(x: anchorX, y: railY)
                    }

                    // Connector lines — below cards: ensure a minimum downward reach when card lies left of anchor
                    ForEach(Array(belowSessions.enumerated()), id: \.element.id) { index, session in
                        let cardCenterX = belowPositions[index]
                        let cardLeftX = max(cardCenterX - cardBackgroundWidth / 2, Theme.Spacing.xl)
                        let anchorX = xPosition(for: session, width: width, range: range)
                        let connectorColor = Theme.Colors.textSecondary.opacity(0.18)
                        let segmentColor = Color(hex: projectInfo(for: session)?.color ?? "#999999")
                        let targetY = belowCardTopY + cardHeight * 0.28

                        let minVerticalReach: CGFloat = 28
                        if cardLeftX < anchorX {
                            let pivotY = railY + minVerticalReach
                            Path { path in
                                path.move(to: CGPoint(x: anchorX, y: railY))
                                path.addLine(to: CGPoint(x: anchorX, y: pivotY))
                                path.addLine(to: CGPoint(x: cardLeftX, y: pivotY))
                                path.addLine(to: CGPoint(x: cardLeftX, y: targetY))
                            }
                            .strokedPath(StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                            .foregroundColor(connectorColor)
                        } else {
                            Path { path in
                                path.move(to: CGPoint(x: anchorX, y: railY))
                                path.addLine(to: CGPoint(x: anchorX, y: targetY))
                                path.addLine(to: CGPoint(x: cardLeftX, y: targetY))
                            }
                            .strokedPath(StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                            .foregroundColor(connectorColor)
                        }

                        Circle()
                            .fill(segmentColor)
                            .frame(width: 6, height: 6)
                            .position(x: anchorX, y: railY)
                    }
                }

                // Above cards — positioned at session time
                ForEach(Array(aboveSessions.enumerated()), id: \.element.id) { index, session in
                    let resolved = resolveCardData(for: session)
                    
                    timelineCard(
                        session: session,
                        project: resolved.project,
                        sessionCount: sorted.count,
                        activityDisplay: resolved.activityDisplay,
                        phaseName: resolved.phaseName,
                        projectName: resolved.projectName,
                        projectEmoji: resolved.projectEmoji,
                        noteLimit: noteLimit
                    )
                    .position(x: abovePositions[index], y: cardHeight / 2)
                }
                
                // Below cards — positioned at session time
                ForEach(Array(belowSessions.enumerated()), id: \.element.id) { index, session in
                    let resolved = resolveCardData(for: session)
                    
                    timelineCard(
                        session: session,
                        project: resolved.project,
                        sessionCount: sorted.count,
                        activityDisplay: resolved.activityDisplay,
                        phaseName: resolved.phaseName,
                        projectName: resolved.projectName,
                        projectEmoji: resolved.projectEmoji,
                        noteLimit: noteLimit
                    )
                    .position(x: belowPositions[index], y: belowCardY)
                }
            }
        }
        .frame(height: panelHeight(hasAbove: !aboveSessions.isEmpty, hasBelow: !belowSessions.isEmpty))
    }
    
    // MARK: - Session Card
    
    @ViewBuilder
    private func timelineCard(
        session: SessionRecord,
        project: DayProjectInfo?,
        sessionCount: Int,
        activityDisplay: (name: String, sfSymbol: String),
        phaseName: String?,
        projectName: String,
        projectEmoji: String,
        noteLimit: Int
    ) -> some View {
        let cardW = adaptiveCardWidth(sessionCount: sessionCount)
        let projectColor = Color(hex: project?.color ?? "#999999")
        
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Row 1: Project emoji + name | Phase pill + milestone
            HStack(alignment: .center) {
                HStack(spacing: Theme.Spacing.micro) {
                    Text(projectEmoji)
                        .font(Theme.Fonts.caption)
                    Text(projectName)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(projectColor)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: Theme.Spacing.xs) {
                    if let phaseName = phaseName {
                        Text(phaseName)
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Theme.Colors.background)
                            )
                    }
                    
                    if session.isMilestone {
                        Image(systemName: "star.fill")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.milestone)
                            .milestonePulse()
                    }
                }
            }
            
            // Row 2: Action text
            if let action = session.action, !action.isEmpty {
                Text(action)
                    .font(Theme.Fonts.body.weight(.semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
            }
            
            if !session.notes.isEmpty {
                Text(String(session.notes.prefix(noteLimit)))
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(3)
                    .padding(.bottom, Theme.Spacing.xs)
            }

            HStack(alignment: .center) {
                HStack(spacing: Theme.Spacing.micro) {
                    Image(systemName: activityDisplay.sfSymbol)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text(activityDisplay.name)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: Theme.Spacing.micro) {
                    Text("\(Self.timeFormatter.string(from: session.startDate))–\(Self.timeFormatter.string(from: session.endDate))")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Text("•")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))
                    
                    Text(formattedDuration(session.durationMinutes))
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .frame(width: cardW, height: cardHeight, alignment: .topLeading)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .fill(Theme.Colors.surface)
        )
        .hoverLift()
    }
    
    // MARK: - Timeline Bar
    
    @ViewBuilder
    private func timelineBar(sessions: [SessionRecord], width: CGFloat, range: (start: Double, end: Double, total: Double)) -> some View {
        ZStack(alignment: .leading) {
            // Base line
            Rectangle()
                .fill(Theme.Colors.divider.opacity(0.24))
                .cornerRadius(barHeight / 2)
            
            // Coloured segments
            ForEach(sessions) { session in
                let projectColor = Color(hex: projectInfo(for: session)?.color ?? "#999999")
                let widthForSession = barWidth(for: session, width: width, range: range)
                let centerX = xPosition(for: session, width: width, range: range) + widthForSession / 2
                
                Rectangle()
                    .fill(projectColor)
                    .frame(width: widthForSession, height: barHeight)
                    .position(x: centerX, y: barHeight / 2)
                    .cornerRadius(barHeight / 2)
            }
        }
        .frame(width: width, height: barHeight)
    }
    
    // MARK: - Time Markers
    
    /// Subtle hour ticks and labels along the timeline rail.
    @ViewBuilder
    private func timeMarkers(width: CGFloat, railY: CGFloat, range: (start: Double, end: Double, total: Double)) -> some View {
        let markerCount = 4
        let step = range.total / Double(markerCount - 1)
        
        ForEach(0..<markerCount, id: \.self) { i in
            let hourOffset = Double(i) * step
            let x = (hourOffset / range.total) * width
            let hour = range.start + hourOffset
            let label = formatRailHour(hour)
            
            // Tick mark
            Rectangle()
                .fill(Theme.Colors.divider.opacity(0.2))
                .frame(width: 1, height: 4)
                .position(x: x, y: railY)
            
            // Label
            Text(label)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.35))
                .position(x: x, y: railY + barHeight / 2 + 11)
        }
    }
    
    /// Formats a decimal hour value into a compact rail label (e.g. "9a", "12p", "3p").
    private func formatRailHour(_ hour: Double) -> String {
        let h = Int(floor(hour))
        let m = Int(round((hour - Double(h)) * 60))
        let totalMinutes = h * 60 + m
        let period = totalMinutes < 720 ? "a" : "p"
        var displayH = h
        if displayH == 0 { displayH = 12 }
        else if displayH > 12 { displayH -= 12 }
        if m >= 30 {
            return "\(displayH):30\(period)"
        }
        return "\(displayH)\(period)"
    }
    
    // MARK: - Data Resolution
    
    /// Bundles all resolved data for a session card to avoid repeated lookups in the ForEach body.
    private struct CardData {
        let project: DayProjectInfo?
        let activityDisplay: (name: String, sfSymbol: String)
        let phaseName: String?
        let projectName: String
        let projectEmoji: String
    }
    
    /// Resolves project info, activity display, phase name, project name, and emoji for a session.
    private func resolveCardData(for session: SessionRecord) -> CardData {
        let project = projectInfo(for: session)
        let activityDisplay = ActivityTypeManager.shared.getActivityTypeDisplay(id: session.activityTypeID)
        let phaseName = ProjectManager.shared.getPhaseDisplay(projectID: session.projectID, phaseID: session.projectPhaseID)
        let projectName = project?.name ?? "Unknown"
        let projectEmoji = project?.emoji ?? "📁"
        
        return CardData(
            project: project,
            activityDisplay: activityDisplay,
            phaseName: phaseName,
            projectName: projectName,
            projectEmoji: projectEmoji
        )
    }
    
    /// Looks up the resolved project info for a session from the day's project lookups.
    private func projectInfo(for session: SessionRecord) -> DayProjectInfo? {
        dayStack?.projects.first { $0.id == session.projectID }
    }
    
    // MARK: - Positioning Helpers
    
    /// Calculates time-based X positions for cards, nudging overlapping cards apart.
    private func resolvedCardPositions(for sessions: [SessionRecord], width: CGFloat, range: (start: Double, end: Double, total: Double), cardBackgroundWidth: CGFloat) -> [CGFloat] {
        guard !sessions.isEmpty else { return [] }
        
        let minGap: CGFloat = Theme.Spacing.md
        let minSpacing = cardBackgroundWidth + minGap
        let margin = cardBackgroundWidth / 2 + Theme.Spacing.xl
        
        // Desired center positions based on the session start anchor.
        // Cards sit a fixed distance to the right of the anchor so the connector can
        // run straight vertical and then turn once to the card's left edge.
        let anchorOffset: CGFloat = 20
        var desired: [(originalIndex: Int, x: CGFloat)] = sessions.enumerated().map { i, session in
            let anchorX = xPosition(for: session, width: width, range: range)
            let center = anchorX + anchorOffset + cardBackgroundWidth / 2
            return (originalIndex: i, x: center)
        }
        
        desired.sort { $0.x < $1.x }
        
        // Start from desired positions and resolve overlaps in both directions.
        var positions = desired.map { min(max($0.x, margin), width - margin) }
        for i in 1..<positions.count {
            positions[i] = max(positions[i], positions[i - 1] + minSpacing)
        }
        for i in (0..<(positions.count - 1)).reversed() {
            positions[i] = min(positions[i], positions[i + 1] - minSpacing)
        }
        
        // Clamp to available width and keep cards within bounds.
        for i in positions.indices {
            positions[i] = min(max(positions[i], margin), width - margin)
        }

        // One final pass to respect both sides after clamping.
        for i in 1..<positions.count {
            positions[i] = max(positions[i], positions[i - 1] + minSpacing)
        }
        
        var result = Array(repeating: CGFloat(0), count: sessions.count)
        for (sortIndex, item) in desired.enumerated() {
            result[item.originalIndex] = positions[sortIndex]
        }
        return result
    }
    
    /// Calculates the X offset for the left edge of a session's bar on the timeline.
    private func xPosition(for session: SessionRecord, width: CGFloat, range: (start: Double, end: Double, total: Double)) -> CGFloat {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: session.startDate)
        let startHour = Double(startComponents.hour ?? 0) + Double(startComponents.minute ?? 0) / 60.0
        
        let clamped = max(range.start, min(startHour, range.end))
        let proportion = (clamped - range.start) / range.total
        return proportion * width
    }
    
    /// Calculates the bar width proportional to the session's duration within the timeline.
    private func barWidth(for session: SessionRecord, width: CGFloat, range: (start: Double, end: Double, total: Double)) -> CGFloat {
        let proportion = Double(session.durationMinutes) / (range.total * 60.0)
        return max(proportion * width, 4)
    }
    
    // MARK: - Adaptive Sizing
    
    /// Returns the ideal card width based on session count.
    private func adaptiveCardWidth(sessionCount: Int) -> CGFloat {
        switch sessionCount {
        case 1...2: return 380
        case 3...4: return 320
        default:    return 260
        }
    }
    
    /// Returns the maximum character count for the notes preview based on session count.
    private func notePreviewLength(sessionCount: Int) -> Int {
        switch sessionCount {
        case 1...2: return 160
        case 3...4: return 130
        default:    return 100
        }
    }
    
    /// Fixed panel height: above cards + gap + rail + gap + below cards.
    private func panelHeight(hasAbove: Bool, hasBelow: Bool) -> CGFloat {
        let topSection = (hasAbove ? cardHeight : 0) + cardToBarGap
        let bottomSection = (hasBelow ? cardHeight : 0) + cardToBarGap
        return topSection + barHeight + bottomSection
    }
    
    // MARK: - Formatting
    
    private func formattedHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
    
    private func formattedDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(m)m"
    }
}

