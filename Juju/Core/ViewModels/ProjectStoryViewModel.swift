/// ProjectStoryViewModel.swift
/// Purpose: Derive a read-only narrative timeline for a single project.
/// AI Notes: Pure read layer; derives chapters, density, milestones, and gaps from in-memory sessions + projects.

import Foundation
import Combine

@MainActor
final class ProjectStoryViewModel: ObservableObject {
    // MARK: - Output

    struct Header: Equatable {
        let projectName: String
        let emoji: String
        let colorHex: String
        let about: String?
        let startDate: Date?
        let endDate: Date?
    }

    struct DensityBucket: Identifiable, Equatable {
        let id: Date
        let weekStart: Date
        let totalDurationMinutes: Int
        let averageMood: Double?
        let sessionCount: Int
    }

    struct Milestone: Identifiable, Equatable {
        let id: String
        let date: Date
        let action: String
        let phaseID: String?
        let phaseTitle: String
        let isArchivedPhase: Bool
    }

    struct SummaryStats: Equatable {
        let totalDurationMinutes: Int
        let totalSessions: Int
        let averageMood: Double?
        let phaseCount: Int
    }

    struct PhaseSegment: Identifiable, Equatable {
        let id: String
        let title: String
        let isArchivedPhase: Bool
        let durationMinutes: Int
        let fractionOfTotal: Double
    }

    struct Chapter: Identifiable, Equatable {
        let id: String
        let phaseID: String?
        let title: String
        let isArchivedPhase: Bool
        let startDate: Date
        let endDate: Date
        let density: [DensityBucket]
        let milestones: [Milestone]
    }

    struct Gap: Identifiable, Equatable {
        let id: String
        let startDate: Date
        let endDate: Date
        let days: Int
    }

    enum TimelineItem: Identifiable, Equatable {
        case chapter(Chapter)
        case gap(Gap)

        var id: String {
            switch self {
            case .chapter(let c): return "chapter-\(c.id)"
            case .gap(let g): return "gap-\(g.id)"
            }
        }
    }

    @Published private(set) var header: Header?
    @Published private(set) var summary: SummaryStats?
    @Published private(set) var phaseTimeline: [PhaseSegment] = []
    @Published private(set) var projectDensity: [DensityBucket] = []
    @Published private(set) var projectSessions: [SessionRecord] = []
    @Published private(set) var allMilestones: [Milestone] = []
    @Published private(set) var phaseBoundaries: [Date] = []
    @Published private(set) var items: [TimelineItem] = []
    @Published private(set) var isEmpty = true

    // MARK: - Inputs

    private let projectID: String
    private let projectsProvider: () -> [Project]
    private let sessionsProvider: () -> [SessionRecord]
    private let calendar: Calendar
    private let gapThresholdDays: Int

    private var cancellables: Set<AnyCancellable> = []

