//
// DATA_MODELS.swift
// Juju Project Tracking App
//
// MARK: - ARCHITECTURAL SCHEMA REFERENCE
//
// This file serves as the definitive source of truth for the structure of all core
// business entities. All other components (View, ViewModel, Manager, Service) must
// use the types and properties defined here.
//

import Foundation

// --- Key Models Defined in ARCHITECTURE_RULES.md ---

// MARK: - 1. Session Model
// Represents a single block of tracked work/time. Must be Codable for CSV persistence.
// **UPDATED: Phase 1 & 2 Complete - Project Name Phaseout Infrastructure Ready**
public struct SessionRecord: Codable, Identifiable {
    public let id: String
    public let date: String
    public let startTime: String
    public let endTime: String
    public let durationMinutes: Int
    public let projectName: String  // Kept for backward compatibility
    public let projectID: String?
    public let activityTypeID: String?
    public let projectPhaseID: String?
    public let milestoneText: String?
    public let notes: String
    public let mood: Int?
    
    // Computed properties for date/time handling
    public var startDateTime: Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: self.date) else { return nil }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let paddedStartTime = startTime.count == 5 ? startTime + ":00" : startTime
        guard let time = timeFormatter.date(from: paddedStartTime) else { return nil }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second ?? 0

        return Calendar.current.date(from: components)
    }

    public var endDateTime: Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: self.date) else { return nil }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let paddedEndTime = endTime.count == 5 ? endTime + ":00" : endTime
        guard let time = timeFormatter.date(from: paddedEndTime) else { return nil }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second ?? 0

        var endDate = Calendar.current.date(from: components)
        
        // Fix for sessions that cross midnight: if end time is between midnight and 4 AM,
        // add 24 hours to properly calculate duration across days
        if let hour = timeComponents.hour, hour >= 0 && hour < 4 {
            endDate = Calendar.current.date(byAdding: .day, value: 1, to: endDate ?? date)
        }
        
        return endDate
    }
    
    // Helper to check if session overlaps with a date interval
    public func overlaps(with interval: DateInterval) -> Bool {
        guard let start = startDateTime, let end = endDateTime else { return false }
        return start < interval.end && end > interval.start
    }
    
    // Convenience initializer for backward compatibility (legacy sessions without new fields)
    public init(id: String, date: String, startTime: String, endTime: String, durationMinutes: Int, projectName: String, notes: String, mood: Int?) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.projectName = projectName
        self.projectID = nil
        self.activityTypeID = nil
        self.projectPhaseID = nil
        self.milestoneText = nil
        self.notes = notes
        self.mood = mood
    }
    
    // Full initializer with all fields
    public init(id: String, date: String, startTime: String, endTime: String, durationMinutes: Int, projectName: String, projectID: String?, activityTypeID: String?, projectPhaseID: String?, milestoneText: String?, notes: String, mood: Int?) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.projectName = projectName
        self.projectID = projectID
        self.activityTypeID = activityTypeID
        self.projectPhaseID = projectPhaseID
        self.milestoneText = milestoneText
        self.notes = notes
        self.mood = mood
    }
}

// MARK: - SessionRecord Extension for Data Processing
public extension SessionRecord {
    /// Fix sessions that cross midnight by adjusting end time if it's between midnight and 4 AM
    /// This ensures proper duration calculation for sessions that span across days
    /// - Returns: Fixed session record with corrected end time and duration
    func fixMidnightCrossingSession() -> SessionRecord {
        // Parse end time to check if it's between midnight and 4 AM
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let paddedEndTime = endTime.count == 5 ? endTime + ":00" : endTime
        
        guard let endTimeDate = timeFormatter.date(from: paddedEndTime),
              let endHour = Calendar.current.dateComponents([.hour], from: endTimeDate).hour,
              endHour >= 0 && endHour < 4 else {
            // End time is not between midnight and 4 AM, no fix needed
            return self
        }
        
        // Check if this session likely crosses midnight by comparing start and end times
        let paddedStartTime = startTime.count == 5 ? startTime + ":00" : startTime
        guard let startTimeDate = timeFormatter.date(from: paddedStartTime) else {
            return self
        }
        
        // If end time is earlier than start time, it likely crosses midnight
        if endTimeDate < startTimeDate {
            // Calculate the actual duration by treating end time as next day
            let nextDayEndTime = Calendar.current.date(byAdding: .day, value: 1, to: endTimeDate)
            let startDateTime = startDateTime ?? Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date()))!
            
            guard let actualEndDateTime = nextDayEndTime else {
                return self
            }
            
