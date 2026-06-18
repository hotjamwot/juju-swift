import SwiftUI

/// DaySessionInfoPanel.swift
/// Purpose: Horizontal timeline rail-and-card panel below the 90-day stacked bar chart.
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
/// singletons because DayStack does not carry that enriched data. Could be refactored
/// to accept pre-resolved data if the data model is extended.
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
    
    /// Computes the rail start/end hours from the actual session times, with padding.
    /// Returns (startHour, endHour, totalHours) for the timeline window.
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
            return (start: 6, end: 23, total: 17)
        }
        let start = max(minHour - timelinePaddingHours, 0)
        let end = min(maxHour + timelinePaddingHours, 24)
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
        .cornerRadius(Theme.Design.blockCornerRadius)
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
                        let segmentColor = Color(hex: dayStack?.segments.first { $0.projectID == session.projectID }?.color ?? "#999999")
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
                        let segmentColor = Color(hex: dayStack?.segments.first { $0.projectID == session.projectID }?.color ?? "#999999")
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
                        segment: resolved.segment,
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
                        segment: resolved.segment,
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
        segment: ProjectSegment?,
        sessionCount: Int,
        activityDisplay: (name: String, sfSymbol: String),
        phaseName: String?,
        projectName: String,
        projectEmoji: String,
        noteLimit: Int
    ) -> some View {
        let cardW = adaptiveCardWidth(sessionCount: sessionCount)
        let projectColor = Color(hex: segment?.color ?? "#999999")
        
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
            RoundedRectangle(cornerRadius: Theme.Design.blockCornerRadius)
                .fill(Theme.Colors.surface)
        )
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
                let segment = dayStack?.segments.first { $0.projectID == session.projectID }
                let projectColor = Color(hex: segment?.color ?? "#999999")
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
        let segment: ProjectSegment?
        let activityDisplay: (name: String, sfSymbol: String)
        let phaseName: String?
        let projectName: String
        let projectEmoji: String
    }
    
    /// Resolves segment, activity display, phase name, project name, and emoji for a session.
    private func resolveCardData(for session: SessionRecord) -> CardData {
        let segment = dayStack?.segments.first { $0.projectID == session.projectID }
        let activityDisplay = ActivityTypeManager.shared.getActivityTypeDisplay(id: session.activityTypeID)
        let phaseName = ProjectManager.shared.getPhaseDisplay(projectID: session.projectID, phaseID: session.projectPhaseID)
        let projectName = segment?.projectName ?? "Unknown"
        let projectEmoji = segment?.emoji ?? "📁"
        
        return CardData(
            segment: segment,
            activityDisplay: activityDisplay,
            phaseName: phaseName,
            projectName: projectName,
            projectEmoji: projectEmoji
        )
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

// MARK: - Preview

#Preview("5 sessions – timeline rail") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    let writingProject = Project(name: "Writing", color: "#E15759", order: 0, emoji: "📝")
    let designProject = Project(name: "Design", color: "#4E79A7", order: 1, emoji: "🎨")
    let codingProject = Project(name: "Coding", color: "#59A14F", order: 2, emoji: "💻")
    
    let session1 = SessionRecord(
        id: UUID().uuidString,
        startDate: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: today)!,
        endDate: calendar.date(bySettingHour: 11, minute: 45, second: 0, of: today)!,
        projectID: writingProject.id,
        activityTypeID: "writing",
        action: "Draft intro chapter",
        isMilestone: true,
        notes: "Spent the morning refining the opening paragraphs. The narrative arc is starting to feel right."
    )
    
    let session2 = SessionRecord(
        id: UUID().uuidString,
        startDate: calendar.date(bySettingHour: 11, minute: 45, second: 0, of: today)!,
        endDate: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today)!,
        projectID: designProject.id,
        activityTypeID: "editing",
        action: "Wireframes for new layout",
        notes: ""
    )
    
    let session3 = SessionRecord(
        id: UUID().uuidString,
        startDate: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today)!,
        endDate: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: today)!,
        projectID: writingProject.id,
        activityTypeID: "writing",
        action: "Research for chapter two",
        notes: "Gathering sources on narrative structure in longform essays."
    )
    
    let session4 = SessionRecord(
        id: UUID().uuidString,
        startDate: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: today)!,
        endDate: calendar.date(bySettingHour: 18, minute: 30, second: 0, of: today)!,
        projectID: codingProject.id,
        activityTypeID: "coding",
        action: "API implementation",
        notes: "Built the session parsing pipeline and CSV export."
    )
    
    let session5 = SessionRecord(
        id: UUID().uuidString,
        startDate: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: today)!,
        endDate: calendar.date(bySettingHour: 21, minute: 30, second: 0, of: today)!,
        projectID: designProject.id,
        activityTypeID: "editing",
        action: "Revise chapter two",
        notes: "Tightened the middle section and cut redundant paragraphs."
    )
    
    let segments = [
        ProjectSegment(projectID: writingProject.id, projectName: writingProject.name, emoji: writingProject.emoji, color: writingProject.color, hours: 4.75),
        ProjectSegment(projectID: designProject.id, projectName: designProject.name, emoji: designProject.emoji, color: designProject.color, hours: 4.0),
        ProjectSegment(projectID: codingProject.id, projectName: codingProject.name, emoji: codingProject.emoji, color: codingProject.color, hours: 3.0)
    ]
    
    let dayStack = DayStack(
        date: today,
        segments: segments,
        isMilestone: true,
        sessions: [session1, session2, session3, session4, session5]
    )
    
    DaySessionInfoPanel(dayStack: dayStack)
        .padding()
        .frame(width: 800)
        .background(Theme.Colors.background)
}

#Preview("1 session") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    let project = Project(name: "Coding", color: "#59A14F", order: 0, emoji: "💻")
    
    let session = SessionRecord(
        id: UUID().uuidString,
        startDate: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today)!,
        endDate: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today)!,
        projectID: project.id,
        activityTypeID: "coding",
        action: "Full stack feature implementation",
        notes: "Shipped the new dashboard panel with timeline view."
    )
    
    let dayStack = DayStack(
        date: today,
        segments: [ProjectSegment(projectID: project.id, projectName: project.name, emoji: project.emoji, color: project.color, hours: 4.0)],
        sessions: [session]
    )
    
    DaySessionInfoPanel(dayStack: dayStack)
        .padding()
        .frame(width: 800)
        .background(Theme.Colors.background)
}

#Preview("Empty state") {
    DaySessionInfoPanel(dayStack: nil)
        .padding()
        .frame(width: 800)
        .background(Theme.Colors.background)
}
