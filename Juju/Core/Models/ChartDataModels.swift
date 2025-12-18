import Foundation
import SwiftUI


// MARK: - Chart Data Models
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String
}

struct ProjectChartData: Identifiable {
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

struct ActivityChartData: Identifiable {
    let id = UUID()
    let activityName: String
    let emoji: String
    let totalHours: Double
    let percentage: Double
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
    let activityEmoji: String
    var duration: Double { endHour - startHour }
}

// MARK: - Pie Chart Data Models
struct ActivityTypePieSlice: Identifiable, Equatable {
    let id = UUID()
    let activityName: String
    let emoji: String
    let totalHours: Double
    let percentage: Double
    let color: Color
    
    var label: String {
        "\(emoji) \(activityName) - \(String(format: "%.1f", percentage))%"
    }
    
    static func == (lhs: ActivityTypePieSlice, rhs: ActivityTypePieSlice) -> Bool {
        return lhs.activityName == rhs.activityName
    }
}


/// Monthly hour data for charts
struct MonthlyActivityHour: Identifiable {
    let id = UUID()
    let month: String
    let monthNumber: Int
    let activityName: String
    let totalHours: Double
}

// MARK: - Yearly Chart Data Models

/// Yearly project chart data model for project distribution chart
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

/// Yearly project data point for individual data points
struct YearlyProjectDataPoint: Identifiable {
    let id = UUID()
    let projectName: String
    let emoji: String
    let totalHours: Double
    let percentage: Double
}

/// Yearly activity type chart data model for activity types distribution chart
struct YearlyActivityTypeChartData: Identifiable {
    let id = UUID()
    let activityName: String
    let emoji: String
    let totalHours: Double
    let percentage: Double
}

/// Yearly activity type data point for individual data points
struct YearlyActivityTypeDataPoint: Identifiable {
    let id = UUID()
    let activityName: String
    let emoji: String
    let totalHours: Double
    let percentage: Double
}

/// Yearly monthly chart data model for monthly activity breakdown chart
struct YearlyMonthlyChartData: Identifiable {
    let id = UUID()
    let month: String
    let monthNumber: Int
    let activityBreakdown: [YearlyMonthlyActivityDataPoint]
    let totalHours: Double
}

/// Yearly monthly activity data point for individual activity breakdowns within months
struct YearlyMonthlyActivityDataPoint: Identifiable {
    let id = UUID()
    let activityName: String
    let emoji: String
    let totalHours: Double
    let percentage: Double
}
