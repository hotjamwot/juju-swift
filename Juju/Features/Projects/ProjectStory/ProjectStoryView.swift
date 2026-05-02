/// ProjectStoryView.swift
/// Purpose: Read-only narrative timeline for a single project.
/// AI Notes: Pure presentation; consumes ProjectStoryViewModel-derived items.

import SwiftUI

struct ProjectStoryView: View {
    let projectID: String
    let onExit: () -> Void

    @StateObject private var projectsViewModel = ProjectsViewModel.shared
    @StateObject private var sessionManager = SessionManager.shared

    @StateObject private var viewModel: ProjectStoryViewModel

    init(projectID: String, onExit: @escaping () -> Void) {
        self.projectID = projectID
        self.onExit = onExit

        _viewModel = StateObject(wrappedValue: ProjectStoryViewModel(
            projectID: projectID,
            projectsProvider: { ProjectsViewModel.shared.projects },
            sessionsProvider: { SessionManager.shared.allSessions }
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLarge) {
                    if let header = viewModel.header {
                        ProjectStoryHeaderView(header: header)
                            .padding(.top, Theme.spacingLarge)
                    }

                    if viewModel.isEmpty {
                        emptyState
                    } else {
                        // 1) Summary stats row
                        if let summary = viewModel.summary, let header = viewModel.header {
                            ProjectStorySummaryRowView(summary: summary, projectColorHex: header.colorHex)
                        }

                        // 2) Phase timeline bar + milestone pins + labels/ticks
                        if let header = viewModel.header, !viewModel.phaseTimeline.isEmpty {
                            ProjectStoryPhaseTimelineView(
                                segments: viewModel.phaseTimeline,
                                phaseBoundaries: viewModel.phaseBoundaries,
                                projectColorHex: header.colorHex
                            )
                        }

                        // 3) Full-project intensity + mood chart
                        if let header = viewModel.header, !viewModel.projectSessions.isEmpty {
                            ProjectStoryIntensityMoodChartView(
                                sessions: viewModel.projectSessions,
                                orderedPhaseIDs: viewModel.phaseTimeline.map(\.id),
                                projectColorHex: header.colorHex
                            )
                        }

                        // 4) Gaps only (chapters removed; redundant with bar + chart + notable moments)
                        ForEach(viewModel.items.compactMap { item -> ProjectStoryViewModel.Gap? in
                            if case .gap(let g) = item { return g }
                            return nil
                        }) { gap in
                            ProjectStoryGapView(gap: gap)
                        }

                        // 5) Notable moments
                        if let header = viewModel.header, !viewModel.allMilestones.isEmpty {
                            ProjectStoryNotableMomentsView(
                                milestones: viewModel.allMilestones,
                                projectColorHex: header.colorHex
                            )
                        }
                    }
                }
                .padding(.horizontal, Theme.spacingLarge)
                .padding(.bottom, Theme.spacingLarge)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Theme.Colors.background)
        .onAppear {
            viewModel.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .projectsDidChange)) { _ in
            viewModel.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { _ in
            viewModel.reload()
        }
    }

    private var headerBar: some View {
        HStack(spacing: Theme.spacingMedium) {
            Button {
                onExit()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("Projects")
                }
                .font(Theme.Fonts.caption.weight(.semibold))
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.Colors.divider.opacity(0.25))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .pointingHandOnHover()

            Spacer()
        }
        .padding(.horizontal, Theme.spacingLarge)
        .padding(.vertical, Theme.spacingMedium)
        .background(Theme.Colors.background)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.spacingMedium) {
            Text("No Sessions Yet")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)

            Text("When you record time against this project, its story will appear here.")
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

// MARK: - Subviews

private struct ProjectStoryHeaderView: View {
    let header: ProjectStoryViewModel.Header

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(header.emoji)
                    .font(.system(size: 28))

                Text(header.projectName)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            if let about = header.about?.trimmingCharacters(in: .whitespacesAndNewlines),
               !about.isEmpty {
                Text(about)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                if let start = header.startDate {
                    Text("Started \(dateFormatter.string(from: start))")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                if let end = header.endDate, let start = header.startDate {
                    Text("·")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))

                    Text("\(dateFormatter.string(from: end))")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)