            let durationMinutes = Int(round(actualEndDateTime.timeIntervalSince(startDateTime) / 60))
            
            print("🔧 Fixed midnight-crossing session \(id): \(startTime) -> \(endTime) (next day), duration: \(durationMinutes) minutes")
            
            // Return fixed session with corrected duration
            return SessionRecord(
                id: id,
                date: date,
                startTime: startTime,
                endTime: endTime,
                durationMinutes: durationMinutes,
                projectName: projectName,
                projectID: projectID,
                activityTypeID: activityTypeID,
                projectPhaseID: projectPhaseID,
                milestoneText: milestoneText,
                notes: notes,
                mood: mood
            )
        }
        
        return self
    }
}

// MARK: - 2. Project Model
// Represents the entities being tracked. Must be Codable for JSON persistence.
public struct Project: Codable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var color: String
    public var about: String?
    public var order: Int
    public var emoji: String
    public var archived: Bool 
    public var phases: [Phase]
    
    // Computed properties for session statistics - **UPDATED: Now implemented with caching**
    public var totalDurationHours: Double {
        // Uses ProjectStatisticsCache for performance optimization
        // Falls back to SessionManager calculation if cache miss
        let cachedDuration = ProjectStatisticsCache.shared.getTotalDuration(for: id)
        if cachedDuration > 0 {
            return cachedDuration
        }
        
        // Fallback calculation (should rarely be needed due to caching)
        let sessionManager = SessionManager.shared
        let totalDuration = sessionManager.allSessions
            .filter { $0.projectID == id }
            .reduce(0) { $0 + Double($1.durationMinutes) / 60.0 }
        ProjectStatisticsCache.shared.setTotalDuration(totalDuration, for: id)
        return totalDuration
    }
    
    public var lastSessionDate: Date? {
        // Uses ProjectStatisticsCache for performance optimization
        // Falls back to SessionManager calculation if cache miss
        if let cachedDate = ProjectStatisticsCache.shared.getLastSessionDate(for: id) {
            return cachedDate
        }
        
        // Fallback calculation (should rarely be needed due to caching)
        let sessionManager = SessionManager.shared
        let sessions = sessionManager.allSessions
            .filter { $0.projectID == id }
            .compactMap { $0.startDateTime }
        let date = sessions.max()
        ProjectStatisticsCache.shared.setLastSessionDate(date, for: id)
        return date
    }
    
    public var swiftUIColor: Color {
        // This would use JujuUtils.Color(hex:) for hex-to-SwiftUI.Color conversion
        return Color(hex: color)
    }
    
    public init(id: String, name: String, color: String, about: String?, order: Int, emoji: String = "📁", phases: [Phase] = []) {
        self.id = id
        self.name = name
        self.color = color
        self.about = about
        self.order = order
        self.emoji = emoji
        self.archived = false
        self.phases = phases
    }
    
    public init(name: String, color: String = "#4E79A7", about: String? = nil, order: Int = 0, emoji: String = "📁", phases: [Phase] = []) {
        self.id = UUID().uuidString
        self.name = name
        self.color = color
        self.about = about
        self.order = order
        self.emoji = emoji
        self.archived = false
        self.phases = phases
    }
}

// MARK: - 3. Phase Model
// Represents project subdivisions/milestones.
public struct Phase: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public var order: Int
    public var archived: Bool
    
    public init(id: String = UUID().uuidString, name: String, order: Int = 0, archived: Bool = false) {
        self.id = id
        self.name = name
        self.order = order
        self.archived = archived
    }
}

// MARK: - 4. ActivityType Model
// Represents the type of work being done (e.g., Coding, Writing).
public struct ActivityType: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public var emoji: String
    public var description: String
    public var archived: Bool
    
    public init(id: String, name: String, emoji: String, description: String = "", archived: Bool = false) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.description = description
        self.archived = archived
    }
}

// MARK: - Supporting Types

// MARK: - Session Data Transfer Object
public struct SessionData {
    public let startTime: Date
    public let endTime: Date
    public let durationMinutes: Int
    public let projectName: String  // Kept for backward compatibility
    public let projectID: String   // Updated: Required for new sessions
    public let activityTypeID: String?
    public let projectPhaseID: String?
    public let milestoneText: String?
    public let notes: String
    
