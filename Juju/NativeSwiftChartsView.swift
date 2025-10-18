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

// MARK: - Chart View Model
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
                return sessions.filter { 
                    let sessionDate = parseDate($0.date)
                    return sessionDate >= sevenDaysAgo
                }
                
            case "Last Month":
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: today)!
                return sessions.filter { 
                    let sessionDate = parseDate($0.date)
                    return sessionDate >= lastMonth
                }
                
            case "Last Quarter":
                let lastQuarter = calendar.date(byAdding: .month, value: -3, to: today)!
                return sessions.filter { 
                    let sessionDate = parseDate($0.date)
                    return sessionDate >= lastQuarter
                }
                
            case "This Year":
                let thisYear = calendar.date(from: DateComponents(year: calendar.component(.year, from: today), month: 1, day: 1))!
                return sessions.filter { 
                    let sessionDate = parseDate($0.date)
                    return sessionDate >= thisYear
                }
                
            case "All Time":
                return sessions
                
            default:
                let thisYear = calendar.date(from: DateComponents(year: calendar.component(.year, from: today), month: 1, day: 1))!
                return sessions.filter { 
                    let sessionDate = parseDate($0.date)
                    return sessionDate >= thisYear
                }
            }
        }
    }
    
    private func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString) ?? Date()
    }
}

// MARK: - Chart Data Preparer (simplified version)
class ChartDataPreparer: ObservableObject {
    var viewModel = ChartViewModel()
    
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
            if components.count == 2 {
                let year = components[0]
                let month = components[1]
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
            let thisYear = calendar.date(from: DateComponents(year: calendar.component(.year, from: today), month: 1, day: 1))!
            dateRange = thisYear...today
        case "All Time":
            if let minDateStr = filteredSessions.min(by: { $0.date < $1.date })?.date,
               let minDate = DateFormatter.yyyyMMdd.date(from: minDateStr) {
                dateRange = minDate...today
            } else {
                viewModel.weeklyData = []
                return
            }
        default:
            let thisYear = calendar.date(from: DateComponents(year: calendar.component(.year, from: today), month: 1, day: 1))!
            dateRange = thisYear...today
        }
        
        // Group sessions by week
        var weeklyData: [String: Double] = [:]
        
        for session in filteredSessions {
            if let sessionDate = DateFormatter.yyyyMMdd.date(from: session.date),
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
            if components.count == 2 {
                let year = components[0]
                let week = components[1]
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM dd"
                
                // Get the start date of the week for display
                let weekStart = calendar.date(from: DateComponents(weekday: 2, weekOfYear: week, yearForWeekOfYear: year))!
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
            ] as [String: Any]
        }
        
        let weekCurrentValue = sumWeekRange(thisMonday, today)
        let weekAvg = weekPast.reduce(0) { $0 + ($1["value"] as? Double ?? 0) } / 3
        let weekRange = weekAvg > 0 ? String(format: "%.1fh vs avg", (weekCurrentValue - weekAvg)) : ""
        
        let weekCurrent = [
            "label": "\(calendar.component(.month, from: thisMonday))/\(calendar.component(.day, from: thisMonday))-\(calendar.component(.month, from: today))/\(calendar.component(.day, from: today))",
            "value": weekCurrentValue,
            "range": weekRange
        ] as [String: Any]
        
        return [
            "day": [
                "past": [["label": "7-Day Avg", "value": avg7] as [String: Any]],
                "current": ["label": "Today", "value": todayValue, "range": dayRange] as [String: Any]
            ] as [String: Any],
            "week": ["past": weekPast, "current": weekCurrent] as [String: Any],
            "month": [
                "past": [] as [[String: Any]],
                "current": ["label": "", "value": 0, "range": ""] as [String: Any]
            ] as [String: Any]
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

struct NativeSwiftChartsView: View {
    @StateObject private var chartDataPreparer = ChartDataPreparer()
    @State private var currentFilter = "This Year"
    @State private var sessions: [SessionRecord] = []
    @State private var projects: [Project] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and filter controls
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Tracking")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Showing data for: \(currentFilter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Filter buttons
                HStack(spacing: 8) {
                    FilterButton(title: "Last 7 Days", filter: "Last 7 Days", currentFilter: $currentFilter)
                    FilterButton(title: "Last Month", filter: "Last Month", currentFilter: $currentFilter)
                    FilterButton(title: "Last Quarter", filter: "Last Quarter", currentFilter: $currentFilter)
                    FilterButton(title: "This Year", filter: "This Year", currentFilter: $currentFilter)
                    FilterButton(title: "All Time", filter: "All Time", currentFilter: $currentFilter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Charts grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    // Yearly Chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Yearly Overview")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if chartDataPreparer.viewModel.yearlyData.isEmpty {
                            Text("No data available")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 200)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        } else {
                            LineChartView(
                                data: chartDataPreparer.viewModel.yearlyData,
                                title: "Hours per Month"
                            )
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Weekly Chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly Overview")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if chartDataPreparer.viewModel.weeklyData.isEmpty {
                            Text("No data available")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 200)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        } else {
                            LineChartView(
                                data: chartDataPreparer.viewModel.weeklyData,
                                title: "Hours per Week"
                            )
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Pie Chart - Project Distribution
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Distribution")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if chartDataPreparer.viewModel.projectDistribution.isEmpty {
                            Text("No data available")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 200)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        } else {
                            PieChartView(
                                data: chartDataPreparer.viewModel.projectDistribution
                            )
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Bar Chart - Project Breakdown
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Time Breakdown")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if chartDataPreparer.viewModel.projectBreakdown.isEmpty {
                            Text("No data available")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 200)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        } else {
                            BarChartView(
                                data: chartDataPreparer.viewModel.projectBreakdown
                            )
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color(red: 0.10, green: 0.10, blue: 0.12))
        .onAppear {
            loadData()
        }
        .onChange(of: currentFilter) { _ in
            updateChartData()
        }
    }
    
    private func loadData() {
        sessions = SessionManager.shared.loadAllSessions()
        projects = ProjectManager.shared.loadProjects()
        updateChartData()
    }
    
    private func updateChartData() {
        chartDataPreparer.prepareChartData(sessions: sessions, projects: projects, filter: currentFilter)
    }
}