                    Text("·")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))

                    Text(durationDescription(from: start, to: end))
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .padding(.bottom, Theme.spacingLarge)
    }

    private func durationDescription(from start: Date, to end: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        if days < 7 { return "\(max(days, 1)) days" }
        let weeks = Int(Double(days) / 7.0.rounded(.down))
        if weeks < 8 { return "\(weeks) weeks" }
        let months = Int(Double(days) / 30.0.rounded(.down))
        return "\(max(months, 1)) months"
    }
}

private struct ProjectStorySummaryRowView: View {
    let summary: ProjectStoryViewModel.SummaryStats
    let projectColorHex: String

    var body: some View {
        HStack(spacing: Theme.spacingSmall) {
            StoryMetricCard(title: "Total time") {
                Text(durationString(fromMinutes: summary.totalDurationMinutes))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            StoryMetricCard(title: "Sessions") {
                Text("\(summary.totalSessions)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            StoryMetricCard(title: "Average mood") {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(moodValueString(summary.averageMood))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("/10")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            StoryMetricCard(title: "Phases") {
                Text("\(summary.phaseCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
        }
        .padding(.bottom, Theme.spacingLarge)
    }

    private func durationString(fromMinutes minutes: Int) -> String {
        let h = max(minutes, 0) / 60
        let m = max(minutes, 0) % 60
        return "\(h)h \(m)m"
    }

    private func moodValueString(_ mood: Double?) -> String {
        guard let mood else { return "—" }
        return String(format: "%.1f", mood)
    }
}

private struct StoryMetricCard: View {
    let title: String
    let content: () -> AnyView

    init(title: String, @ViewBuilder content: @escaping () -> some View) {
        self.title = title
        self.content = { AnyView(content()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.Fonts.caption.weight(.semibold))
                .foregroundColor(Theme.Colors.textSecondary)

            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface.opacity(0.7))
        .cornerRadius(10)
    }
}

private struct ProjectStoryPhaseTimelineView: View {
    let segments: [ProjectStoryViewModel.PhaseSegment]
    let phaseBoundaries: [Date]
    let projectColorHex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phase timeline")
                .font(Theme.Fonts.caption.weight(.semibold))
                .foregroundColor(Theme.Colors.textSecondary)

            GeometryReader { geo in
                ZStack {
                    // Layer 1 — Bar itself
                    HStack(spacing: 0) {
                        ForEach(segments.indices, id: \.self) { idx in
                            let seg = segments[idx]
                            Rectangle()
                                .fill(phaseColor(index: idx, for: seg))
                                .opacity(seg.isArchivedPhase ? 0.45 : 1.0)
                                .frame(width: max(1, geo.size.width * seg.fractionOfTotal))
                        }
                    }
                    .frame(height: 34)
                    .background(Theme.Colors.surface.opacity(0.5))
                    .cornerRadius(6)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .frame(height: 34)

            // Layer 3 — Phase labels beneath segments (suppressed if narrow)
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(segments.indices, id: \.self) { idx in
                        let seg = segments[idx]
                        let startFrac = startFraction(for: idx)
                        let w = geo.size.width * seg.fractionOfTotal
                        let mid = geo.size.width * (startFrac + (seg.fractionOfTotal / 2))

                        if w >= 50 {
                            Text(seg.title)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .position(x: mid, y: 8)
                        }
                    }
                }
            }
            .frame(height: 16)

            // Date ticks beneath labels (start/end + phase boundaries)
            ProjectStoryTimelineTicksView(
                projectStart: nil,
                projectEnd: nil,
                phaseBoundaries: phaseBoundaries,
                projectColorHex: projectColorHex
            )
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Theme.Colors.surface.opacity(0.6))
        .cornerRadius(10)
    }

    private func phaseColor(index: Int, for seg: ProjectStoryViewModel.PhaseSegment) -> Color {
        ColorFamily.projectHueRotated(baseHex: projectColorHex, stepDegrees: 30)[safe: index] ?? Color(hex: projectColorHex)
    }

    private func startFraction(for index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        let sum = segments.prefix(index).reduce(0.0) { $0 + $1.fractionOfTotal }
        return CGFloat(sum)
    }
}

private struct ProjectStoryGapView: View {
    let gap: ProjectStoryViewModel.Gap

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    var body: some View {
        HStack(spacing: 12) {
            DashedDivider()
            VStack(spacing: 6) {
                Text(gapDurationDescription(days: gap.days))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("\(dateFormatter.string(from: gap.startDate)) → \(dateFormatter.string(from: gap.endDate))")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            DashedDivider()
        }
        .padding(.vertical, 26)
    }

    private func gapDurationDescription(days: Int) -> String {
        if days < 14 { return "\(days) days away" }
        if days < 60 {
            let weeks = Int(Double(days) / 7.0.rounded(.down))
            return "\(max(weeks, 2)) weeks away"
        }
        let months = Int(Double(days) / 30.0.rounded(.down))
        return "\(max(months, 2)) months away"
    }
}

private struct DashedDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 1)
            .overlay(
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundColor(Theme.Colors.divider.opacity(0.7))
            )
    }
}

