import SwiftUI
import Charts
import Foundation

// MARK: – Time‑range filter

/// One of the three drop‑down options you already have.
enum TimePeriod: String, CaseIterable, Identifiable {
    case lastMonth   = "Last month"
    case last90Days  = "Last 90 days"
    case thisYear    = "This Year"

    var id: String { rawValue }          // Needed for ForEach

    /// Human‑friendly title (used in the button & header).
    var title: String { rawValue }

    /// How many days back from `Date()` this option covers.
    var daysAgo: Int {
        switch self {
        case .lastMonth:  return 30
        case .last90Days: return 90
        case .thisYear:   return 365
        }
    }

    /// Convenience: the `DateInterval` that ChartDataPreparer can use directly.
    var dateInterval: DateInterval {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -daysAgo, to: end)!
        return DateInterval(start: start, end: end)
    }
}

/// Modern native SwiftUI Charts dashboard
struct DashboardNativeSwiftChartsView: View {
    @StateObject private var chartDataPreparer = ChartDataPreparer()
    @State private var selectedPeriod: TimePeriod = .thisYear
    @State private var sessions: [SessionRecord] = []
    @State private var projects: [Project] = []
    @Namespace private var filterNamespace


    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header 
                HStack(spacing: 8) {
               ForEach(TimePeriod.allCases) { period in
        FilterButton(
            title: period.title,
            filter: period,
            selectedPeriod: $selectedPeriod
        )
    }
}

            .padding(.horizontal, Theme.spacingLarge)
            .padding(.vertical, Theme.spacingMedium)
            
            // MARK: Charts
            ScrollView {
                VStack(spacing: 20) {
                    // Row 1: Stacked Bar Chart (Daily)
                    EnhancedChartCard(
                        title: "Daily Time Distribution",
                        legendData: chartDataPreparer.viewModel.pieChartData
                    ) {
                        if chartDataPreparer.viewModel.dailyStackedData.isEmpty {
                            NoDataPlaceholder(minHeight: 200)
                        } else {
                            StackedBarChartView(data: chartDataPreparer.viewModel.dailyStackedData)
                        }
                    }
                    
                    // Row 2: Stacked Area Chart (Weekly)
                    EnhancedChartCard(
                        title: "Weekly Time Trends",
                        legendData: chartDataPreparer.viewModel.pieChartData
                    ) {
                        if chartDataPreparer.viewModel.weeklyStackedData.isEmpty {
                            NoDataPlaceholder(minHeight: 200)
                        } else {
                            // Adjust tick density based on Period to reduce clutter
                            StackedAreaChartView(
                                data: chartDataPreparer.viewModel.weeklyStackedData,
                                desiredTickCount: desiredTickCountForPeriod(selectedPeriod)
                            )
                        }
                    }
                    
                    // Row 3: Pie Chart and Project Bar Chart
                    HStack(spacing: 16) {
                        // Left: Pie Chart
                        EnhancedChartCard(
                            title: "Project Distribution",
                            legendData: chartDataPreparer.viewModel.pieChartData
                        ) {
                            if chartDataPreparer.viewModel.pieChartData.isEmpty {
                                NoDataPlaceholder(minHeight: 200)
                            } else {
                                PieChartView(data: chartDataPreparer.viewModel.pieChartData)
                            }
                        }
                        
                        // Right: Project Bar Chart
                        EnhancedChartCard(
                            title: "Project Hours Comparison",
                            legendData: chartDataPreparer.viewModel.pieChartData
                        ) {
                            if chartDataPreparer.viewModel.projectBarData.isEmpty {
                                NoDataPlaceholder(minHeight: 200)
                            } else {
                                ProjectBarChartView(data: chartDataPreparer.viewModel.projectBarData)
                            }
                        }
                    }
                    
                    // Summary Section
                    EnhancedChartCard(title: "Summary") {
                        VStack(spacing: 12) {
                            if !sessions.isEmpty {
                                SummaryCard(title: "Total Sessions",
                                            value: "\(sessions.count)",
                                            color: .blue)
                                
                                let totalHours = Double(sessions.reduce(0) { $0 + $1.durationMinutes }) / 60.0
                                SummaryCard(title: "Total Hours",
                                            value: String(format: "%.1f", totalHours),
                                            color: .green)
                                
                                if !projects.isEmpty {
                                    SummaryCard(title: "Active Projects",
                                                value: "\(projects.count)",
                                                color: .purple)
                                }
                            } else {
                                NoDataPlaceholder(minHeight: 100)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.spacingLarge)
                .padding(.bottom, Theme.spacingLarge)
            }
        }
        .background(Color(red: 0.10, green: 0.10, blue: 0.12))
        .onAppear(perform: loadData)
        .onChange(of: selectedPeriod) { newPeriod in
            // Smoothly animate chart transitions when filter changes
            withAnimation(.easeInOut(duration: 0.22)) {
                updateChartData()
                print("[Dashboard] Updating chart for period: \(selectedPeriod.title)")
            }
        }
    }
    
    private func loadData() {
        sessions = SessionManager.shared.loadAllSessions()
        projects = ProjectManager.shared.loadProjects()
        updateChartData()
    }
    
    private func updateChartData() {
        chartDataPreparer.prepareData(sessions: sessions, projects: projects, filter: selectedPeriod)
    }

    // Choose reasonable axis tick counts per filter window
    private func desiredTickCountForPeriod(_ period: TimePeriod) -> Int {
    switch period {
    case .lastMonth:
        return 6        // about every 5 days
    case .last90Days:
        return 8        // weekly‑ish
    case .thisYear:
        return 6        // roughly bi‑monthly
    }
}

}

// MARK: - Components

struct FilterButton: View {
    let title: String
    let filter: TimePeriod
    @Binding var selectedPeriod: TimePeriod
    
    var body: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.18)) { selectedPeriod = filter } }) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, Theme.spacingSmall)
                .padding(.vertical, Theme.spacingExtraSmall)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .fill(Color.gray.opacity(0.25))
                        if selectedPeriod == filter {
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .fill(Color.accentColor.opacity(0.9))
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                )
                .foregroundColor(selectedPeriod == filter ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// Simple wrapper for consistent chart card styling
struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            content
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(Theme.Design.cornerRadius)
    }
}

struct NoDataPlaceholder: View {
    var minHeight: CGFloat = 200
    var body: some View {
        Text("No data available")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(Theme.Design.cornerRadius)
    }
}

// MARK: - Charts using Apple Charts framework

struct LineChartView: View {
    let data: [TimeSeriesData]
    
    var body: some View {
        Chart(data) { item in
            LineMark(
                x: .value("Period", item.period),
                y: .value("Value", item.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.accentColor.gradient)
            
            PointMark(
                x: .value("Period", item.period),
                y: .value("Value", item.value)
            )
            .foregroundStyle(.white)
        }
        .frame(height: 200)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6))
        }
    }
}

struct BarChartView: View {
    let data: [TimeSeriesData]
    
    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Period", item.period),
                y: .value("Value", item.value)
            )
            .foregroundStyle(Color.accentColor.gradient)
        }
        .frame(height: 200)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6))
        }
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.spacingMedium)
        .padding(.vertical, Theme.spacingSmall)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(Theme.Design.cornerRadius)
    }
}

// MARK: - Preview
struct DashboardNativeSwiftChartsView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardNativeSwiftChartsView()
            .frame(width: 1200, height: 800)
            .preferredColorScheme(.dark)
    }
}