    init(
        projectID: String,
        projectsProvider: @escaping () -> [Project],
        sessionsProvider: @escaping () -> [SessionRecord],
        calendar: Calendar = .current,
        gapThresholdDays: Int = 28
    ) {
        self.projectID = projectID
        self.projectsProvider = projectsProvider
        self.sessionsProvider = sessionsProvider
        self.calendar = calendar
        self.gapThresholdDays = gapThresholdDays

        NotificationCenter.default.publisher(for: .sessionDidEnd)
            .merge(with: NotificationCenter.default.publisher(for: .projectsDidChange))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)
    }

    func reload() {
        let projects = projectsProvider()
        guard let project = projects.first(where: { $0.id == projectID }) else {
            header = nil
            summary = nil
            phaseTimeline = []
            items = []
            isEmpty = true
            return
        }

        let sessions = sessionsProvider()
            .filter { $0.projectID == projectID }
            .sorted { $0.startDate < $1.startDate }

        let start = sessions.first?.startDate
        let end = sessions.last?.endDate
        header = Header(
            projectName: project.name,
            emoji: project.emoji,
            colorHex: project.color,
            about: project.about,
            startDate: start,
            endDate: end
        )

        isEmpty = sessions.isEmpty
        summary = Self.deriveSummaryStats(from: sessions, project: project)
        phaseTimeline = Self.derivePhaseTimeline(from: sessions, project: project)
        projectDensity = Self.deriveWeeklyDensity(from: sessions, calendar: calendar)
        projectSessions = sessions
        items = Self.deriveTimelineItems(
            sessions: sessions,
            project: project,
            calendar: calendar,
            gapThresholdDays: gapThresholdDays
        )

        let chapters = items.compactMap { item -> Chapter? in
            if case .chapter(let c) = item { return c }
            return nil
        }
        allMilestones = chapters.flatMap(\.milestones).sorted { $0.date < $1.date }
        phaseBoundaries = chapters.dropFirst().map(\.startDate)
    }

    // MARK: - Derivation

    nonisolated static func deriveTimelineItems(
        sessions: [SessionRecord],
        project: Project,
        calendar: Calendar,
        gapThresholdDays: Int
    ) -> [TimelineItem] {
        guard !sessions.isEmpty else { return [] }

        let phasesByID = Dictionary(uniqueKeysWithValues: project.phases.map { ($0.id, $0) })

        func resolvePhaseInfo(_ phaseID: String?) -> (title: String, archived: Bool) {
            guard let phaseID, let phase = phasesByID[phaseID] else { return ("Unphased", false) }
            return (phase.name, phase.archived)
        }

        // Group sessions by phaseID (nil and unknown both become "Unphased")
        var groups: [String: [SessionRecord]] = [:]
        func groupKey(for phaseID: String?) -> String {
            guard let phaseID, phasesByID[phaseID] != nil else { return "__unphased__" }
            return phaseID
        }

        for s in sessions {
            groups[groupKey(for: s.projectPhaseID), default: []].append(s)
        }

        // Create chapters sorted by their first session date
        let chapters: [Chapter] = groups
            .map { (key, groupSessions) in
                let sorted = groupSessions.sorted { $0.startDate < $1.startDate }
                let phaseID: String? = (key == "__unphased__") ? nil : key
                let info = resolvePhaseInfo(phaseID)

                let start = sorted.first!.startDate
                let end = (sorted.max(by: { $0.endDate < $1.endDate }))!.endDate

                let density = deriveWeeklyDensity(from: sorted, calendar: calendar)
                let milestones = deriveMilestones(from: sorted, phaseID: phaseID, phaseTitle: info.title, isArchivedPhase: info.archived)

                return Chapter(
                    id: phaseID ?? "unphased",
                    phaseID: phaseID,
                    title: info.title,
                    isArchivedPhase: info.archived,
                    startDate: start,
                    endDate: end,
                    density: density,
                    milestones: milestones
                )
            }
            .sorted { $0.startDate < $1.startDate }

        // Infer gaps between chapters (based on their date spans)
        var items: [TimelineItem] = []
        items.reserveCapacity(chapters.count * 2)

        for idx in chapters.indices {
            let chapter = chapters[idx]
            items.append(.chapter(chapter))

            guard idx < chapters.count - 1 else { continue }
            let next = chapters[idx + 1]

            let gapStart = chapter.endDate
            let gapEnd = next.startDate
            let dayDelta = calendar.dateComponents([.day], from: gapStart, to: gapEnd).day ?? 0
            if dayDelta > gapThresholdDays {
                let gap = Gap(
                    id: "\(chapter.id)-to-\(next.id)-\(gapStart.timeIntervalSince1970)",
                    startDate: gapStart,
                    endDate: gapEnd,
                    days: dayDelta
                )
                items.append(.gap(gap))
            }
        }

        return items
    }

    private nonisolated static func deriveWeeklyDensity(from sessions: [SessionRecord], calendar: Calendar) -> [DensityBucket] {
        struct Accumulator {
            var durationMinutes: Int = 0
            var moodSum: Int = 0
            var moodCount: Int = 0
            var sessionCount: Int = 0
        }

        var acc: [Date: Accumulator] = [:]
        acc.reserveCapacity(min(sessions.count, 64))

        for s in sessions {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: s.startDate)?.start else { continue }
            var a = acc[weekStart] ?? Accumulator()
            a.sessionCount += 1
            a.durationMinutes += max(s.durationMinutes, 0)
            if let mood = s.mood {
                a.moodSum += mood
                a.moodCount += 1
            }
            acc[weekStart] = a
        }

        return acc
            .map { (weekStart, a) in
                let avgMood: Double? = a.moodCount > 0 ? Double(a.moodSum) / Double(a.moodCount) : nil
                return DensityBucket(
                    id: weekStart,
                    weekStart: weekStart,
                    totalDurationMinutes: a.durationMinutes,
                    averageMood: avgMood,
                    sessionCount: a.sessionCount
                )
            }
            .sorted { $0.weekStart < $1.weekStart }
    }

    private nonisolated static func deriveMilestones(
        from sessions: [SessionRecord],
        phaseID: String?,
        phaseTitle: String,
        isArchivedPhase: Bool
    ) -> [Milestone] {
        sessions
            .filter { $0.isMilestone }
            .compactMap { s in
                let action = (s.action ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !action.isEmpty else { return nil }
                return Milestone(
                    id: s.id,
                    date: s.startDate,
                    action: action,
                    phaseID: phaseID,
                    phaseTitle: phaseTitle,
                    isArchivedPhase: isArchivedPhase
                )
            }
            .sorted { $0.date < $1.date }
    }

    nonisolated static func deriveSummaryStats(from sessions: [SessionRecord], project: Project) -> SummaryStats {
        let totalMinutes = sessions.reduce(0) { $0 + max($1.durationMinutes, 0) }
        let totalSessions = sessions.count

        let moods = sessions.compactMap(\.mood)
        let avgMood: Double? = moods.isEmpty ? nil : Double(moods.reduce(0, +)) / Double(moods.count)

        let phasesByID = Dictionary(uniqueKeysWithValues: project.phases.map { ($0.id, $0) })
        let distinctPhaseIDs = Set(sessions.compactMap { s -> String? in
            guard let id = s.projectPhaseID, phasesByID[id] != nil else { return nil }
            return id
        })

        return SummaryStats(
            totalDurationMinutes: totalMinutes,
            totalSessions: totalSessions,
            averageMood: avgMood,
            phaseCount: distinctPhaseIDs.count
        )
    }

    nonisolated static func derivePhaseTimeline(from sessions: [SessionRecord], project: Project) -> [PhaseSegment] {
        guard !sessions.isEmpty else { return [] }

        let phasesByID = Dictionary(uniqueKeysWithValues: project.phases.map { ($0.id, $0) })
        var minutesByKey: [String: Int] = [:]

        func key(for phaseID: String?) -> String {
            guard let phaseID, phasesByID[phaseID] != nil else { return "__unphased__" }
            return phaseID
        }

        for s in sessions {
            minutesByKey[key(for: s.projectPhaseID), default: 0] += max(s.durationMinutes, 0)
        }

        let total = max(minutesByKey.values.reduce(0, +), 1)

        // Sort by project phase order, then Unphased last if present.
        let orderedPhaseIDs = project.phases.sorted { $0.order < $1.order }.map(\.id)
        var orderedKeys: [String] = orderedPhaseIDs.filter { minutesByKey[$0] != nil }
        if minutesByKey["__unphased__"] != nil {
            orderedKeys.append("__unphased__")
        }

        return orderedKeys.compactMap { k in
            guard let minutes = minutesByKey[k], minutes > 0 else { return nil }
            if k == "__unphased__" {
                return PhaseSegment(
                    id: "unphased",
                    title: "Unphased",
                    isArchivedPhase: false,
                    durationMinutes: minutes,
                    fractionOfTotal: Double(minutes) / Double(total)
                )
            }

            guard let phase = phasesByID[k] else { return nil }
            return PhaseSegment(
                id: phase.id,
                title: phase.name,
                isArchivedPhase: phase.archived,
                durationMinutes: minutes,
                fractionOfTotal: Double(minutes) / Double(total)
            )
        }
    }
}