private struct ProjectStoryTimelineTicksView: View {
    let projectStart: Date?
    let projectEnd: Date?
    let phaseBoundaries: [Date]
    let projectColorHex: String

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if let start = projectStart, let end = projectEnd, end > start {
                    // Start + end ticks
                    tick(x: 0, text: df.string(from: start))
                    tick(x: geo.size.width, text: df.string(from: end), alignTrailing: true)

                    // Phase boundary ticks
                    ForEach(phaseBoundaries, id: \.timeIntervalSince1970) { d in
                        let x = geo.size.width * fraction(d, start: start, end: end)
                        tick(x: x, text: df.string(from: d))
                    }
                } else {
                    // When start/end aren't provided, render boundary labels at even spacing.
                    ForEach(Array(phaseBoundaries.enumerated()), id: \.offset) { idx, d in
                        let t = CGFloat(idx + 1) / CGFloat(max(phaseBoundaries.count + 1, 1))
                        tick(x: geo.size.width * t, text: df.string(from: d))
                    }
                }
            }
        }
        .frame(height: 12)
    }

    private func fraction(_ date: Date, start: Date, end: Date) -> CGFloat {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return CGFloat(min(max(date.timeIntervalSince(start) / total, 0), 1))
    }

    private func tick(x: CGFloat, text: String, alignTrailing: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundColor(Theme.Colors.textSecondary.opacity(0.55))
            .position(x: x + (alignTrailing ? -18 : 18), y: 6)
    }
}

private struct ProjectStoryIntensityMoodChartView: View {
    let sessions: [SessionRecord]
    let orderedPhaseIDs: [String]
    let projectColorHex: String

    private let phaseIndexByID: [String: Int]

    init(sessions: [SessionRecord], orderedPhaseIDs: [String], projectColorHex: String) {
        self.sessions = sessions
        self.orderedPhaseIDs = orderedPhaseIDs
        self.projectColorHex = projectColorHex
        self.phaseIndexByID = Dictionary(uniqueKeysWithValues: orderedPhaseIDs.enumerated().map { ($0.element, $0.offset) })
    }

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    let count = max(sessions.count, 1)
                    let gap: CGFloat = 1
                    let raw = (geo.size.width / CGFloat(count)) - gap
                    let barW = max(1.5, raw)
                    let maxMinutes = max(sessions.map(\.durationMinutes).max() ?? 1, 1)

