/// SessionDataParserTests.swift
/// Purpose: Unit tests for session CSV parse/convert integrity (no UI).
/// AI Notes: Legacy fixtures match branches in `SessionDataParser.parseSessionsFromCSV`.

import XCTest
@testable import Juju

final class SessionDataParserTests: XCTestCase {
    private var parser: SessionDataParser!

    override func setUp() {
        super.setUp()
        parser = SessionDataParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func assertSessionsEqual(
        _ a: SessionRecord,
        _ b: SessionRecord,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(a.id, b.id, file: file, line: line)
        XCTAssertEqual(a.projectID, b.projectID, file: file, line: line)
        XCTAssertEqual(a.activityTypeID, b.activityTypeID, file: file, line: line)
        XCTAssertEqual(a.projectPhaseID, b.projectPhaseID, file: file, line: line)
        XCTAssertEqual(a.action, b.action, file: file, line: line)
        XCTAssertEqual(a.isMilestone, b.isMilestone, file: file, line: line)
        XCTAssertEqual(a.notes, b.notes, file: file, line: line)
        XCTAssertEqual(a.mood, b.mood, file: file, line: line)
        XCTAssertEqual(a.startDate.timeIntervalSince1970, b.startDate.timeIntervalSince1970, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(a.endDate.timeIntervalSince1970, b.endDate.timeIntervalSince1970, accuracy: 0.001, file: file, line: line)
    }

    // MARK: - Tests

    func testParse_canonicalCSV_parsesAllFields() {
        let csv = """
        id,start_date,end_date,project_id,activity_type_id,project_phase_id,action,is_milestone,notes,mood
        1,2026-03-27 10:00:00,2026-03-27 11:00:00,proj1,act1,phase1,,0,Deep work,7
        """

        let (sessions, _) = parser.parseSessionsFromCSV(csv, hasIdColumn: true)
        XCTAssertEqual(sessions.count, 1)
        let s = sessions[0]

        XCTAssertEqual(s.id, "1")
        XCTAssertEqual(s.projectID, "proj1")
        XCTAssertEqual(s.activityTypeID, "act1")
        XCTAssertEqual(s.projectPhaseID, "phase1")
        XCTAssertNil(s.action)
        XCTAssertFalse(s.isMilestone)
        XCTAssertEqual(s.notes, "Deep work")
        XCTAssertEqual(s.mood, 7)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let start = s.startDate
        let end = s.endDate
        XCTAssertEqual(cal.component(.year, from: start), 2026)
        XCTAssertEqual(cal.component(.month, from: start), 3)
        XCTAssertEqual(cal.component(.day, from: start), 27)
        XCTAssertEqual(cal.component(.hour, from: start), 10)
        XCTAssertEqual(cal.component(.minute, from: start), 0)
        XCTAssertEqual(cal.component(.day, from: end), 27)
        XCTAssertEqual(cal.component(.hour, from: end), 11)
    }

    /// Column order is ignored when headers use the modern names (`columnIndex` map).
    func testParse_reorderedModernHeaders_mapsFieldsCorrectly() {
        let csv = """
        notes,mood,id,start_date,end_date,project_id,activity_type_id,project_phase_id,action,is_milestone
        Reordered row,8,row-reorder,2026-03-27 09:15:00,2026-03-27 10:15:00,proj-x,act-x,phase-x,Shipped,1
        """

        let (sessions, _) = parser.parseSessionsFromCSV(csv, hasIdColumn: true)
        XCTAssertEqual(sessions.count, 1)
        let s = sessions[0]

        XCTAssertEqual(s.id, "row-reorder")
        XCTAssertEqual(s.projectID, "proj-x")
        XCTAssertEqual(s.notes, "Reordered row")
        XCTAssertEqual(s.mood, 8)
        XCTAssertEqual(s.action, "Shipped")
        XCTAssertTrue(s.isMilestone)
        XCTAssertEqual(s.activityTypeID, "act-x")
        XCTAssertEqual(s.projectPhaseID, "phase-x")
    }

    /// Legacy layout: single `date` plus `start_time` / `end_time` and `project_id` (no `start_date` column).
    func testParse_legacyDateAndTimeColumns_producesValidSession() {
        let csv = """
        id,date,start_time,end_time,project_id,notes,mood
        leg-1,2026-03-27,10:00:00,11:00:00,proj-legacy,Legacy note,5
        """

        let (sessions, _) = parser.parseSessionsFromCSV(csv, hasIdColumn: true)
        XCTAssertEqual(sessions.count, 1)
        let s = sessions[0]

        XCTAssertEqual(s.id, "leg-1")
        XCTAssertEqual(s.projectID, "proj-legacy")
        XCTAssertEqual(s.notes, "Legacy note")
        XCTAssertEqual(s.mood, 5)
        XCTAssertNil(s.activityTypeID)
        XCTAssertNil(s.projectPhaseID)
        XCTAssertNil(s.action)
        XCTAssertFalse(s.isMilestone)

        XCTAssertEqual(s.durationMinutes, 60)
    }

    func testRoundTrip_convertToCSVAndBack_preservesSession() {
        let original = SessionRecord(
            id: "rt-1",
            startDate: Date(timeIntervalSince1970: 1_714_000_000), // arbitrary fixed instant
            endDate: Date(timeIntervalSince1970: 1_714_003_600),
            projectID: "proj-rt",
            activityTypeID: "act-rt",
            projectPhaseID: "phase-rt",
            action: "Round trip",
            isMilestone: true,
            notes: "Notes RT",
            mood: 6
        )

        let csv = parser.convertSessionsToCSV([original])
        let (parsed, _) = parser.parseSessionsFromCSV(csv, hasIdColumn: true)
        XCTAssertEqual(parsed.count, 1)
        assertSessionsEqual(original, parsed[0])
    }

    func testParse_sparseOptionals_nilOrEmptyDefaults() {
        let csv = """
        id,start_date,end_date,project_id,activity_type_id,project_phase_id,action,is_milestone,notes,mood
        sparse,2026-01-01 08:00:00,2026-01-01 09:00:00,proj-only,,,,0,, 
        """

        let (sessions, _) = parser.parseSessionsFromCSV(csv, hasIdColumn: true)
        XCTAssertEqual(sessions.count, 1)
        let s = sessions[0]

        XCTAssertEqual(s.id, "sparse")
        XCTAssertEqual(s.projectID, "proj-only")
        XCTAssertNil(s.activityTypeID)
        XCTAssertNil(s.projectPhaseID)
        XCTAssertNil(s.action)
        XCTAssertFalse(s.isMilestone)
        XCTAssertEqual(s.notes, "")
        XCTAssertNil(s.mood)
    }

    func testParse_midnightSpanning_computesDurationAcrossDays() {
        let csv = """
        id,start_date,end_date,project_id,activity_type_id,project_phase_id,action,is_milestone,notes,mood
        night,2026-03-27 23:30:00,2026-03-28 00:30:00,proj-night,,,,0,Cross midnight,
        """

        let (sessions, _) = parser.parseSessionsFromCSV(csv, hasIdColumn: true)
        XCTAssertEqual(sessions.count, 1)
        let s = sessions[0]

        XCTAssertEqual(s.durationMinutes, 60)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        XCTAssertEqual(cal.component(.day, from: s.startDate), 27)
        XCTAssertEqual(cal.component(.hour, from: s.startDate), 23)
        XCTAssertEqual(cal.component(.minute, from: s.startDate), 30)
        XCTAssertEqual(cal.component(.day, from: s.endDate), 28)
        XCTAssertEqual(cal.component(.hour, from: s.endDate), 0)
        XCTAssertEqual(cal.component(.minute, from: s.endDate), 30)
    }
}
