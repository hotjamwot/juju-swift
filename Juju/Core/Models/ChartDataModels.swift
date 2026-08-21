import Foundation
import SwiftUI


// MARK: - Chart Data Models
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String
}

/// Consolidated activity distribution item — used across yearly, monthly, and pie charts.
/// Replaces the previous `YearlyActivityTypeChartData`, `YearlyActivityTypeDataPoint`, and `MonthlyActivityTypeDataPoint`.
struct ActivityDistributionItem: Identifiable {
    let id = UUID()
    let activityName: String
    let sfSymbol: String
    let totalHours: Double
    let percentage: Double
    /// Breakdown of hours by project within this activity type (for tooltips)
    let projectBreakdown: [(projectName: String, emoji: String, color: String, hours: Double)]
}

struct YearlyProjectChartData: Identifiable {
    let id = UUID()
    let projectName: String
    let color: String
    let emoji: String
    let totalHours: Double
    let percentage: Double
    /// Breakdown of hours by activity type within this project (for tooltips)
    let activityBreakdown: [(activityName: String, sfSymbol: String, hours: Double)]
    
    var colorSwiftUI: Color {
        Color(hex: color)
    }
}

struct TimeSeriesData: Identifiable {
    let id = UUID()
    let period: String
    let value: Double
    var comparisonValue: Double?
    var comparisonLabel: String?
}

// MARK: - Daily Chart Data Model
struct DailyChartEntry: Identifiable {
    let id = UUID()
    let date: Date
    let dateString: String
    let projectName: String
    let projectColor: String
    let projectEmoji: String
    let durationHours: Double
    
    var colorSwiftUI: Color {
        Color(hex: projectColor)
    }
}

// MARK: - Stacked Area Chart
struct MonthlyHour: Identifiable {
    let date: Date // Use a real Date for proper sorting and axis formatting
    let hours: Double
    var id: Date { date }
}

struct WeeklyHour: Identifiable {
    let weekNumber: Int // 1-52
    let hours: Double
    var id: Int { weekNumber }
}

// Represents a complete series (one layer of the stacked chart) for a single project
struct ProjectSeriesData: Identifiable {
    let projectName: String
    let monthlyHours: [MonthlyHour] // An array of all data points for this project (for monthly charts)
    let weeklyHours: [WeeklyHour] // An array of all data points for this project (for weekly charts)
    let color: String
    let emoji: String
    var id: String { projectName }
}

// MARK: - Dashboard Chart Data Models
struct WeeklySession: Identifiable {
    let id = UUID()
    let day: String
    let startHour: Double
    let endHour: Double
    let projectName: String
    let projectColor: String
    let projectEmoji: String
    let activitySFSymbol: String
    let action: String?
    let isMilestone: Bool
    var duration: Double { endHour - startHour }
}

// MARK: - Pie Chart Data Models
struct ActivityTypePieSlice: Identifiable, Equatable {
    let id = UUID()
    let activityName: String
    let sfSymbol: String
    let totalHours: Double
    let percentage: Double
    let color: Color
    
    var label: String {
        "\(activityName) - \(String(format: "%.1f", percentage))%"
    }
    
    static func == (lhs: ActivityTypePieSlice, rhs: ActivityTypePieSlice) -> Bool {
        return lhs.activityName == rhs.activityName
    }
}

// MARK: - 90-Day Timeline Models

/// Lightweight project lookup for a day's session cards.
///
/// Carried on `DayStack` so `DaySessionInfoPanel` can resolve project
/// colours, names, and emoji without hitting the disk per session card.
struct DayProjectInfo: Identifiable, Equatable {
    let id: String           // projectID
    let name: String
    let color: String        // hex
    let emoji: String
}

/// A single calendar day in the 90-day timeline.
///
/// Carries the raw session records for the day so `DaySessionInfoPanel` can
/// show per-session details when the day column is hovered. Built by
/// `ChartDataPreparer.prepare90DayTimeline`.
struct DayStack: Identifiable, Equatable {
    let date: Date
    /// True when this day contains a milestone session (set by ChartDataPreparer)
    var isMilestone: Bool = false
    /// Individual session records for this day (set by ChartDataPreparer).
    /// Used by DaySessionInfoPanel to show per-session details on hover.
    var sessions: [SessionRecord] = []
    /// Project lookups for sessions on this day (set by ChartDataPreparer).
    /// Used by DaySessionInfoPanel for project colour/name/emoji resolution.
    var projects: [DayProjectInfo] = []
    
    var id: Date { date }
    /// Total hours across all sessions this day.
    var totalHours: Double {
        sessions.reduce(0) { $0 + Double($1.durationMinutes) / 60.0 }
    }
}

// MARK: - 90-Day Timeline Model

/// A single session rendered as a thin vertical sliver in the 90-day timeline.
///
/// The sliver is positioned by its decimal start/end hours on the Y-axis
/// (fixed range matching the weekly calendar chart) within its calendar-day
/// column on the X-axis. Duration is expressed by sliver height, but the
/// emphasis is on *when* work happened — early mornings, late evenings,
/// flow patterns — rather than total hours per day.
///
/// Sessions that cross midnight emit two slivers: one clipped to 24:00 on
/// the start day and a continuation from 0:00 on the following day.
struct DayTimelineSession: Identifiable {
    let id = UUID()
    /// Start-of-day for the column this sliver belongs to.
    let date: Date
    /// Decimal hour of session start (e.g. 14.5).
    let startHour: Double
    /// Decimal hour of session end (e.g. 16.25).
    let endHour: Double
    let projectID: String
    let projectName: String
    let projectColor: String      // hex
    let projectEmoji: String
    let isMilestone: Bool
    
    var duration: Double { endHour - startHour }
}

