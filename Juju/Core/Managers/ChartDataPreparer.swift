import Foundation
import SwiftUI

/// Responsible for parsing and aggregating raw session data into reusable time-series or categorical structures.
/// Keeps logic focused on *data integrity*, not chart styling.
@MainActor
final class ChartDataPreparer: ObservableObject {
    @Published var viewModel = ChartViewModel()
    
    // MARK: - Public Entry Point
    
    func prepareData(
        sessions: [SessionRecord],
        projects: [Project],
        filter: String
    ) {
        viewModel.sessions = sessions
        viewModel.projects = projects
        viewModel.currentFilter = filter
        
        // Transform sessions to unified ChartEntry format
        viewModel.chartEntries = transformToChartEntries(from: filteredSessions, projects: projects)
        
        // Compute all available data series
        viewModel.yearlyData = aggregateByMonth(from: filteredSessions)
        viewModel.weeklyData = aggregateByWeek(from: filteredSessions)
        viewModel.projectDistribution = aggregateProjectTotals(from: filteredSessions)
        viewModel.projectBreakdown = aggregateProjectBreakdown(from: filteredSessions)
        
        // Compute new chart data
        viewModel.dailyStackedData = prepareDailyStackedData()
        viewModel.weeklyStackedData = prepareWeeklyStackedData()
        viewModel.pieChartData = preparePieChartData()
        viewModel.projectBarData = prepareProjectBarData()
    }
    
    // MARK: - Core Accessors
    
    private var filteredSessions: [SessionRecord] {
        viewModel.filteredSessions
    }
    
    private let calendar = Calendar.current
    private let formatterYYYYMMDD = DateFormatter.yyyyMMdd
    
    // MARK: - Data Transformation Methods
    
    /// Transforms SessionRecord array to unified ChartEntry format
    private func transformToChartEntries(from sessions: [SessionRecord], projects: [Project]) -> [ChartEntry] {
        return sessions.compactMap { session in
            guard let date = formatterYYYYMMDD.date(from: session.date) else { return nil }
            guard let project = projects.first(where: { $0.name == session.projectName }) else { return nil }
            
            return ChartEntry(
                date: date,
                projectName: session.projectName,
                projectColor: project.color,
                durationMinutes: session.durationMinutes,
                startTime: session.startTime,
                endTime: session.endTime,
                notes: session.notes,
                mood: session.mood
            )
        }
    }
    
    /// Prepares data for daily stacked bar chart
    private func prepareDailyStackedData() -> [DailyChartEntry] {
        return viewModel.chartEntries.map { entry in
            DailyChartEntry(
                date: entry.date,
                dateString: formatterYYYYMMDD.string(from: entry.date),
                projectName: entry.projectName,
                projectColor: entry.projectColor,
                durationHours: entry.durationHours
            )
        }.sorted { $0.date < $1.date }
    }
    
    /// Prepares data for weekly stacked area chart
    private func prepareWeeklyStackedData() -> [StackedChartEntry] {
        var weekTotals: [Date: [String: Double]] = [:]
        
        for entry in viewModel.chartEntries {
            guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: entry.date)) else { continue }
            
