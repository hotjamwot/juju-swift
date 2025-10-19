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
        
        // Compute all available data series
        viewModel.yearlyData = aggregateByMonth(from: filteredSessions)
        viewModel.weeklyData = aggregateByWeek(from: filteredSessions)
        viewModel.projectDistribution = aggregateProjectTotals(from: filteredSessions)
        viewModel.projectBreakdown = aggregateProjectBreakdown(from: filteredSessions)
    }
    
    // MARK: - Core Accessors
    
    private var filteredSessions: [SessionRecord] {
        viewModel.filteredSessions
    }
    
    private let calendar = Calendar.current
    private let formatterYYYYMMDD = DateFormatter.yyyyMMdd
    
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