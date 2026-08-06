/// SessionRecordFilteringTests.swift
/// Purpose: Tests for SessionRecord date/project/activity/phase filters, duration, and overlap checks (deterministic; no Date()-relative logic).

import XCTest
@testable import Juju

final class SessionRecordFilteringTests: XCTestCase {
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

    private func session(id: String = "s", start: Date, end: Date) -> SessionRecord {
        SessionRecord(id: id, startDate: start, endDate: end, projectID: "p1")
    }

    // MARK: - isInInterval

    func testIsInInterval_trueWhenStartWithinRange_falseWhenOutside() {
        let interval = DateInterval(start: date(10, 0), end: date(12, 0))
        let inside = session(start: date(10, 9), end: date(10, 10))
        let outside = session(id: "o", start: date(13, 9), end: date(13, 10))
        XCTAssertTrue(inside.isInInterval(interval))
        XCTAssertFalse(outside.isInInterval(interval))
    }

    func testIsInInterval_includesIntervalStartBoundary() {
        let interval = DateInterval(start: date(10, 0), end: date(12, 0))
        let s = session(id: "b", start: date(10, 0), end: date(10, 30))
        XCTAssertTrue(s.isInInterval(interval))
    }

    // MARK: - isForProject / hasActivityType / hasPhase

    func testIsForProject_matchesExactly() {
        let s = session(start: date(10, 9), end: date(10, 10))
        XCTAssertTrue(s.isForProject("p1"))
        XCTAssertFalse(s.isForProject("p2"))
    }

    func testHasActivityType_matchesSetOrNil() {
        let withType = SessionRecord(id: "a", startDate: date(10, 9), endDate: date(10, 10), projectID: "p1", activityTypeID: "act1")
        let nilType = SessionRecord(id: "b", startDate: date(10, 9), endDate: date(10, 10), projectID: "p1")
        XCTAssertTrue(withType.hasActivityType("act1"))
        XCTAssertFalse(withType.hasActivityType("act2"))
        XCTAssertFalse(nilType.hasActivityType("act1"))
    }

    func testHasPhase_matchesSetOrNil() {
        let withPhase = SessionRecord(id: "a", startDate: date(10, 9), endDate: date(10, 10), projectID: "p1", projectPhaseID: "ph1")
        let nilPhase = SessionRecord(id: "b", startDate: date(10, 9), endDate: date(10, 10), projectID: "p1")
        XCTAssertTrue(withPhase.hasPhase("ph1"))
        XCTAssertFalse(withPhase.hasPhase("ph2"))
        XCTAssertFalse(nilPhase.hasPhase("ph1"))
    }

    // MARK: - hasValidDuration

    func testHasValidDuration_trueWhenEndAfterStart_falseWhenEqualOrReversed() {
        let valid = session(start: date(10, 9), end: date(10, 10))
        let equal = session(id: "eq", start: date(10, 9), end: date(10, 9))
        let reversed = session(id: "rev", start: date(10, 10), end: date(10, 9))
        XCTAssertTrue(valid.hasValidDuration)
        XCTAssertFalse(equal.hasValidDuration)
        XCTAssertFalse(reversed.hasValidDuration)
    }

    // MARK: - exceedsDurationThreshold

    func testExceedsDurationThreshold_usesTruncatedMinuteFloor() {
        let s = session(start: date(10, 9, 0), end: date(10, 10, 30))
        XCTAssertTrue(s.exceedsDurationThreshold(89))
        XCTAssertFalse(s.exceedsDurationThreshold(90))
    }

    func testExceedsDurationThreshold_zeroDurationDoesNotExceed() {
        let s = session(id: "z", start: date(10, 9), end: date(10, 9))
        XCTAssertFalse(s.exceedsDurationThreshold(0))
    }

    // MARK: - overlaps

    func testOverlaps_adjacentSessionsDoNotOverlap() {
        let a = session(id: "a", start: date(10, 9), end: date(10, 10))
        let b = session(id: "b", start: date(10, 10), end: date(10, 11))
        XCTAssertFalse(a.overlaps(with: b))
        XCTAssertFalse(b.overlaps(with: a))
    }

    func testOverlaps_disjointSessionsDoNotOverlap() {
        let a = session(id: "a", start: date(10, 9), end: date(10, 10))
        let b = session(id: "b", start: date(10, 12), end: date(10, 13))
        XCTAssertFalse(a.overlaps(with: b))
    }

    func testOverlaps_partialAndContainedOverlap() {
        let a = session(id: "a", start: date(10, 9), end: date(10, 11))
        let partial = session(id: "p", start: date(10, 10), end: date(10, 12))
        XCTAssertTrue(a.overlaps(with: partial))

        let contained = session(id: "c", start: date(10, 9, 30), end: date(10, 10, 30))
        XCTAssertTrue(a.overlaps(with: contained))
    }
}