            if weekTotals[weekStart] == nil {
                weekTotals[weekStart] = [:]
            }
            weekTotals[weekStart]![entry.projectName, default: 0] += entry.durationHours
        }
        
        var result: [(StackedChartEntry, Date)] = []
        for (weekDate, projectTotals) in weekTotals {
            guard let endDate = calendar.date(byAdding: .day, value: 6, to: weekDate) else { continue }
            let periodLabel = "\(weekDate.formatted(.dateTime.day().month(.abbreviated))) - \(endDate.formatted(.dateTime.day().month(.abbreviated)))"
            
            for (projectName, hours) in projectTotals {
                guard let project = viewModel.projects.first(where: { $0.name == projectName }) else { continue }
                let entry = StackedChartEntry(
                    period: periodLabel,
                    projectName: projectName,
                    projectColor: project.color,
                    value: hours
                )
                result.append((entry, weekDate))
            }
        }
        
        return result.sorted { $0.1 < $1.1 }.map { $0.0 }
    }
    
    /// Prepares data for pie chart
    private func preparePieChartData() -> [PieChartEntry] {
        var totals: [String: Double] = [:]
        for entry in viewModel.chartEntries {
            totals[entry.projectName, default: 0] += entry.durationHours
        }
        
        let totalHours = totals.values.reduce(0, +)
        return totals.compactMap { (projectName, hours) in
            guard let project = viewModel.projects.first(where: { $0.name == projectName }) else { return nil }
            return PieChartEntry(
                projectName: projectName,
                projectColor: project.color,
                value: hours,
                percentage: totalHours > 0 ? (hours / totalHours * 100) : 0
            )
        }.sorted { $0.value > $1.value }
    }
    
    /// Prepares data for project bar chart
    private func prepareProjectBarData() -> [ProjectChartData] {
        return preparePieChartData().map { pieEntry in
            ProjectChartData(
                projectName: pieEntry.projectName,
                color: pieEntry.projectColor,
                totalHours: pieEntry.value,
                percentage: pieEntry.percentage
            )
        }
    }
    
    // MARK: - Aggregations
    
    /// Groups sessions by month.
    private func aggregateByMonth(from sessions: [SessionRecord]) -> [TimeSeriesData] {
        var monthTotals: [Date: Double] = [:]
        
        for session in sessions {
            guard let date = formatterYYYYMMDD.date(from: session.date) else { continue }
            let components = calendar.dateComponents([.year, .month], from: date)
            guard let monthStart = calendar.date(from: components) else { continue }
            monthTotals[monthStart, default: 0] += Double(session.durationMinutes) / 60
        }
        
        return monthTotals.keys.sorted().map {
            TimeSeriesData(
                period: $0.formatted(.dateTime.month().year()),
                value: monthTotals[$0] ?? 0
            )
        }
    }
    
    /// Groups sessions by ISO week.
    private func aggregateByWeek(from sessions: [SessionRecord]) -> [TimeSeriesData] {
        var weekTotals: [Date: Double] = [:]
        
        for session in sessions {
            guard let date = formatterYYYYMMDD.date(from: session.date) else { continue }
            if let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) {
                weekTotals[weekStart, default: 0] += Double(session.durationMinutes) / 60
            }
        }
        
        return weekTotals.keys.sorted().map {
            let end = calendar.date(byAdding: .day, value: 6, to: $0)!
            let rangeLabel = "\($0.formatted(.dateTime.day().month(.abbreviated))) - \(end.formatted(.dateTime.day().month(.abbreviated)))"
            return TimeSeriesData(period: rangeLabel, value: weekTotals[$0] ?? 0)
        }
    }
    
    /// Sums total hours per project (for pie charts or stacked bars).
    private func aggregateProjectTotals(from sessions: [SessionRecord]) -> [ProjectChartData] {
        var totals: [String: Double] = [:]
        for session in sessions {
            totals[session.projectName, default: 0] += Double(session.durationMinutes) / 60
        }
        
        let totalHours = totals.values.reduce(0, +)
        return totals.compactMap { (name, hours) in
            guard let project = viewModel.projects.first(where: { $0.name == name }) else { return nil }
            return ProjectChartData(
                projectName: name,
                color: project.color,
                totalHours: hours,
                percentage: totalHours > 0 ? (hours / totalHours * 100) : 0
            )
        }.sorted { $0.totalHours > $1.totalHours }
    }
    
    /// Provides simple totals per project name (for bar charts or comparisons).
    private func aggregateProjectBreakdown(from sessions: [SessionRecord]) -> [TimeSeriesData] {
        let grouped = Dictionary(grouping: sessions, by: \.projectName)
        return grouped.map { (projectName, sessions) in
            let totalHours = sessions.reduce(0) { $0 + Double($1.durationMinutes) / 60 }
            return TimeSeriesData(period: projectName, value: totalHours)
        }.sorted { $0.value > $1.value }
    }
    
    // MARK: - Comparison Stats (unchanged for now)
    
    func getComparisonStats() -> [String: Any] {
        // Left mostly as-is, as it provides logic for day/week/month summaries.
        // You can later refactor this to produce reusable ComparisonData structs.
        let sessions = viewModel.sessions
        let today = Date()
        let calendar = Calendar.current
        
        func sumDay(_ date: Date) -> Double {
            let dateStr = formatterYYYYMMDD.string(from: date)
            return sessions.filter { $0.date == dateStr }
                .reduce(0) { $0 + (Double($1.durationMinutes) / 60) }
        }
        
        // Compute 7-day average vs today
        let last7Days = (1...7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        let avg7 = last7Days.map(sumDay).reduce(0, +) / Double(last7Days.count)
        let todayValue = sumDay(today)
        let dayRange = avg7 > 0 ? String(format: "%.1fh vs avg", todayValue - avg7) : ""
        
        return [
            "day": [
                "past": [["label": "7-Day Avg", "value": avg7]],
                "current": ["label": "Today", "value": todayValue, "range": dayRange]
            ]
        ]
    }
}

// MARK: - DateFormatter Helper
extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}