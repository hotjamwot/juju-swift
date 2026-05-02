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
        let phaseIndex: Int? // Index into the project's phases array for color lookup; nil for unphased
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

    private var cancellables: Set<AnyCancellable> = []

    init(
        projectID: String,
        projectsProvider: @escaping () -> [Project],
        sessionsProvider: @escaping () -> [SessionRecord],
        calendar: Calendar = .current
    ) {
        self.projectID = projectID
        self.projectsProvider = projectsProvider
        self.sessionsProvider = sessionsProvider
        self.calendar = calendar

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
            calendar: calendar
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
        calendar: Calendar
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

        // Convert chapters to TimelineItems (no gaps)
        return chapters.map { .chapter($0) }
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
        var phaseIndexByID: [String: Int] = [:]
        for (index, phase) in project.phases.enumerated() {
            phaseIndexByID[phase.id] = index
        }
        
        let totalDuration = sessions.reduce(0) { $0 + max($1.durationMinutes, 0) }
        guard totalDuration > 0 else { return [] }
        
        var segments: [PhaseSegment] = []
        var currentPhaseID: String? = sessions.first?.projectPhaseID
        var currentPhaseTitle: String {
            guard let phaseID = currentPhaseID,
                  let phase = phasesByID[phaseID] else { return "Unphased" }
            return phase.name
        }
        var currentIsArchivedPhase: Bool {
            guard let phaseID = currentPhaseID,
                  let phase = phasesByID[phaseID] else { return false }
            return phase.archived
        }
        var currentPhaseIndex: Int? {
            guard let phaseID = currentPhaseID else { return nil }
            return phaseIndexByID[phaseID]
        }
        var currentDuration: Int = 0
        
        for session in sessions {
            if session.projectPhaseID != currentPhaseID {
                // Phase changed, finalize current segment
                if currentDuration > 0 {
                    segments.append(PhaseSegment(
                        id: "\(currentPhaseID ?? "unphased")-\(segments.count)",
                        title: currentPhaseTitle,
                        isArchivedPhase: currentIsArchivedPhase,
                        durationMinutes: currentDuration,
                        fractionOfTotal: Double(currentDuration) / Double(totalDuration),
                        phaseIndex: currentPhaseIndex
                    ))
                }
                // Start new segment
                currentPhaseID = session.projectPhaseID
                currentDuration = max(session.durationMinutes, 0)
            } else {
                // Same phase, accumulate duration
                currentDuration += max(session.durationMinutes, 0)
            }
        }
        
        // Don't forget the last segment
        if currentDuration > 0 {
            segments.append(PhaseSegment(
                id: "\(currentPhaseID ?? "unphased")-\(segments.count)",
                title: currentPhaseTitle,
                isArchivedPhase: currentIsArchivedPhase,
                durationMinutes: currentDuration,
                fractionOfTotal: Double(currentDuration) / Double(totalDuration),
                phaseIndex: currentPhaseIndex
            ))
        }
        
        return segments
    }
}

