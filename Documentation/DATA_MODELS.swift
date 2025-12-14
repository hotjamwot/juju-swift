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
public struct Session: Codable, Identifiable {
    public let id: String
    public let date: String
    public let startTime: String
    public let endTime: String
    public let durationMinutes: Int
    public let projectName: String  // Kept for backward compatibility
    public let projectID: String?  // **UPDATED: Required for new sessions, optional for legacy**
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

        return Calendar.current.date(from: components)
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
    
    // Computed properties for session statistics
    public var totalDurationHours: Double {
        // This would typically be calculated from sessions
        // Implementation depends on SessionManager integration
        return 0.0
    }
    
    public var lastSessionDate: Date? {
        // This would typically be calculated from sessions
        // Implementation depends on SessionManager integration
        return nil
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

// MARK: - Dashboard Data Models
public struct DashboardData: Codable {
    public let weeklySessions: [Session]
    public let yearlySessions: [Session]
    public let projectTotals: [String: Double] // projectID -> total hours
    public let activityTypeTotals: [String: Double] // activityTypeID -> total hours
    public let narrativeHeadline: String
    
    public init(weeklySessions: [Session], yearlySessions: [Session], projectTotals: [String: Double], activityTypeTotals: [String: Double], narrativeHeadline: String) {
        self.weeklySessions = weeklySessions
        self.yearlySessions = yearlySessions
        self.projectTotals = projectTotals
        self.activityTypeTotals = activityTypeTotals
        self.narrativeHeadline = narrativeHeadline
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

// MARK: - Yearly Dashboard Data Models

/// Yearly Dashboard Data Model
public struct YearlyDashboardData: Codable {
    public let projectDistribution: [ProjectBarChartData]
    public let activityDistribution: [ActivityTypeBarChartData]
    public let monthlyBreakdown: [MonthlyActivityGroup]
    public let totalHours: Double
    public let narrativeHeadline: String
    
    public init(projectDistribution: [ProjectBarChartData], activityDistribution: [ActivityTypeBarChartData], monthlyBreakdown: [MonthlyActivityGroup], totalHours: Double, narrativeHeadline: String) {
        self.projectDistribution = projectDistribution
        self.activityDistribution = activityDistribution
        self.monthlyBreakdown = monthlyBreakdown
        self.totalHours = totalHours
        self.narrativeHeadline = narrativeHeadline
    }
}

/// Dashboard View Type for Navigation
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

/// Horizontal bar chart data for project distribution
public struct ProjectBarChartData: Codable {
    public let id: String
    public let projectName: String
    public let emoji: String
    public let totalHours: Double
    public let percentage: Double
    public let color: Color
    
    public init(id: String = UUID().uuidString, projectName: String, emoji: String, totalHours: Double, percentage: Double, color: Color) {
        self.id = id
        self.projectName = projectName
        self.emoji = emoji
        self.totalHours = totalHours
        self.percentage = percentage
        self.color = color
    }
    
    public var colorSwiftUI: Color {
        color
    }
}

/// Horizontal bar chart data for activity type distribution
public struct ActivityTypeBarChartData: Codable {
    public let id: String
    public let activityName: String
    public let emoji: String
    public let totalHours: Double
    public let percentage: Double
    public let color: Color
    
    public init(id: String = UUID().uuidString, activityName: String, emoji: String, totalHours: Double, percentage: Double, color: Color) {
        self.id = id
        self.activityName = activityName
        self.emoji = emoji
        self.totalHours = totalHours
        self.percentage = percentage
        self.color = color
    }
    
    public var colorSwiftUI: Color {
        color
    }
}

/// Grouped bar chart data for monthly activity breakdown
public struct MonthlyActivityGroup: Codable {
    public let id: String
    public let month: String
    public let monthNumber: Int
    public let activities: [ActivityBarData]
    
    public init(id: String = UUID().uuidString, month: String, monthNumber: Int, activities: [ActivityBarData]) {
        self.id = id
        self.month = month
        self.monthNumber = monthNumber
        self.activities = activities
    }
}

public struct ActivityBarData: Codable {
    public let id: String
    public let activityName: String
    public let emoji: String
    public let totalHours: Double
    public let color: Color
    
    public init(id: String = UUID().uuidString, activityName: String, emoji: String, totalHours: Double, color: Color) {
        self.id = id
        self.activityName = activityName
        self.emoji = emoji
        self.totalHours = totalHours
        self.color = color
    }
}

/// Monthly hour data for charts
public struct MonthlyActivityHour: Codable {
    public let id: String
    public let month: String
    public let monthNumber: Int
    public let activityName: String
    public let totalHours: Double
    
    public init(id: String = UUID().uuidString, month: String, monthNumber: Int, activityName: String, totalHours: Double) {
        self.id = id
        self.month = month
        self.monthNumber = monthNumber
        self.activityName = activityName
        self.totalHours = totalHours
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
