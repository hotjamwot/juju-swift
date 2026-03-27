/// PhaseDataIntegrityTests.swift
/// Unit tests for phase reference clearing and session validation (in-memory fixtures; no CSV / projects.json).

import XCTest
@testable import Juju

final class PhaseDataIntegrityTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)
    private let end = Date(timeIntervalSince1970: 2_000)

    private func sampleSession(
        id: String = "s1",
        projectID: String = "proj-fixture",
        phaseID: String? = "phase-active"
    ) -> SessionRecord {
        SessionRecord(
            id: id,
            startDate: start,
            endDate: end,
            projectID: projectID,
            activityTypeID: nil,
            projectPhaseID: phaseID,
            action: nil,
            isMilestone: false,
            notes: "fixture",
            mood: 7
        )
    }

    // MARK: - SessionPhaseIntegrity

    func testClearingPhaseReferences_clearsOnlyMatchingProjectAndPhases() {
        let a = sampleSession(id: "a", projectID: "p1", phaseID: "x")
        let b = sampleSession(id: "b", projectID: "p1", phaseID: "y")
        let c = sampleSession(id: "c", projectID: "p2", phaseID: "x")
        let d = sampleSession(id: "d", projectID: "p1", phaseID: nil)
        let input = [a, b, c, d]

        let (out, count) = SessionPhaseIntegrity.clearingPhaseReferences(
            in: input,
            projectID: "p1",
            phaseIDs: ["x"]
        )

        XCTAssertEqual(count, 1)
        XCTAssertNil(out.first { $0.id == "a" }!.projectPhaseID)
        XCTAssertEqual(out.first { $0.id == "b" }!.projectPhaseID, "y")
        XCTAssertEqual(out.first { $0.id == "c" }!.projectPhaseID, "x")
        XCTAssertNil(out.first { $0.id == "d" }!.projectPhaseID)
    }

    func testClearingPhaseReferences_multiplePhaseIDs() {
        let sessions = [
            sampleSession(id: "1", phaseID: "alpha"),
            sampleSession(id: "2", phaseID: "beta"),
            sampleSession(id: "3", phaseID: "gamma"),
        ]
        let (out, count) = SessionPhaseIntegrity.clearingPhaseReferences(
            in: sessions,
            projectID: "proj-fixture",
            phaseIDs: ["alpha", "gamma"]
        )
        XCTAssertEqual(count, 2)
        XCTAssertNil(out[0].projectPhaseID)
        XCTAssertEqual(out[1].projectPhaseID, "beta")
        XCTAssertNil(out[2].projectPhaseID)
    }

    func testClearingPhaseReferences_emptyInputNoOps() {
        let (out, count) = SessionPhaseIntegrity.clearingPhaseReferences(
            in: [],
            projectID: "p",
            phaseIDs: ["x"]
        )
        XCTAssertEqual(count, 0)
        XCTAssertTrue(out.isEmpty)
    }

    func testClearingPhaseReferences_emptyPhaseSetNoOps() {
        let s = [sampleSession()]
        let (out, count) = SessionPhaseIntegrity.clearingPhaseReferences(
            in: s,
            projectID: "proj-fixture",
            phaseIDs: []
        )
        XCTAssertEqual(count, 0)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].projectPhaseID, "phase-active")
    }

    func testClearingPhaseReferences_preservesOtherSessionFields() {
        let s = SessionRecord(
            id: "full",
            startDate: start,
            endDate: end,
            projectID: "proj-fixture",
            activityTypeID: "act-1",
            projectPhaseID: "phase-active",
            action: "Done",
            isMilestone: true,
            notes: "keep me",
            mood: 9
        )
        let (out, count) = SessionPhaseIntegrity.clearingPhaseReferences(
            in: [s],
            projectID: "proj-fixture",
            phaseIDs: ["phase-active"]
        )
        XCTAssertEqual(count, 1)
        let u = out[0]
        XCTAssertNil(u.projectPhaseID)
        XCTAssertEqual(u.id, s.id)
        XCTAssertEqual(u.notes, "keep me")
        XCTAssertEqual(u.mood, 9)
        XCTAssertEqual(u.activityTypeID, "act-1")
        XCTAssertEqual(u.action, "Done")
        XCTAssertTrue(u.isMilestone)
    }

    // MARK: - DataValidator + archived phases

    func testValidateSession_archivedPhaseStillValid() {
        let archived = Phase(id: "ph-arch", name: "Old track", order: 0, archived: true)
        let project = Project(id: "proj-x", name: "X", color: "#000000", about: nil, order: 0, emoji: "📁", phases: [archived])

        let session = sampleSession(projectID: "proj-x", phaseID: "ph-arch")
        let result = DataValidator.shared.validateSession(session, projectList: [project])

        XCTAssertTrue(result.isValid, "Archived phase definitions must still validate for existing sessions")
    }

    func testValidateSession_unknownPhaseInvalid() {
        let phase = Phase(id: "only-this", name: "A", order: 0, archived: false)
        let project = Project(id: "proj-x", name: "X", color: "#000000", about: nil, order: 0, emoji: "📁", phases: [phase])

        let session = sampleSession(projectID: "proj-x", phaseID: "missing-phase")
        let result = DataValidator.shared.validateSession(session, projectList: [project])

        XCTAssertFalse(result.isValid)
        if case .invalid(let reason) = result {
            XCTAssertTrue(reason.contains("phase"))
        } else {
            XCTFail("Expected invalid result")
        }
    }
}