// MARK: - Filter Button
struct FilterButton: View {
    let title: String
    let filter: String
    @Binding var currentFilter: String
    
    var body: some View {
        Button(action: {
            currentFilter = filter
        }) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(currentFilter == filter ? Color.accentColor : Color.gray.opacity(0.3))
                .foregroundColor(currentFilter == filter ? .white : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Chart Views
struct LineChartView: View {
    let data: [TimeSeriesData]
    let title: String
    
    var body: some View {
        GeometryReader { geometry in
            let maxValue = data.map { $0.value }.max() ?? 1
            let width = geometry.size.width
            let height = geometry.size.height
            let pointSpacing = width / CGFloat(data.count - 1)
            
            ZStack {
                // Grid lines
                VStack(spacing: height / 4) {
                    Divider().opacity(0.3)
                    Divider().opacity(0.3)
                    Divider().opacity(0.3)
                    Divider().opacity(0.3)
                }
                
                // Line chart
                Path { path in
                    for (index, point) in data.enumerated() {
                        let x = CGFloat(index) * pointSpacing
                        let y = height - (CGFloat(point.value) / CGFloat(maxValue)) * height * 0.9 - height * 0.05
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.accentColor, lineWidth: 2)
                
                // Data points
                ForEach(data) { point in
                    let index = data.firstIndex(where: { $0.id == point.id }) ?? 0
                    let x = CGFloat(index) * pointSpacing
                    let y = height - (CGFloat(point.value) / CGFloat(maxValue)) * height * 0.9 - height * 0.05
                    
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }
                
                // Labels
                ForEach(data) { point in
                    let index = data.firstIndex(where: { $0.id == point.id }) ?? 0
                    let x = CGFloat(index) * pointSpacing
                    let y = height - (CGFloat(point.value) / CGFloat(maxValue)) * height * 0.9 - height * 0.05
                    
                    Text(String(format: "%.1f", point.value))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .position(x: x, y: y - 15)
                }
            }
        }
        .frame(height: 200)
    }
}

struct PieChartView: View {
    let data: [ProjectChartData]
    
    var body: some View {
        GeometryReader { geometry in
            let total = data.reduce(0) { $0 + $1.totalHours }
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 20
            
            ZStack {
                ForEach(data) { item in
                    let startAngle = sumPreviousPercentages(data: data, upTo: item.id)
                    let endAngle = startAngle + (item.totalHours / total) * 360
                    
                    PieSlice(startAngle: .degrees(startAngle), endAngle: .degrees(endAngle))
                        .fill(Color(hex: item.color))
                        .frame(width: radius * 2, height: radius * 2)
                }
                
                // Center circle (donut effect)
                Circle()
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.12))
                    .frame(width: radius, height: radius)
            }
        }
        .frame(height: 200)
    }
    
    private func sumPreviousPercentages(data: [ProjectChartData], upTo id: UUID) -> Double {
        var total: Double = 0
        for item in data {
            if item.id == id { break }
            total += (item.totalHours / data.reduce(0) { $0 + $1.totalHours }) * 360
        }
        return total
    }
}

struct BarChartView: View {
    let data: [TimeSeriesData]
    
    var body: some View {
        GeometryReader { geometry in
            let maxValue = data.map { $0.value }.max() ?? 1
            let width = geometry.size.width
            let height = geometry.size.height
            let barWidth = width / CGFloat(data.count) * 0.7
            let spacing = width / CGFloat(data.count) * 0.3
            
            ZStack {
                // Grid lines
                VStack(spacing: height / 4) {
                    Divider().opacity(0.3)
                    Divider().opacity(0.3)
                    Divider().opacity(0.3)
                    Divider().opacity(0.3)
                }
                
                // Bars
                ForEach(data) { item in
                    let index = data.firstIndex(where: { $0.id == item.id }) ?? 0
                    let barHeight = (CGFloat(item.value) / CGFloat(maxValue)) * height * 0.9
                    let x = CGFloat(index) * (barWidth + spacing) + spacing / 2
                    
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: barWidth, height: barHeight)
                        
                        Text(item.period)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: barWidth, alignment: .center)
                    }
                    .position(x: x + barWidth / 2, y: height / 2)
                }
            }
        }
        .frame(height: 200)
    }
}

// MARK: - Pie Slice Shape
struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        var path = Path()
        
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addLine(to: center)
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Preview
struct NativeSwiftChartsView_Previews: PreviewProvider {
    static var previews: some View {
        NativeSwiftChartsView()
    }
}
