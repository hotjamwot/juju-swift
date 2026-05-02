/// ProjectStoryDerivationTests.swift
/// Purpose: Verify ProjectStoryViewModel derives chapters, milestones, and gaps correctly.
/// AI Notes: In-memory fixtures only; no disk I/O.

import XCTest
@testable import Juju

final class ProjectStoryDerivationTests: XCTestCase {
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.firstWeekday = 2 // Monday (ISO-ish) for deterministic week bucketing
        return cal
    }()

    private func d(_ y: Int, _ m: Int, _ day: Int, _ hour: Int = 12) -> Date {
        var comps = DateComponents()
        comps.calendar = calendar
        comps.year = y
        comps.month = m
        comps.day = day
        comps.hour = hour
        return comps.date!
    }

    private func session(
        id: String,
        start: Date,
        end: Date,
        projectID: String = "p1",
        phaseID: String? = "ph1",
        action: String? = nil,
        isMilestone: Bool = false
    ) -> SessionRecord {
        SessionRecord(
            id: id,
            startDate: start,
            endDate: end,
            projectID: projectID,
            activityTypeID: nil,
            projectPhaseID: phaseID,
            action: action,
            isMilestone: isMilestone,
            notes: "",
            mood: nil
        )
    }

    func testDeriveTimelineItems_groupsByPhaseAndOrdersByTime() {
        let ph1 = Phase(id: "ph1", name: "Build", order: 0, archived: false)
        let ph2 = Phase(id: "ph2", name: "Polish", order: 1, archived: false)
        let project = Project(id: "p1", name: "X", color: "#000000", about: nil, order: 0, emoji: "📁", phases: [ph1, ph2])

        let s1 = session(id: "a", start: d(2026, 1, 1), end: d(2026, 1, 1, 13), phaseID: "ph1")
        let s2 = session(id: "b", start: d(2026, 2, 1), end: d(2026, 2, 1, 13), phaseID: "ph2")
        let s3 = session(id: "c", start: d(2026, 1, 10), end: d(2026, 1, 10, 13), phaseID: "ph1")

        let items = ProjectStoryViewModel.deriveTimelineItems(
            sessions: [s2, s3, s1],
            project: project,
            calendar: calendar,
            gapThresholdDays: 7
        )

        let chapters = items.compactMap { item -> ProjectStoryViewModel.Chapter? in
            if case .chapter(let c) = item { return c }
            return nil
        }

        XCTAssertEqual(chapters.count, 2)
        XCTAssertEqual(chapters[0].phaseID, "ph1")
        XCTAssertEqual(chapters[0].title, "Build")
        XCTAssertEqual(chapters[1].phaseID, "ph2")
        XCTAssertEqual(chapters[1].title, "Polish")
        XCTAssertEqual(chapters[0].startDate, s1.startDate)
        XCTAssertEqual(chapters[0].endDate, s3.endDate)
    }

    func testDeriveTimelineItems_archivedPhaseStillResolves() {
        let archived = Phase(id: "ph-arch", name: "Old track", order: 0, archived: true)
        let project = Project(id: "p1", name: "X", color: "#000000", about: nil, order: 0, emoji: "📁", phases: [archived])

        let s = session(id: "s", start: d(2026, 1, 1), end: d(2026, 1, 1, 13), phaseID: "ph-arch")
        let items = ProjectStoryViewModel.deriveTimelineItems(sessions: [s], project: project, calendar: calendar, gapThresholdDays: 7)

        guard case .chapter(let c)? = items.first else {
            return XCTFail("Expected first item to be a chapter")
        }
        XCTAssertEqual(c.title, "Old track")
        XCTAssertTrue(c.isArchivedPhase)
    }

    func testDeriveTimelineItems_unknownPhaseBecomesUnphased() {
        let project = Project(id: "p1", name: "X", color: "#000000", about: nil, order: 0, emoji: "📁", phases: [])
        let s = session(id: "s", start: d(2026, 1, 1), end: d(2026, 1, 1, 13), phaseID: "missing")

        let items = ProjectStoryViewModel.deriveTimelineItems(sessions: [s], project: project, calendar: calendar, gapThresholdDays: 7)
        guard case .chapter(let c)? = items.first else {
            return XCTFail("Expected chapter")
        }
        XCTAssertNil(c.phaseID)
        XCTAssertEqual(c.title, "Unphased")
    }

    func testDeriveTimelineItems_milestonesRequireActionAndFlag() {
        let ph = Phase(id: "ph1", name: "Build", order: 0, archived: false)
        let project = Project(id: "p1", name: "X", color: "#000000", about: nil, order: 0, emoji: "📁", phases: [ph])

        let a = session(id: "a", start: d(2026, 1, 1), end: d(2026, 1, 1, 13), phaseID: "ph1", action: "Shipped", isMilestone: true)
        let b = session(id: "b", start: d(2026, 1, 2), end: d(2026, 1, 2, 13), phaseID: "ph1", action: "", isMilestone: true)
        let c = session(id: "c", start: d(2026, 1, 3), end: d(2026, 1, 3, 13), phaseID: "ph1", action: "Did thing", isMilestone: false)

        let items = ProjectStoryViewModel.deriveTimelineItems(sessions: [a, b, c], project: project, calendar: calendar, gapThresholdDays: 7)
        guard case .chapter(let chapter)? = items.first else {
            return XCTFail("Expected chapter")
        }

        XCTAssertEqual(chapter.milestones.map(\.id), ["a"])
        XCTAssertEqual(chapter.milestones.first?.action, "Shipped")
        XCTAssertEqual(chapter.milestones.first?.phaseTitle, "Build")
    }

    func testDeriveTimelineItems_insertsGapBetweenChapters() {
        let ph1 = Phase(id: "ph1", name: "A", order: 0, archived: false)
        let ph2 = Phase(id: "ph2", name: "B", order: 1, archived: false)
        let project = Project(id: "p1", name: "X", color: "#000000", about: nil, order: 0, emoji: "📁", phases: [ph1, ph2])

        let s1 = session(id: "a", start: d(2026, 1, 1), end: d(2026, 1, 1, 13), phaseID: "ph1")
        let s2 = session(id: "b", start: d(2026, 1, 25), end: d(2026, 1, 25, 13), phaseID: "ph2")

        let items = ProjectStoryViewModel.deriveTimelineItems(sessions: [s1, s2], project: project, calendar: calendar, gapThresholdDays: 7)
        XCTAssertEqual(items.count, 3)

        XCTAssertTrue({
            if case .gap = items[1] { return true }
            return false
        }())
    }

    func testDeriveWeeklyDensity_tracksTotalDurationAndMood() {
        let ph1 = Phase(id: "ph1", name: "A", order: 0, archived: false)
        let project = Project(id: "p1", name: "X", color: "#000000", about: nil, order: 0, emoji: "📁", phases: [ph1])

        // Pick two dates that are guaranteed to fall in the same week under the calendar above.
        let s1 = session(id: "a", start: d(2026, 1, 6, 10), end: d(2026, 1, 6, 12), phaseID: "ph1", action: nil, isMilestone: false)
        let s2 = SessionRecord(
            id: "b",
            startDate: d(2026, 1, 7, 10),
            endDate: d(2026, 1, 7, 11),
            projectID: "p1",
            activityTypeID: nil,
            projectPhaseID: "ph1",
            action: nil,
            isMilestone: false,
            notes: "",
            mood: 10
        )

        let items = ProjectStoryViewModel.deriveTimelineItems(sessions: [s1, s2], project: project, calendar: calendar, gapThresholdDays: 7)
        guard case .chapter(let c)? = items.first else {
            return XCTFail("Expected chapter")
        }

        XCTAssertEqual(c.density.count, 1)
        XCTAssertEqual(c.density[0].sessionCount, 2)
        XCTAssertEqual(c.density[0].totalDurationMinutes, 180)
        XCTAssertNotNil(c.density[0].averageMood)
    }
}