    public init(startTime: Date, endTime: Date, durationMinutes: Int, projectName: String, projectID: String, activityTypeID: String? = nil, projectPhaseID: String? = nil, milestoneText: String? = nil, notes: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.projectName = projectName
        self.projectID = projectID
        self.activityTypeID = activityTypeID
        self.projectPhaseID = projectPhaseID
        self.milestoneText = milestoneText
        self.notes = notes
    }
}

// MARK: - Year-Based File System Models
public struct YearlySessionFile {
    public let year: Int
    public let fileName: String
    public let fileURL: URL
    
    public init(year: Int, jujuPath: URL) {
        self.year = year
        self.fileName = "\(year)-data.csv"
        self.fileURL = jujuPath.appendingPathComponent(fileName)
    }
}

// MARK: - Data Migration Models
public struct DataMigrationResult {
    public let success: Bool
    public let migratedSessions: Int
    public let createdProjects: [String]
    public let errors: [String]
    
    public init(success: Bool, migratedSessions: Int, createdProjects: [String] = [], errors: [String] = []) {
        self.success = success
        self.migratedSessions = migratedSessions
        self.createdProjects = createdProjects
        self.errors = errors
    }
}

// MARK: - Data Validation Models
public struct DataIntegrityReport {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    public let repairsPerformed: [String]
    
    public init(isValid: Bool, errors: [String] = [], warnings: [String] = [], repairsPerformed: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
        self.repairsPerformed = repairsPerformed
    }
}

// MARK: - Dashboard Data Models
public struct DashboardData: Codable {
    public let weeklySessions: [SessionRecord]
    public let projectTotals: [String: Double] // projectID -> total hours
    public let activityTypeTotals: [String: Double] // activityTypeID -> total hours
    public let narrativeHeadline: String
    
    public init(weeklySessions: [SessionRecord], projectTotals: [String: Double], activityTypeTotals: [String: Double], narrativeHeadline: String) {
        self.weeklySessions = weeklySessions
        self.projectTotals = projectTotals
        self.activityTypeTotals = activityTypeTotals
        self.narrativeHeadline = narrativeHeadline
    }
}

// MARK: - Filter Bar Data Models
/// Date range for custom date filtering in sessions
public struct DateRange: Codable, Identifiable {
    public let id = UUID()
    public var startDate: Date
    public var endDate: Date
    
    var isValid: Bool {
        return startDate <= endDate
    }
    
    var durationDescription: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .weekOfMonth]
        formatter.maximumUnitCount = 1
        formatter.unitsStyle = .abbreviated
        
        let duration = endDate.timeIntervalSince(startDate)
        return formatter.string(from: duration) ?? "0d"
    }
}

/// Available date filter options for sessions
public enum SessionsDateFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisYear = "This Year"
    case custom = "Custom Range"
    case clear = "Clear"
    
    public var id: String { rawValue }
    public var title: String { rawValue }
}

/// Observable filter state for sessions view
public class FilterExportState: ObservableObject {
    @Published var isExpanded: Bool = false
    
    // Filter state
    @Published var projectFilter: String = "All"
    @Published var activityTypeFilter: String = "All"
    @Published var selectedDateFilter: SessionsDateFilter = .thisWeek
    @Published var customDateRange: DateRange? = nil
    
    // Manual refresh control
    @Published var shouldRefresh: Bool = false
    
    /// Call this when you want to manually refresh the filtered data
    func requestManualRefresh() {
        shouldRefresh.toggle()
    }
    
    /// Clear all filters and reset to default state
    func clearFilters() {
        projectFilter = "All"
        activityTypeFilter = "All"
        selectedDateFilter = .thisWeek
        customDateRange = nil
    }
}

// MARK: - Chart Data Models
public struct ChartDataPoint: Codable {
    public let label: String
    public let value: Double
    public let color: String
    
    public init(label: String, value: Double, color: String) {
        self.label = label
        self.value = value
        self.color = color
    }
}

public struct BubbleChartDataPoint: Codable {
    public let x: Double
    public let y: Double
    public let size: Double
    public let label: String
    public let color: String
    
    public init(x: Double, y: Double, size: Double, label: String, color: String) {
        self.x = x
        self.y = y
        self.size = size
        self.label = label
        self.color = color
    }
}

// MARK: - Editorial Engine Data Models
/// Enhanced session data for a specific time period with comprehensive analytics
/// FUTURE USE: Foundation for comparative analytics and trend detection
public struct PeriodSessionData: Identifiable {
    public let id = UUID()
    public let period: ChartTimePeriod
    public let sessions: [SessionRecord]
    public let totalHours: Double
    public let topActivity: (name: String, emoji: String)
    public let topProject: (name: String, emoji: String)
    public let milestones: [Milestone]
    public let averageDailyHours: Double
    public let activityDistribution: [String: Double] // activityID -> hours
    public let projectDistribution: [String: Double] // projectName -> hours
    public let timeRange: DateInterval
    
