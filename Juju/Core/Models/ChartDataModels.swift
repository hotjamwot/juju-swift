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
}

struct YearlyProjectChartData: Identifiable {
    let id = UUID()
    let projectName: String
    let color: String
    let emoji: String
    let totalHours: Double
    let percentage: Double
    
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

// MARK: - 90-Day Stacked Bar Chart Models

/// A single day's project breakdown for the 90-day stacked bar chart.
struct DayStack: Identifiable {
    let date: Date
    let segments: [ProjectSegment]  // sorted bottom-to-top by hours descending
    
    var id: Date { date }
    var totalHours: Double { segments.reduce(0) { $0 + $1.hours } }
    var isToday: Bool { Calendar.current.isDateInToday(date) }
}

/// One coloured segment within a day bar.
struct ProjectSegment: Identifiable {
    let id = UUID()
    let projectID: String
    let projectName: String
    let emoji: String
    let color: String      // hex
    let hours: Double
}

