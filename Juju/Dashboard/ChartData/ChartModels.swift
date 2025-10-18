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

// MARK: - Chart View Models
class ChartViewModel: ObservableObject {
    @Published var yearlyData: [TimeSeriesData] = []
    @Published var weeklyData: [TimeSeriesData] = []
    @Published var projectDistribution: [ProjectChartData] = []
    @Published var projectBreakdown: [TimeSeriesData] = []
    @Published var isLoading: Bool = false
    @Published var currentFilter: String = "This Year"
    
    var sessions: [SessionRecord] = []
    var projects: [Project] = []
    
    var filteredSessions: [SessionRecord] {
        get {
            let calendar = Calendar.current
            let today = Date()
            
            switch currentFilter {
            case "Last 7 Days":
                let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today)!
                return sessions.filter { $0.date >= sevenDaysAgo }
                
            case "Last Month":
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: today)!
                return sessions.filter { $0.date >= lastMonth }
                
            case "Last Quarter":
                let lastQuarter = calendar.date(byAdding: .month, value: -3, to: today)!
                return sessions.filter { $0.date >= lastQuarter }
                
            case "This Year":
                let thisYear = calendar.date(from: DateComponents(year: today.year, month: 1, day: 1))!
                return sessions.filter { $0.date >= thisYear }
                
            case "All Time":
                return sessions
                
            default:
                let thisYear = calendar.date(from: DateComponents(year: today.year, month: 1, day: 1))!
                return sessions.filter { $0.date >= thisYear }
            }
        }
    }
}
