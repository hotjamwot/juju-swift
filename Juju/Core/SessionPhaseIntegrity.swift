import Foundation

/// Pure transformations for keeping `SessionRecord.projectPhaseID` aligned with project phase definitions.
/// Used by `SessionManager` and unit-tested without persistence.
enum SessionPhaseIntegrity {
    /// Returns a new session array with `projectPhaseID` set to `nil` for every row where
    /// `projectID` matches and the current phase id is in `phaseIDs`.
    static func clearingPhaseReferences(
        in sessions: [SessionRecord],
        projectID: String,
        phaseIDs: Set<String>
    ) -> (sessions: [SessionRecord], clearedCount: Int) {
        guard !projectID.isEmpty, !phaseIDs.isEmpty else {
            return (sessions, 0)
        }
        var cleared = 0
        let updated = sessions.map { s -> SessionRecord in
            guard s.projectID == projectID,
                  let pid = s.projectPhaseID,
                  phaseIDs.contains(pid) else {
                return s
            }
            cleared += 1
            return SessionRecord(
                id: s.id,
                startDate: s.startDate,
                endDate: s.endDate,
                projectID: s.projectID,
                activityTypeID: s.activityTypeID,
                projectPhaseID: nil,
                action: s.action,
                isMilestone: s.isMilestone,
                notes: s.notes,
                mood: s.mood
            )
        }
        return (updated, cleared)
    }
}
