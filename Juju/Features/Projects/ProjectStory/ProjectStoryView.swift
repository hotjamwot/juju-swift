/// ProjectStoryView.swift
/// Purpose: Read-only narrative timeline for a single project.
/// AI Notes: Pure presentation; consumes ProjectStoryViewModel-derived items.
///
/// "The Braid" — a dual-track timeline. The top track (spine) is a
/// chronological bar chart of sessions coloured by phase. The bottom tracks
/// are one lane per phase with marks positioned by date — honest about the
/// fact that phases aren't always chronological (they can be sub-projects,
/// collaborators, or interleaved).

import SwiftUI

struct ProjectStoryView: View {
    let projectID: String
    let onExit: () -> Void

    @StateObject private var projectsViewModel = ProjectsViewModel.shared
    @StateObject private var sessionManager = SessionManager.shared

    @StateObject private var viewModel: ProjectStoryViewModel
    @State private var highlightedPhaseID: String? = nil

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

                        // 2) The Braid — spine + phase lanes + detail panel
                        if let header = viewModel.header, !viewModel.projectSessions.isEmpty {
                            ProjectStoryBraidView(
                                sessions: viewModel.projectSessions,
                                lanes: viewModel.phaseLanes,
                                projectColorHex: header.colorHex,
                                projectStart: header.startDate,
                                projectEnd: header.endDate,
                                highlightedPhaseID: $highlightedPhaseID
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
                Image(systemName: "chevron.left")
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.Colors.divider.opacity(0.25))
                    .cornerRadius(Theme.Design.blockCornerRadius)
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
                .font(Theme.Fonts.title)
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
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text(header.emoji)
                    .font(Theme.Fonts.hero)

                Text(header.projectName)
                    .font(Theme.Fonts.hero)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            if let about = header.about?.trimmingCharacters(in: .whitespacesAndNewlines),
               !about.isEmpty {
                Text(about)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Theme.Spacing.micro)
            }

