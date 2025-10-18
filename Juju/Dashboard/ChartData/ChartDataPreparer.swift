import Foundation
import SwiftUI

class ChartDataPreparer: ObservableObject {
    @Published var viewModel = ChartViewModel()
    
    // MARK: - Data Processing
    
    func prepareChartData(sessions: [SessionRecord], projects: [Project], filter: String) {
        viewModel.sessions = sessions
        viewModel.projects = projects
        viewModel.currentFilter = filter
        
        // Prepare all chart data
        prepareYearlyData()
        prepareWeeklyData()
        prepareProjectDistribution()
        prepareProjectBreakdown()
    }
    
    private func prepareYearlyData() {
        let calendar = Calendar.current
        let filteredSessions = viewModel.filteredSessions
        
        // Group sessions by month
        var monthlyData: [String: Double] = [:]
        
        for session in filteredSessions {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let sessionDate = dateFormatter.date(from: session.date) ?? Date()
            let components = calendar.dateComponents([.year, .month], from: sessionDate)
            let monthKey = "\(components.year ?? 2022)-\(components.month ?? 1)"
            
            let hours = Double(session.durationMinutes) / 60.0
            monthlyData[monthKey, default: 0] += hours
        }
        
        // Convert to chart data
        var chartData: [TimeSeriesData] = []
        
        // Get all months from the data
        let sortedMonths = monthlyData.keys.sorted()
        
        for monthKey in sortedMonths {
            let components = monthKey.split(separator: "-").compactMap { Int($0) }
            if components.count == 2, let year = components[0], let month = components[1] {
                let date = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM yyyy"
                
                chartData.append(TimeSeriesData(
                    period: formatter.string(from: date),
                    value: monthlyData[monthKey] ?? 0
                ))
            }
        }
        
        viewModel.yearlyData = chartData
    }
    
