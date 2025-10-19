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
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            switch currentFilter {
            case "Last month":
                // Rolling last 30 days including today
                let start = calendar.date(byAdding: .day, value: -29, to: today)!
                let startStr = dateFormatter.string(from: start)
                let todayStr = dateFormatter.string(from: today)
                return sessions.filter { $0.date >= startStr && $0.date <= todayStr }
                
            case "Last 90 days":
                // Rolling last 90 days including today
                let start = calendar.date(byAdding: .day, value: -89, to: today)!
                let startStr = dateFormatter.string(from: start)
                let todayStr = dateFormatter.string(from: today)
                return sessions.filter { $0.date >= startStr && $0.date <= todayStr }
                
            case "This Year":
                let thisYear = calendar.date(from: DateComponents(year: calendar.component(.year, from: today), month: 1, day: 1))!
                let thisYearStr = dateFormatter.string(from: thisYear)
                let todayStr = dateFormatter.string(from: today)
                return sessions.filter { $0.date >= thisYearStr && $0.date <= todayStr }
                
            case "All Time":
                return sessions
                
            default:
                let thisYear = calendar.date(from: DateComponents(year: calendar.component(.year, from: today), month: 1, day: 1))!
                let thisYearStr = dateFormatter.string(from: thisYear)
                let todayStr = dateFormatter.string(from: today)
                return sessions.filter { $0.date >= thisYearStr && $0.date <= todayStr }
            }
        }
    }
}