            HStack(spacing: Theme.Spacing.sm) {
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
                    .font(Theme.Fonts.title)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            StoryMetricCard(title: "Sessions") {
                Text("\(summary.totalSessions)")
                    .font(Theme.Fonts.title)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            StoryMetricCard(title: "Average mood") {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
                    Text(moodValueString(summary.averageMood))
                        .font(Theme.Fonts.title)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("/10")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            StoryMetricCard(title: "Phases") {
                Text("\(summary.phaseCount)")
                    .font(Theme.Fonts.title)
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
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(title)
                .font(Theme.Fonts.caption.weight(.semibold))
                .foregroundColor(Theme.Colors.textSecondary)

            content()
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface.opacity(0.7))
        .cornerRadius(Theme.Row.cornerRadius)
    }
}

// MARK: - The Braid

/// The core "Braid" component: a chronological session spine on top, with one
/// lane per phase beneath. Hovering a lane highlights its bars in the spine
/// and reveals a pinned `PhaseDetailPanel`.
private struct ProjectStoryBraidView: View {
    let sessions: [SessionRecord]
    let lanes: [ProjectStoryViewModel.PhaseLane]
    let projectColorHex: String
    let projectStart: Date?
    let projectEnd: Date?
    @Binding var highlightedPhaseID: String?

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Spine — chronological session bars
            spine

            // Phase lanes — one row per phase, marks positioned by date
            VStack(spacing: Theme.Spacing.xxs) {
                ForEach(lanes) { lane in
                    PhaseLaneRow(
                        lane: lane,
                        projectColorHex: projectColorHex,
                        projectStart: projectStart,
                        projectEnd: projectEnd,
                        isHighlighted: highlightedPhaseID == lane.id,
                        anyPhaseHighlighted: highlightedPhaseID != nil,
                        onHover: { id in
                            withAnimation(.easeOut(duration: 0.15)) {
                                highlightedPhaseID = id
                            }
                        }
                    )
                }
            }

            // Axis labels — start / mid / end
            axisLabels

            // Pinned detail panel for the highlighted phase
            if let highlightedPhaseID,
               let lane = lanes.first(where: { $0.id == highlightedPhaseID }) {
                PhaseDetailPanel(lane: lane, projectColorHex: projectColorHex)
                    .transition(.opacity)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.surface.opacity(0.6))
        .cornerRadius(Theme.Row.cornerRadius)
        .animation(.easeOut(duration: 0.15), value: highlightedPhaseID)
    }

    // MARK: Spine

    private var spine: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                let maxMinutes = max(sessions.map(\.durationMinutes).max() ?? 1, 1)

                if let start = projectStart, let end = projectEnd, end > start {
                    let totalSpan = end.timeIntervalSince(start)

                    ForEach(sessions, id: \.id) { s in
                        let sStart = s.startDate.timeIntervalSince(start)
                        let sEnd = s.endDate.timeIntervalSince(start)
                        let xFrac = totalSpan > 0 ? sStart / totalSpan : 0
                        let wFrac = totalSpan > 0 ? (sEnd - sStart) / totalSpan : 0

                        let x = geo.size.width * CGFloat(xFrac)
                        let w = max(2.0, geo.size.width * CGFloat(wFrac))
                        let h = barHeight(minutes: s.durationMinutes, maxMinutes: maxMinutes)

                        let barOpacity: Double = {
                            if let highlightedPhaseID {
                                return phaseID(for: s) == highlightedPhaseID ? 1.0 : 0.18
                            }
                            return 1.0
                        }()

                        RoundedRectangle(cornerRadius: Theme.Design.blockCornerRadius)
                            .fill(barFill(for: s, isHighlighted: false))
                            .opacity(barOpacity)
                            .frame(width: w, height: h)
                            .position(x: x + w / 2, y: geo.size.height - h / 2 - 4)
                    }
                } else {
                    // Fallback: single-session or zero-span — render evenly spaced.
                    let count = max(sessions.count, 1)
                    let gap: CGFloat = 1
                    let raw = (geo.size.width / CGFloat(count)) - gap
                    let barW = max(1.5, raw)

                    HStack(alignment: .bottom, spacing: gap) {
                        ForEach(sessions, id: \.id) { s in
                            RoundedRectangle(cornerRadius: Theme.Design.blockCornerRadius)
                                .fill(barFill(for: s, isHighlighted: false))
                                .frame(width: barW, height: barHeight(minutes: s.durationMinutes, maxMinutes: maxMinutes))
                        }
                    }
                }
            }
        }
        .frame(height: 72)
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.leading, PhaseLaneRow.labelWidth + Theme.Spacing.xs)
        .padding(.trailing, Theme.Spacing.sm)
        .background(Theme.Colors.surface.opacity(0.5))
        .cornerRadius(Theme.Row.cornerRadius)
    }

    // MARK: Axis Labels

    private var axisLabels: some View {
        HStack {
            Text(labelStart)
            Spacer()
            Text(labelMid)
            Spacer()
            Text(labelEnd)
        }
        .font(Theme.Fonts.caption)
        .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))
        .padding(.leading, PhaseLaneRow.labelWidth + Theme.Spacing.xs)
        .padding(.trailing, Theme.Spacing.sm)
    }

    private var labelStart: String {
        if let d = projectStart { return df.string(from: d) }
        return ""
    }

    private var labelEnd: String {
        if let d = projectEnd { return df.string(from: d) }
        return ""
    }

    private var labelMid: String {
        guard let start = projectStart, let end = projectEnd, end > start else { return "" }
        let mid = start.addingTimeInterval((end.timeIntervalSince(start) / 2))
        return df.string(from: mid)
    }

    // MARK: Helpers

    private func barHeight(minutes: Int, maxMinutes: Int) -> CGFloat {
        let t = CGFloat(Swift.max(minutes, 0)) / CGFloat(Swift.max(maxMinutes, 1))
        return 6 + (t * (48 - 6))
    }

    private func barFill(for session: SessionRecord, isHighlighted: Bool) -> Color {
        if session.isMilestone {
            return isHighlighted ? Theme.Colors.milestoneHighlight : Theme.Colors.milestone
        }
        let base = Color(hex: projectColorHex)
        guard let lane = lanes.first(where: { $0.sessions.contains(where: { $0.id == session.id }) }) else {
            return base.opacity(0.40).lightenedByLuminance()
        }
        if lane.phaseIndex == nil {
            return base.opacity(0.40).lightenedByLuminance()
        }
        let phaseColors = ColorFamily.projectHueRotated(baseHex: projectColorHex, stepDegrees: 18)
        let phaseColor = phaseColors[safe: lane.phaseIndex ?? 0] ?? base
        return phaseColor.lightenedByLuminance()
    }

    private func phaseID(for session: SessionRecord) -> String? {
        // Returns the lane id ("__unphased__" or a real phaseID) for cross-highlight
        lanes.first(where: { $0.sessions.contains(where: { $0.id == session.id }) })?.id
    }
}

// MARK: - Phase Lane Row

