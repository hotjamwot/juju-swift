import Foundation
import SwiftUI

// MARK: - Unified Chart Data Model
struct ChartEntry: Identifiable {
    let id = UUID()
    let date: Date
    let projectName: String
    let projectColor: String
    let projectEmoji: String
    let durationMinutes: Int
    let startTime: String
    let endTime: String
    let notes: String
    let mood: Int?
    
    var durationHours: Double {
        Double(durationMinutes) / 60.0
    }
    
    var projectColorSwiftUI: Color {
        Color(hex: projectColor)
    }
}

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
// Represents a complete series (one layer of the stacked chart) for a single project
struct ProjectSeriesData: Identifiable {
    let projectName: String
    let monthlyHours: [MonthlyHour] // An array of all data points for this project
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

// MARK: - Weekly Stacked Bar Chart Data Models

/// Represents a single week of the year with its associated data
struct WeekOfYear: Identifiable {
    let id = UUID()
    let weekNumber: Int // 1-52
    let year: Int
    let month: Int // 1-12 for month abbreviation mapping
    var monthLabel: String {
        let monthAbbreviations = ["", "J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
        return monthAbbreviations[month]
    }
    let startDate: Date
    let endDate: Date
    
    var id_legacy: Int { weekNumber } // For SwiftUI Charts compatibility
}

/// Represents individual project data for a specific week
struct ProjectWeeklyData: Identifiable {
    let id = UUID()
    let projectName: String
    let projectColor: String
    let projectEmoji: String
    let hours: Double
    let weekId: Int // Reference to WeekOfYear.weekNumber
    
    var colorSwiftUI: Color {
        Color(hex: projectColor)
    }
}

/// Represents the complete weekly stacked bar chart data
struct WeeklyStackedBarChartData: Identifiable {
    let id = UUID()
    let week: WeekOfYear
    let projectData: [ProjectWeeklyData]
    
    var totalHours: Double {
        projectData.reduce(0) { $0 + $1.hours }
    }
}