    public init(period: ChartTimePeriod, sessions: [SessionRecord], totalHours: Double, topActivity: (String, String), topProject: (String, String), milestones: [Milestone], averageDailyHours: Double, activityDistribution: [String : Double], projectDistribution: [String : Double], timeRange: DateInterval) {
        self.period = period
        self.sessions = sessions
        self.totalHours = totalHours
        self.topActivity = topActivity
        self.topProject = topProject
        self.milestones = milestones
        self.averageDailyHours = averageDailyHours
        self.activityDistribution = activityDistribution
        self.projectDistribution = projectDistribution
        self.timeRange = timeRange
    }
}

/// Comparative analytics between two time periods
/// FUTURE USE: Week-on-week, month-on-month comparisons
public struct ComparativeAnalytics: Identifiable {
    public let id = UUID()
    public let current: PeriodSessionData
    public let previous: PeriodSessionData
    public let trends: AnalyticsTrends
    
    public init(current: PeriodSessionData, previous: PeriodSessionData, trends: AnalyticsTrends) {
        self.current = current
        self.previous = previous
        self.trends = trends
    }
}

/// Trend analysis results for comparative analytics
/// FUTURE USE: Comparative analytics and insight generation
public struct AnalyticsTrends: Identifiable {
    public let id = UUID()
    public let totalHoursChange: Double // Percentage change
    public let topActivityChange: (from: String, to: String, change: Double)
    public let topProjectChange: (from: String, to: String, change: Double)
    public let milestoneCountChange: Int
    public let averageDailyHoursChange: Double
    public let activityDistributionChanges: [String: Double] // activityID -> percentage change
    public let projectDistributionChanges: [String: Double] // projectName -> percentage change
    
    public init(totalHoursChange: Double, topActivityChange: (String, String, Double), topProjectChange: (String, String, Double), milestoneCountChange: Int, averageDailyHoursChange: Double, activityDistributionChanges: [String : Double], projectDistributionChanges: [String : Double]) {
        self.totalHoursChange = totalHoursChange
        self.topActivityChange = topActivityChange
        self.topProjectChange = topProjectChange
        self.milestoneCountChange = milestoneCountChange
        self.averageDailyHoursChange = averageDailyHoursChange
        self.activityDistributionChanges = activityDistributionChanges
        self.projectDistributionChanges = projectDistributionChanges
    }
}

/// Time period enum for Editorial Engine filtering
/// FUTURE USE: Designed to support comparative analytics (week-on-week, month-on-month)
public enum ChartTimePeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case year
    case allTime

    public var id: String { self.rawValue }

    public var title: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        case .allTime: return "All Time"
        }
    }
    
    /// Get the previous period for comparative analysis
    /// FUTURE USE: Enables week-on-week, month-on-month comparisons
    public var previousPeriod: ChartTimePeriod {
        return self // Placeholder for future implementation
    }
    
    /// Get the duration in days for this period
    /// FUTURE USE: Normalization for fair comparisons across different time periods
    public var durationInDays: Int {
        switch self {
        case .week: return 7
        case .month: return 30 // Approximate
        case .year: return 365 // Approximate
        case .allTime: return Int.max
        }
    }
}

// MARK: - Dashboard View Type for Navigation
public enum DashboardViewType: CaseIterable {
    case weekly
    case yearly
    
    public var title: String {
        switch self {
        case .weekly:
            return "Weekly"
        case .yearly:
            return "Yearly"
        }
    }
    
    public var next: DashboardViewType {
        switch self {
        case .weekly:
            return .yearly
        case .yearly:
            return .weekly
        }
    }
}

// MARK: - Extension for Color Support
// Note: This requires JujuUtils.Color extension for hex string conversion
public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hex)
        var hexNumber: UInt64 = 0
        var r: Double = 0.0, g: Double = 0.0, b: Double = 0.0
        
        if hex.hasPrefix("#") {
            scanner.scanLocation = 1
        }
        
        if scanner.scanHexInt64(&hexNumber) {
            r = Double((hexNumber & 0xff0000) >> 16) / 255
            g = Double((hexNumber & 0x00ff00) >> 8) / 255
            b = Double(hexNumber & 0x0000ff) / 255
        }
        
        self.init(red: r, green: g, blue: b)
    }
}