/// One row in the Braid's lanes section: a phase title on the left, and a
/// date-positioned track of marks on the right.
private struct PhaseLaneRow: View {
    static let labelWidth: CGFloat = 80
    let lane: ProjectStoryViewModel.PhaseLane
    let projectColorHex: String
    let projectStart: Date?
    let projectEnd: Date?
    let isHighlighted: Bool
    let anyPhaseHighlighted: Bool
    let onHover: (String?) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(lane.title)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: PhaseLaneRow.labelWidth, alignment: .leading)

            GeometryReader { geo in
                ZStack {
                    // Track line
                    Capsule()
                        .fill(Theme.Colors.divider.opacity(0.3))
                        .frame(height: 3)

                    // Marks positioned by date
                    if let start = projectStart, let end = projectEnd, end > start {
                        let totalSpan = end.timeIntervalSince(start)
                        ForEach(lane.sessions) { s in
                            let xFrac = totalSpan > 0 ? s.startDate.timeIntervalSince(start) / totalSpan : 0
                            let x = geo.size.width * CGFloat(xFrac)

                            if s.isMilestone {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.milestone)
                                    .position(x: x, y: geo.size.height / 2)
                            } else {
                                Capsule()
                                    .fill(markColor)
                                    .frame(width: 3, height: 14)
                                    .position(x: x, y: geo.size.height / 2)
                            }
                        }
                    }
                }
            }
            .frame(height: Theme.Spacing.xl)
        }
        .opacity(isHighlighted ? 1.0 : (anyPhaseHighlighted ? 0.35 : 1.0))
        .onHover { hovering in
            onHover(hovering ? lane.id : nil)
        }
    }

    private var markColor: Color {
        if lane.phaseIndex == nil {
            return Color(hex: projectColorHex).opacity(0.40).lightenedByLuminance()
        }
        let phaseColors = ColorFamily.projectHueRotated(baseHex: projectColorHex, stepDegrees: 18)
        return phaseColors[safe: lane.phaseIndex ?? 0] ?? Color(hex: projectColorHex)
    }
}

// MARK: - Phase Detail Panel

/// A pinned strip (not a floating tooltip — safer inside a ScrollView) showing
/// the highlighted phase's details: date range, total time, mood, milestones,
/// and recent action lines.
private struct PhaseDetailPanel: View {
    let lane: ProjectStoryViewModel.PhaseLane
    let projectColorHex: String

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(phaseColor)
                    .frame(width: 8, height: 8)

                Text(lane.title)
                    .font(Theme.Fonts.subheader)
                    .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                if lane.isArchivedPhase {
                    Text("Archived")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.xs)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(Theme.Colors.surface)
                        .cornerRadius(999)
                }
            }

            Text("\(dateRangeText) · \(weeksText) · \(durationText) across \(lane.sessionCount) sessions")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary)

            HStack(spacing: Theme.Spacing.sm) {
                Text("Avg mood \(moodText)")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)

                if lane.milestoneCount > 0 {
                    Text("★ \(lane.milestoneCount) milestones")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.milestone)
                }

                if let activityName = prevalentActivityName {
                    Text("• Mostly \(activityName)")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }

            if !lane.recentActionLines.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Recent action lines:")
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.textSecondary)

                    ForEach(lane.recentActionLines, id: \.self) { line in
                        Text("\"\(line)\"")
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !lane.milestoneActions.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Milestones:")
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.textSecondary)

                    ForEach(lane.milestoneActions, id: \.self) { action in
                        Text("★ \(action)")
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.milestone)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.surface.opacity(0.7))
        .cornerRadius(Theme.Row.cornerRadius)
    }

    private var dateRangeText: String {
        "\(df.string(from: lane.startDate)) → \(df.string(from: lane.endDate))"
    }

    private var weeksText: String {
        let weeks = max(Calendar.current.dateComponents([.weekOfYear], from: lane.startDate, to: lane.endDate).weekOfYear ?? 0, 1)
        return "\(weeks) weeks"
    }

    private var durationText: String {
        let h = lane.totalDurationMinutes / 60
        let m = lane.totalDurationMinutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private var moodText: String {
        guard let mood = lane.averageMood else { return "—" }
        return String(format: "%.1f", mood)
    }

    private var prevalentActivityName: String? {
        guard let id = lane.prevalentActivityTypeID else { return nil }
        return ActivityTypeManager.shared.getActivityType(id: id)?.name
    }

    private var phaseColor: Color {
        if lane.phaseIndex == nil {
            return Color(hex: projectColorHex).opacity(0.40).lightenedByLuminance()
        }
        let phaseColors = ColorFamily.projectHueRotated(baseHex: projectColorHex, stepDegrees: 18)
        return phaseColors[safe: lane.phaseIndex ?? 0] ?? Color(hex: projectColorHex)
    }
}

