import Foundation
import SwiftUI

// MARK: - Unified Chart Data Model
struct ChartEntry: Identifiable {
    let id = UUID()
    let date: Date
    let projectName: String
    let projectColor: String
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
    var duration: Double { endHour - startHour }
}