    private func prepareWeeklyData() {
        let calendar = Calendar.current
        let filteredSessions = viewModel.filteredSessions
        
        // Get the date range for the current filter
        var dateRange: ClosedRange<Date>
        let today = Date()
        
        switch viewModel.currentFilter {
        case "Last 7 Days":
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today)!
            dateRange = sevenDaysAgo...today
        case "Last Month":
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: today)!
            dateRange = lastMonth...today
        case "Last Quarter":
            let lastQuarter = calendar.date(byAdding: .month, value: -3, to: today)!
            dateRange = lastQuarter...today
        case "This Year":
            let thisYear = calendar.date(from: DateComponents(year: today.year, month: 1, day: 1))!
            dateRange = thisYear...today
        case "All Time":
            if let minDateStr = filteredSessions.min(by: { $0.date < $1.date })?.date,
               let minDate = DateFormatter yyyyMMdd.date(from: minDateStr) {
                dateRange = minDate...today
            } else {
                viewModel.weeklyData = []
                return
            }
        default:
            let thisYear = calendar.date(from: DateComponents(year: today.year, month: 1, day: 1))!
            dateRange = thisYear...today
        }
        
        // Group sessions by week
        var weeklyData: [String: Double] = [:]
        
        for session in filteredSessions {
            if let sessionDate = DateFormatter yyyyMMdd.date(from: session.date),
               sessionDate >= dateRange.lowerBound && sessionDate <= dateRange.upperBound {
                let weekNumber = calendar.component(.weekOfYear, from: sessionDate)
                let year = calendar.component(.year, from: sessionDate)
                let weekKey = "\(year)-\(weekNumber)"
                
                let hours = Double(session.durationMinutes) / 60.0
                weeklyData[weekKey, default: 0] += hours
            }
        }
        
        // Convert to chart data
        var chartData: [TimeSeriesData] = []
        
        // Get all weeks from the data
        let sortedWeeks = weeklyData.keys.sorted()
        
        for weekKey in sortedWeeks {
            let components = weekKey.split(separator: "-").compactMap { Int($0) }
            if components.count == 2, let year = components[0], let week = components[1] {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM dd"
                
                // Get the start date of the week for display
                let weekStart = calendar.date(from: DateComponents(yearForWeekOfYear: year, weekOfYear: week, weekday: 2))!
                let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
                
                chartData.append(TimeSeriesData(
                    period: "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))",
                    value: weeklyData[weekKey] ?? 0
                ))
            }
        }
        
        viewModel.weeklyData = chartData
    }
    
    private func prepareProjectDistribution() {
        let filteredSessions = viewModel.filteredSessions
        
        // Group sessions by project
        var projectData: [String: (totalHours: Double, sessions: [SessionRecord])] = [:]
        
        for session in filteredSessions {
            let hours = Double(session.durationMinutes) / 60.0
            if projectData[session.projectName] == nil {
                projectData[session.projectName] = (0, [])
            }
            projectData[session.projectName]?.totalHours += hours
            projectData[session.projectName]?.sessions.append(session)
        }
        
        // Calculate total hours for percentage
        let totalHours = projectData.values.reduce(0) { $0 + $1.totalHours }
        
        // Convert to chart data
        var chartData: [ProjectChartData] = []
        
        for (projectName, data) in projectData {
            if let project = viewModel.projects.first(where: { $0.name == projectName }) {
                let percentage = totalHours > 0 ? (data.totalHours / totalHours) * 100 : 0
                
                chartData.append(ProjectChartData(
                    projectName: projectName,
                    color: project.color,
                    totalHours: data.totalHours,
                    percentage: percentage
                ))
            }
        }
        
        // Sort by total hours descending
        chartData.sort { $0.totalHours > $1.totalHours }
        
        viewModel.projectDistribution = chartData
    }
    
    private func prepareProjectBreakdown() {
        let filteredSessions = viewModel.filteredSessions
        
        // Get all unique projects
        let uniqueProjects = Array(Set(filteredSessions.map { $0.projectName }))
        
        // Convert to chart data
        var chartData: [TimeSeriesData] = []
        
        for projectName in uniqueProjects {
            let projectSessions = filteredSessions.filter { $0.projectName == projectName }
            let totalHours = projectSessions.reduce(0) { $0 + Double($1.durationMinutes) / 60.0 }
            
            chartData.append(TimeSeriesData(
                period: projectName,
                value: totalHours
            ))
        }
        
        // Sort by total hours descending
        chartData.sort { $0.value > $1.value }
        
        viewModel.projectBreakdown = chartData
    }
    
    // MARK: - Comparison Stats (copied from JavaScript implementation)
    
    func getComparisonStats() -> [String: Any] {
        let sessions = viewModel.sessions
        let calendar = Calendar.current
        let today = Date()
        
        // Helper functions
        func parseDate(_ dateStr: String) -> Date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: dateStr) ?? today
        }
        
        func getWeekYear(_ date: Date) -> (year: Int, week: Int) {
            let d = calendar.date(byAdding: .day, value: 4 - (calendar.component(.weekday, from: date) == 1 ? -6 : calendar.component(.weekday, from: date) - 2), to: date)!
            let yearStart = calendar.date(from: DateComponents(year: calendar.component(.year, from: d), month: 1, day: 1))!
            let weekNo = calendar.dateComponents([.weekOfYear], from: d).weekOfYear ?? 1
            return (calendar.component(.year, from: d), weekNo)
        }
        
        func getMonthKey(_ date: Date) -> String {
            return "\(calendar.component(.year, from: date))-\(calendar.component(.month, from: date))"
        }
        
        func sumDay(_ date: Date) -> Double {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStr = dateFormatter.string(from: date)
            return sessions.filter { $0.date == dateStr }
                .reduce(0) { $0 + (Double($1.durationMinutes) / 60.0) }
        }
        
        // Day comparison
        let last7Days = (1...7).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
        let last7DayValues = last7Days.map(sumDay)
        let avg7 = last7DayValues.reduce(0, +) / Double(last7DayValues.count)
        let todayValue = sumDay(today)
        let dayRange = avg7 > 0 ? String(format: "%.1fh vs avg", (todayValue - avg7)) : ""
        
        // Week comparison
        let thisMonday = calendar.date(byAdding: .day, value: -(calendar.component(.weekday, from: today) == 1 ? 6 : calendar.component(.weekday, from: today) - 2), to: today)!
        func sumWeekRange(_ start: Date, _ end: Date) -> Double {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            return sessions.filter { session in
                let sessionDate = dateFormatter.date(from: session.date)
                return sessionDate != nil && sessionDate! >= start && sessionDate! <= end
            }.reduce(0) { $0 + (Double($1.durationMinutes) / 60.0) }
        }
        
        let weekPast = (1...3).map { i in
            let pastMonday = calendar.date(byAdding: .day, value: -7 * i, to: thisMonday)!
            let pastEnd = calendar.date(byAdding: .day, value: calendar.component(.weekday, from: today) - 2, to: pastMonday)!
            return [
                "label": "\(calendar.component(.month, from: pastMonday))/\(calendar.component(.day, from: pastMonday))-\(calendar.component(.month, from: pastEnd))/\(calendar.component(.day, from: pastEnd))",
                "value": sumWeekRange(pastMonday, pastEnd)
            ]
        }
        
        let weekCurrentValue = sumWeekRange(thisMonday, today)
        let weekAvg = weekPast.reduce(0) { $0 + ($1["value"] as? Double ?? 0) } / 3
        let weekRange = weekAvg > 0 ? String(format: "%.1fh vs avg", (weekCurrentValue - weekAvg)) : ""
        
        let weekCurrent = [
            "label": "\(calendar.component(.month, from: thisMonday))/\(calendar.component(.day, from: thisMonday))-\(calendar.component(.month, from: today))/\(calendar.component(.day, from: today))",
            "value": weekCurrentValue,
            "range": weekRange
        ]
        
        return [
            "day": [
                "past": [["label": "7-Day Avg", "value": avg7]],
                "current": ["label": "Today", "value": todayValue, "range": dayRange]
            ],
            "week": ["past": weekPast, "current": weekCurrent],
            "month": ["past": [], "current": ["label": "", "value": 0, "range": ""]]
        ]
    }
}

// MARK: - Helper Extensions
extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
