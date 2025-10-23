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

// MARK: - Stacked Chart Data Models
struct StackedChartEntry: Identifiable {
    let id = UUID()
    let period: String
    let projectName: String
    let projectColor: String
    let value: Double
    
    var colorSwiftUI: Color {
        Color(hex: projectColor)
    }
}

struct PieChartEntry: Identifiable {
    let id = UUID()
    let projectName: String
    let projectColor: String
    let value: Double
    let percentage: Double
    
    var colorSwiftUI: Color {
        Color(hex: projectColor)
    }
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

// MARK: - Chart View Models
@MainActor
class ChartViewModel: ObservableObject {
    @Published var yearlyData: [TimeSeriesData] = []
    @Published var weeklyData: [TimeSeriesData] = []
    @Published var projectDistribution: [ProjectChartData] = []
    @Published var projectBreakdown: [TimeSeriesData] = []
    @Published var isLoading: Bool = false
    @Published var currentFilter: TimePeriod = .last90Days
    // New chart data arrays
    @Published var chartEntries: [ChartEntry] = []
    @Published var dailyStackedData: [DailyChartEntry] = []
    @Published var weeklyStackedData: [StackedChartEntry] = []
    @Published var pieChartData: [PieChartEntry] = []
    @Published var projectBarData: [ProjectChartData] = []
    
    var sessions: [SessionRecord] = []
    var projects: [Project] = []
    
    var filteredSessions: [SessionRecord] {
        get {
            let calendar = Calendar.current
            let today = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            switch currentFilter {
            case .lastMonth:
                // Rolling last 30 days including today
                let start = calendar.date(byAdding: .day, value: -29, to: today)!
                let startStr = dateFormatter.string(from: start)
                let todayStr = dateFormatter.string(from: today)
                return sessions.filter { $0.date >= startStr && $0.date <= todayStr }
                
            case .last90Days:
                // Rolling last 90 days including today
                let start = calendar.date(byAdding: .day, value: -89, to: today)!
                let startStr = dateFormatter.string(from: start)
                let todayStr = dateFormatter.string(from: today)
                return sessions.filter { $0.date >= startStr && $0.date <= todayStr }
                
            case .thisYear:
                let thisYear = calendar.date(from: DateComponents(year: calendar.component(.year, from: today), month: 1, day: 1))!
                let thisYearStr = dateFormatter.string(from: thisYear)
                let todayStr = dateFormatter.string(from: today)
                return sessions.filter { $0.date >= thisYearStr && $0.date <= todayStr }
                
            default:
                let thisYear = calendar.date(from: DateComponents(year: calendar.component(.year, from: today), month: 1, day: 1))!
                let thisYearStr = dateFormatter.string(from: thisYear)
                let todayStr = dateFormatter.string(from: today)
                return sessions.filter { $0.date >= thisYearStr && $0.date <= todayStr }
            }
        }
    }
}