private enum ColorFamily {
    static func projectHueRotated(baseHex: String, stepDegrees: CGFloat) -> [Color] {
        guard let base = NSColor(hex: baseHex)?.usingColorSpace(.deviceRGB) else {
            return Array(repeating: Color(hex: baseHex), count: 16)
        }

        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        base.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        // Keep saturation/brightness close to source (±8%), rotate hue only.
        let sat = clampAroundSource(s, percent: 0.08)
        let bri = clampAroundSource(b, percent: 0.08)

        return (0..<16).map { i in
            let deg = 18 * CGFloat(i)
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

// MARK: - Preview

#Preview("ProjectStory – Dashboard Size") {
    let calendar = Calendar.current
    let now = Date()

    // Mock project with phases
    let phaseA = Phase(id: "phase-a", name: "Discovery", order: 0, archived: false)
    let phaseB = Phase(id: "phase-b", name: "Development", order: 1, archived: false)
    let phaseC = Phase(id: "phase-c", name: "Launch", order: 2, archived: false)
    let project = Project(
        id: "preview-project",
        name: "Juju App",
        color: "#E15759",
        about: "A macOS time-tracking app with narrative project stories.",
        order: 0,
        emoji: "🦊",
        phases: [phaseA, phaseB, phaseC]
    )

    // Generate mock sessions across phases over ~120 days
    var mockSessions: [SessionRecord] = []
    for dayOffset in stride(from: 120, through: 0, by: -1) {
        guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

        // Pick phase based on day range
        let phaseID: String?
        let action: String?
        let isMilestone: Bool
        if dayOffset > 80 {
            phaseID = "phase-a"
            action = nil
            isMilestone = (dayOffset == 81)
        } else if dayOffset > 30 {
            phaseID = "phase-b"
            action = nil
            isMilestone = (dayOffset == 31)
        } else {
            phaseID = "phase-c"
            action = nil
            isMilestone = (dayOffset == 0)
        }

        // Random session count per day (0–2)
        let sessionCount = Int.random(in: 0...2)
        for s in 0..<sessionCount {
            let hour = Int.random(in: 9...17)
            let duration = Int.random(in: 15...180) // minutes
            guard let start = calendar.date(bySetting: .hour, value: hour, of: day),
                  let end = calendar.date(byAdding: .minute, value: duration, to: start) else { continue }

            mockSessions.append(SessionRecord(
                id: "session-\(dayOffset)-\(s)",
                startDate: start,
                endDate: end,
                projectID: "preview-project",
                activityTypeID: nil,
                projectPhaseID: phaseID,
                action: isMilestone ? "Completed major milestone" : nil,
                isMilestone: isMilestone,
                mood: Int.random(in: 4...9)
            ))
        }
    }

    let viewModel = ProjectStoryViewModel(
        projectID: "preview-project",
        projectsProvider: { [project] },
        sessionsProvider: { mockSessions }
    )
    viewModel.reload()

    return ProjectStoryPreviewCanvas(viewModel: viewModel)
        .frame(width: 1200, height: 900)
        .background(Theme.Colors.background)
}

/// Wrapper that uses a pre-built view model (for preview purposes).
private struct ProjectStoryPreviewCanvas: View {
    @StateObject private var viewModel: ProjectStoryViewModel
    @State private var highlightedPhaseID: String? = nil

    init(viewModel: ProjectStoryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLarge) {
                    if let header = viewModel.header {
                        ProjectStoryHeaderView(header: header)
                            .padding(.top, Theme.spacingLarge)
                    }

                    if viewModel.isEmpty {
            Text("No Sessions Yet")
                .font(Theme.Fonts.title)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 80)
                    } else {
                        if let summary = viewModel.summary, let header = viewModel.header {
                            ProjectStorySummaryRowView(summary: summary, projectColorHex: header.colorHex)
                        }

                        if let header = viewModel.header, !viewModel.projectSessions.isEmpty {
                            ProjectStoryBraidView(
                                sessions: viewModel.projectSessions,
                                lanes: viewModel.phaseLanes,
                                projectColorHex: header.colorHex,
                                projectStart: header.startDate,
                                projectEnd: header.endDate,
                                highlightedPhaseID: $highlightedPhaseID
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
    }
}