                    HStack(alignment: .bottom, spacing: gap) {
                        ForEach(sessions, id: \.id) { s in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(barFill(for: s, projectColorHex: projectColorHex))
                                .frame(width: barW, height: barHeight(minutes: s.durationMinutes, maxMinutes: maxMinutes))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .frame(height: 72)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Theme.Colors.surface.opacity(0.6))
            .cornerRadius(10)

            HStack {
                Text(labelStart)
                Spacer()
                Text(labelMid)
                Spacer()
                Text(labelEnd)
            }
            .font(.system(size: 9))
            .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))

            Text("Bar height = time worked · Opacity = mood")
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.55))
        }
        .padding(.bottom, Theme.spacingLarge)
    }

    private var labelStart: String {
        if let d = sessionStartDate { return df.string(from: d) }
        return ""
    }

    private var labelEnd: String {
        if let d = sessionEndDate { return df.string(from: d) }
        return ""
    }

    private var labelMid: String {
        guard let start = sessionStartDate, let end = sessionEndDate, end > start else { return "" }
        let mid = start.addingTimeInterval((end.timeIntervalSince(start) / 2))
        return df.string(from: mid)
    }

    private var sessionStartDate: Date? {
        sessions.min(by: { $0.startDate < $1.startDate })?.startDate
    }

    private var sessionEndDate: Date? {
        sessions.max(by: { $0.endDate < $1.endDate })?.endDate
    }

    private func barHeight(minutes: Int, maxMinutes: Int) -> CGFloat {
        let t = CGFloat(Swift.max(minutes, 0)) / CGFloat(Swift.max(maxMinutes, 1))
        return 6 + (t * (48 - 6))
    }

    private func barFill(for session: SessionRecord, projectColorHex: String) -> Color {
        if session.isMilestone {
            return Color(hex: "F5A623").opacity(1.0)
        }

        let phaseColors = ColorFamily.projectHueRotated(baseHex: projectColorHex, stepDegrees: 30)
        let phaseIndex = session.projectPhaseID.flatMap { phaseIndexByID[$0] }
        let base = Color(hex: projectColorHex)
        let phaseColor = phaseIndex.flatMap { idx in phaseColors[safe: idx] } ?? base
        if let mood = session.mood {
            return phaseColor.opacity(moodOpacity(Double(mood)))
        }
        // Nil mood fallback should not "penalise" visibility.
        return phaseColor.opacity(0.45)
    }

    private func moodOpacity(_ mood: Double) -> Double {
        switch mood {
        case ..<0: return 0.45
        case 0...2: return 0.15
        case 3...4: return 0.30
        case 5...6: return 0.50
        case 7...8: return 0.75
        case 9...10: return 1.0
        default: return 1.0
        }
    }

}

private struct ProjectStoryNotableMomentsView: View {
    let milestones: [ProjectStoryViewModel.Milestone]
    let projectColorHex: String

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            Text("Notable moments")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)

            VStack(spacing: Theme.spacingSmall) {
                ForEach(milestones) { m in
                    NotableMomentCard(milestone: m, projectColorHex: projectColorHex, dateText: df.string(from: m.date))
                }
            }
        }
        .padding(.top, Theme.spacingLarge)
    }
}

private struct NotableMomentCard: View {
    let milestone: ProjectStoryViewModel.Milestone
    let projectColorHex: String
    let dateText: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color(hex: projectColorHex))
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        PhasePill(title: milestone.phaseTitle, colorHex: projectColorHex)
                        Text(dateText)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.65))
                        Spacer()
                    }

                    Text(milestone.action)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Theme.Colors.surface.opacity(0.65))
            .cornerRadius(10)

            Image(systemName: "star.fill")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: projectColorHex))
                .padding(10)
        }
    }
}

private struct PhasePill: View {
    let title: String
    let colorHex: String

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color(hex: colorHex))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: colorHex).opacity(0.15))
            .cornerRadius(999)
    }
}

private enum ColorFamily {
    static func projectHueRotated(baseHex: String, stepDegrees: CGFloat) -> [Color] {
        guard let base = NSColor(hex: baseHex)?.usingColorSpace(.deviceRGB) else {
            return Array(repeating: Color(hex: baseHex), count: 16)
        }

        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        base.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        // Keep saturation/brightness close to source (±15%), rotate hue only.
        let sat = clampAroundSource(s, percent: 0.15)
        let bri = clampAroundSource(b, percent: 0.15)

        return (0..<16).map { i in
            let deg = stepDegrees * CGFloat(i)
            let newHue = (h + (deg / 360.0)).truncatingRemainder(dividingBy: 1.0)
            return Color(NSColor(hue: newHue, saturation: sat, brightness: bri, alpha: 1.0))
        }
    }

    private static func clampAroundSource(_ value: CGFloat, percent: CGFloat) -> CGFloat {
        // If the source is near-zero, keep it near-zero rather than forcing vivid colours.
        guard value > 0 else { return 0 }
        let lo = max(0, value * (1 - percent))
        let hi = min(1, value * (1 + percent))
        return min(max(value, lo), hi)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

