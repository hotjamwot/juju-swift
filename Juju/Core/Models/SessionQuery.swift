import Foundation

// MARK: - Session Query Model
struct SessionQuery {
    let dateInterval: DateInterval?
    let projectIDs: [String]?
    let activityTypeIDs: [String]?
    let projectPhaseIDs: [String]?
    let limit: Int?
    let offset: Int?
    
    init(
        dateInterval: DateInterval? = nil,
        projectIDs: [String]? = nil,
        activityTypeIDs: [String]? = nil,
        projectPhaseIDs: [String]? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        self.dateInterval = dateInterval
        self.projectIDs = projectIDs
        self.activityTypeIDs = activityTypeIDs
        self.projectPhaseIDs = projectPhaseIDs
        self.limit = limit
        self.offset = offset
    }
    
    /// Create a query for current week sessions
    static func currentWeek() -> SessionQuery {
        let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), end: Date())
        return SessionQuery(dateInterval: weekInterval)
    }
    
    /// Create a query for current year sessions
    static func currentYear() -> SessionQuery {
        let yearInterval = Calendar.current.dateInterval(of: .year, for: Date()) ?? DateInterval(start: Date(), end: Date())
        return SessionQuery(dateInterval: yearInterval)
    }
    
    /// Create a query for a specific date range
    static func dateRange(start: Date, end: Date) -> SessionQuery {
        return SessionQuery(dateInterval: DateInterval(start: start, end: end))
    }
    
    /// Create a query for specific projects
    static func projects(_ projectIDs: [String]) -> SessionQuery {
        return SessionQuery(projectIDs: projectIDs)
    }
    
    /// Create a query for specific activity types
    static func activityTypes(_ activityTypeIDs: [String]) -> SessionQuery {
        return SessionQuery(activityTypeIDs: activityTypeIDs)
    }
}

// MARK: - Session Query Extensions
extension SessionQuery {
    /// Check if this query matches a session record
    func matches(_ session: SessionRecord) -> Bool {
        // Check date interval
        if let dateInterval = dateInterval {
            if !session.overlaps(with: dateInterval) {
                return false
            }
        }
        
        // Check project IDs
        if let projectIDs = projectIDs, !projectIDs.isEmpty {
            if !projectIDs.contains(session.projectID) {
                return false
            }
        }
        
        // Check activity type IDs
        if let activityTypeIDs = activityTypeIDs, !activityTypeIDs.isEmpty {
            if let activityTypeID = session.activityTypeID, !activityTypeIDs.contains(activityTypeID) {
                return false
            }
        }
        
        // Check project phase IDs
        if let projectPhaseIDs = projectPhaseIDs, !projectPhaseIDs.isEmpty {
            if let projectPhaseID = session.projectPhaseID, !projectPhaseIDs.contains(projectPhaseID) {
                return false
            }
        }
        
        return true
    }
    
    /// Apply pagination to a filtered session array
    func applyPagination(to sessions: [SessionRecord]) -> [SessionRecord] {
        let offset = self.offset ?? 0
        let limit = self.limit ?? sessions.count
        
        guard offset < sessions.count else {
            return []
        }
        
        let endIndex = min(offset + limit, sessions.count)
        return Array(sessions[offset..<endIndex])
    }
}