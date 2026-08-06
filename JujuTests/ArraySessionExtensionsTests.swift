/// ArraySessionExtensionsTests.swift
/// Purpose: Tests for Array<SessionRecord> filtering, sorting, grouping, dedup, and aggregation (deterministic; no Date()-relative logic).

import XCTest
@testable import Juju

final class ArraySessionExtensionsTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = day; c.hour = hour; c.minute = minute
        return cal.date(from: c)!
    }

    private func session(
        id: String = "s",
        start: Date,
        end: Date,
        projectID: String = "p1",
        activityTypeID: String? = "a1",
        projectPhaseID: String? = "ph1"
    ) -> SessionRecord {
        SessionRecord(id: id, startDate: start, endDate: end, projectID: projectID, activityTypeID: activityTypeID, projectPhaseID: projectPhaseID)
    }

    // MARK: - filteredByProject

    func testFilteredByProject_returnsOnlyMatching() {
        let a = session(id: "a", start: date(10, 9), end: date(10, 10), projectID: "p1")
        let b = session(id: "b", start: date(10, 9), end: date(10, 10), projectID: "p2")
        let out = [a, b].filteredByProject("p1")
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].id, "a")
    }

    // MARK: - filteredByActivityType

    func testFilteredByActivityType_uncategorizedMatchesNilAndEmpty() {
        let nilType = session(id: "n", start: date(10, 9), end: date(10, 10), activityTypeID: nil)
        let emptyType = session(id: "e", start: date(10, 9), end: date(10, 10), activityTypeID: "")
        let typed = session(id: "t", start: date(10, 9), end: date(10, 10), activityTypeID: "a1")
        let out = [nilType, emptyType, typed].filteredByActivityType("Uncategorized")
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out.map(\.id).sorted(), ["e", "n"])
    }

    func testFilteredByActivityType_standardExactMatch() {
        let a = session(id: "a", start: date(10, 9), end: date(10, 10), activityTypeID: "a1")
        let b = session(id: "b", start: date(10, 9), end: date(10, 10), activityTypeID: "a2")
        let out = [a, b].filteredByActivityType("a2")
        XCTAssertEqual(out.map(\.id), ["b"])
    }

    // MARK: - filteredByPhase

    func testFilteredByPhase_uncategorizedMatchesNilAndEmpty() {
        let nilPhase = session(id: "n", start: date(10, 9), end: date(10, 10), projectPhaseID: nil)
        let emptyPhase = session(id: "e", start: date(10, 9), end: date(10, 10), projectPhaseID: "")
        let typed = session(id: "t", start: date(10, 9), end: date(10, 10), projectPhaseID: "ph1")
        let out = [nilPhase, emptyPhase, typed].filteredByPhase("Uncategorized")
        XCTAssertEqual(out.count, 2)
    }

    func testFilteredByPhase_standardExactMatch() {
        let a = session(id: "a", start: date(10, 9), end: date(10, 10), projectPhaseID: "ph1")
        let b = session(id: "b", start: date(10, 9), end: date(10, 10), projectPhaseID: "ph2")
        let out = [a, b].filteredByPhase("ph2")
        XCTAssertEqual(out.map(\.id), ["b"])
    }

    // MARK: - filteredByDateInterval

    func testFilteredByDateInterval_includesBoundaries() {
        let interval = DateInterval(start: date(10, 0), end: date(12, 0))
        let atStart = session(id: "s", start: date(10, 0), end: date(10, 30))
        let atEnd = session(id: "e", start: date(12, 0), end: date(12, 30))
        let out = [atStart, atEnd].filteredByDateInterval(interval)
        // DateInterval.contains() is inclusive on both ends, so sessions whose start
        // date equals the interval start OR the interval end are both included.
        XCTAssertEqual(out.map(\.id).sorted(), ["e", "s"])
    }

    // MARK: - sortedBy*

    func testSortedByStartDate_newestFirst() {
        let old = session(id: "old", start: date(10, 9), end: date(10, 10))
        let new = session(id: "new", start: date(10, 11), end: date(10, 12))
        let out = [old, new].sortedByStartDate()
        XCTAssertEqual(out.map(\.id), ["new", "old"])
    }

    func testSortedByDuration_longestFirst() {
        let short = session(id: "s", start: date(10, 9), end: date(10, 10))
        let long = session(id: "l", start: date(10, 9), end: date(10, 11))
        let out = [short, long].sortedByDuration()
        XCTAssertEqual(out.map(\.id), ["l", "s"])
    }

    func testSortedByProject_alphabeticalByProjectID() {
        let a = session(id: "a", start: date(10, 9), end: date(10, 10), projectID: "zeta")
        let b = session(id: "b", start: date(10, 9), end: date(10, 10), projectID: "alpha")
        let out = [a, b].sortedByProject()
        XCTAssertEqual(out.map(\.projectID), ["alpha", "zeta"])
    }

    // MARK: - totalDurationMinutes

    func testTotalDurationMinutes_sumsAcrossSessions() {
        let a = session(id: "a", start: date(10, 9), end: date(10, 10))
        let b = session(id: "b", start: date(10, 11), end: date(10, 13))
        XCTAssertEqual([a, b].totalDurationMinutes(), 180)
    }

    func testTotalDurationMinutesInInterval_filtersThenSums() {
        let inRange = session(id: "i", start: date(10, 9), end: date(10, 10))
        let outRange = session(id: "o", start: date(20, 9), end: date(20, 10))
        let interval = DateInterval(start: date(10, 0), end: date(11, 0))
        XCTAssertEqual([inRange, outRange].totalDurationMinutes(in: interval), 60)
    }

    // MARK: - unique IDs

    func testUniqueProjectIDs_andUniqueActivityTypeIDs() {
        let a = session(id: "a", start: date(10, 9), end: date(10, 10), projectID: "p1", activityTypeID: "a1")
        let b = session(id: "b", start: date(10, 9), end: date(10, 10), projectID: "p1", activityTypeID: "a2")
        let c = session(id: "c", start: date(10, 9), end: date(10, 10), projectID: "p2", activityTypeID: nil)
        XCTAssertEqual([a, b, c].uniqueProjectIDs(), ["p1", "p2"])
        XCTAssertEqual([a, b, c].uniqueActivityTypeIDs(), ["a1", "a2"])
    }

    // MARK: - findOverlappingSessions

    func testFindOverlappingSessions_excludesTargetAndAdjacent() {
        let target = session(id: "t", start: date(10, 10), end: date(10, 11))
        let same = session(id: "t", start: date(10, 10), end: date(10, 11))
        let partial = session(id: "p", start: date(10, 10, 30), end: date(10, 11, 30))
        let before = session(id: "b", start: date(10, 9), end: date(10, 10))
        let disjoint = session(id: "d", start: date(10, 12), end: date(10, 13))
        let out = [same, partial, before, disjoint].findOverlappingSessions(with: target)
        XCTAssertEqual(out.map(\.id), ["p"])
    }

    // MARK: - removeDuplicates

    func testRemovingDuplicates_keepsFirstOccurrence() {
        let first = session(id: "d", start: date(10, 9), end: date(10, 10))
        let dup = SessionRecord(id: "d", startDate: date(10, 12), endDate: date(10, 13), projectID: "p_other")
        let unique = session(id: "u", start: date(10, 9), end: date(10, 10))
        let out = [first, dup, unique].removingDuplicates()
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[0].id, "d")
        XCTAssertEqual(out[0].projectID, "p1")
        XCTAssertEqual(out[1].id, "u")
    }

    // MARK: - aggregateSessionDurationsByActivityType

    func testAggregateSessionDurationsByActivityType_nilBecomesUncategorized() {
        let a1 = session(id: "a1", start: date(10, 9), end: date(10, 11), activityTypeID: "a1")
        let a2 = session(id: "a2", start: date(10, 9), end: date(10, 10), activityTypeID: "a2")
        let nilAct = session(id: "n", start: date(10, 9), end: date(10, 10), activityTypeID: nil)
        let totals = [a1, a2, nilAct].aggregateSessionDurationsByActivityType([a1, a2, nilAct])
        XCTAssertEqual(totals["a1"]!, 2.0, accuracy: 0.0001)
        XCTAssertEqual(totals["a2"]!, 1.0, accuracy: 0.0001)
        XCTAssertEqual(totals[ActivityType.uncategorizedID]!, 1.0, accuracy: 0.0001)
    }

    // MARK: - filteredByDateFilter (deterministic no-op cases)

    func testFilteredByDateFilter_allTimeClearAndCustomAreNoOps() {
        let a = session(id: "a", start: date(10, 9), end: date(10, 10))
        let b = session(id: "b", start: date(10, 11), end: date(10, 12))
        let input = [a, b]
        XCTAssertEqual(input.filteredByDateFilter(.allTime), input)
        XCTAssertEqual(input.filteredByDateFilter(.clear), input)
        XCTAssertEqual(input.filteredByDateFilter(.custom), input)
    }

    // MARK: - groupedByDate

    func testGroupedByDate_groupsNewestFirstAndFormatsDuration() {
        let jan10a = session(id: "a", start: date(10, 10), end: date(10, 11))
        let jan10b = session(id: "b", start: date(10, 13), end: date(10, 14))
        let jan09 = session(id: "c", start: date(9, 9), end: date(9, 11))
        let grouped = [jan10a, jan09, jan10b].groupedByDate()
        XCTAssertEqual(grouped.count, 2)
        XCTAssertEqual(grouped[0].date, cal.startOfDay(for: date(10, 0)))
        XCTAssertEqual(grouped[0].sessions.map(\.id), ["b", "a"])
        XCTAssertEqual(grouped[0].totalDurationMinutes, 120)
        XCTAssertEqual(grouped[0].formattedDuration, "2h")

        XCTAssertEqual(grouped[1].date, cal.startOfDay(for: date(9, 0)))
        XCTAssertEqual(grouped[1].sessions.map(\.id), ["c"])
    }
}
