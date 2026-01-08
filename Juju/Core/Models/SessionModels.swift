import Foundation

// MARK: - Session Record (Clean Model)
public struct SessionRecord: Identifiable, Codable {
    public let id: String
    public let startDate: Date
    public let endDate: Date
    public let projectID: String
    public let activityTypeID: String?
    public let projectPhaseID: String?
    public let milestoneText: String?
    public let notes: String
    public let mood: Int?
    
    public init(
        id: String = UUID().uuidString,
        startDate: Date,
        endDate: Date,
        projectID: String,
        activityTypeID: String? = nil,
        projectPhaseID: String? = nil,
        milestoneText: String? = nil,
        notes: String = "",
        mood: Int? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.projectID = projectID
        self.activityTypeID = activityTypeID
        self.projectPhaseID = projectPhaseID
        self.milestoneText = milestoneText
        self.notes = notes
        self.mood = mood
    }
    
    public var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }
    
    func overlaps(with interval: DateInterval) -> Bool {
        startDate < interval.end && endDate > interval.start
    }
}

// MARK: - Session Creation DTO
struct SessionData {
    let startDate: Date
    let endDate: Date
    let projectID: String
    let activityTypeID: String?
    let projectPhaseID: String?
    let milestoneText: String?
    let notes: String
    let mood: Int?
    
    // Convenience properties for backward compatibility
    var startTime: Date { startDate }
    var endTime: Date { endDate }
    
    init(
        startDate: Date,
        endDate: Date,
        projectID: String,
        activityTypeID: String? = nil,
        projectPhaseID: String? = nil,
        milestoneText: String? = nil,
        notes: String = "",
        mood: Int? = nil
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.projectID = projectID
        self.activityTypeID = activityTypeID
        self.projectPhaseID = projectPhaseID
        self.milestoneText = milestoneText
        self.notes = notes
        self.mood = mood
    }
    
    // Convenience initializer for backward compatibility with old code using startTime/endTime
    init(
        startTime: Date,
        endTime: Date,
        projectID: String,
        activityTypeID: String? = nil,
        projectPhaseID: String? = nil,
        milestoneText: String? = nil,
        notes: String = "",
        mood: Int? = nil
    ) {
        self.startDate = startTime
        self.endDate = endTime
        self.projectID = projectID
        self.activityTypeID = activityTypeID
        self.projectPhaseID = projectPhaseID
        self.milestoneText = milestoneText
        self.notes = notes
        self.mood = mood
    }
}

// MARK: - Session Errors
enum SessionError: Error {
    case invalidProjectID
    case invalidDate
    case invalidTimeRange
}

// MARK: - Project Name Resolution
extension SessionRecord {
    /// Get project name from projectID by looking up in projects array
    func getProjectName(from projects: [Project]) -> String {
        projects.first { $0.id == projectID }?.name ?? projectID
    }
}
