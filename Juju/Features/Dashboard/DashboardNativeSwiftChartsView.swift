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
    
    // Mock data for project bubbles
    let mockBubbles = [
        ProjectChartData(projectName: "Film", color: "#FFA500", totalHours: 6.2, percentage: 57.4),
        ProjectChartData(projectName: "Writing", color: "#800080", totalHours: 3.8, percentage: 35.0),
        ProjectChartData(projectName: "Admin", color: "#0000FF", totalHours: 2.1, percentage: 19.2)
    ]


    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header 
                HStack(spacing: 8) {
               ForEach(TimePeriod.allCases) { period in
        FilterButton(
            title: period.title,
            filter: period,
            selectedPeriod: $selectedPeriod
        ) {
            updateChartData(filter: period)
        }
    }
}

            .padding(.horizontal, Theme.spacingLarge)
            .padding(.vertical, Theme.spacingMedium)
            
            // MARK: Hero Section
            HeroSectionView(
                totalHours: 12.1,
                projectBubbles: mockBubbles,
                totalAllTimeHours: 108.3,
                totalSessions: 245
            )
            
            // MARK: Summary Row
            HStack(spacing: Theme.spacingLarge) {
                SummaryCard(title: "Total Sessions", value: "\(sessions.count)", color: .blue, icon: Image(systemName: "clock"))
                SummaryCard(title: "Total Hours", value: String(format: "%.1f", calculateTotalHours()), color: .green, icon: Image(systemName: "hourglass"))
                SummaryCard(title: "Active Projects", value: "\(projects.count)", color: .purple, icon: Image(systemName: "folder"))
            }
            .padding(.horizontal, Theme.spacingLarge)
            
            // MARK: Charts
            ScrollView {
                VStack(spacing: 20) {
                    // Row 1: Stacked Bar Chart (Daily)
                    EnhancedChartCard(
                        title: nil,
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
                        title: nil,
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
                            title: nil,
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
                            title: nil,
                            legendData: chartDataPreparer.viewModel.pieChartData
                        ) {
                            if chartDataPreparer.viewModel.projectBarData.isEmpty {
                                NoDataPlaceholder(minHeight: 200)
                            } else {
                                ProjectBarChartView(data: chartDataPreparer.viewModel.projectBarData)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.spacingLarge)
                .padding(.bottom, Theme.spacingLarge)
            }
        }
        .background(Theme.Colors.background)
        .onAppear(perform: loadData)
        .onChange(of: selectedPeriod) { newPeriod in
            print("[Dashboard] Selected period changed to: \(newPeriod.title)")
        }
    }
    
    private func calculateTotalHours() -> Double {
        return Double(sessions.reduce(0) { $0 + $1.durationMinutes }) / 60.0
    }
    
    private func loadData() {
        sessions = SessionManager.shared.loadAllSessions()
        projects = ProjectManager.shared.loadProjects()
        updateChartData(filter: selectedPeriod)
    }
    
    private func updateChartData(filter: TimePeriod) {
        chartDataPreparer.prepareData(sessions: sessions, projects: projects, filter: filter)
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
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: Theme.Design.animationDuration)) {
                selectedPeriod = filter
                onSelect()
            }
        }) {
            Text(title)
                .font(Theme.Fonts.caption)
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
                .foregroundColor(selectedPeriod == filter ? Theme.Colors.textPrimary :
                Theme.Colors.textSecondary)
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
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textPrimary)
            content
        }
        .padding(Theme.spacingMedium)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
    }
}

struct NoDataPlaceholder: View {
    var minHeight: CGFloat = 200
    var body: some View {
        Text("No data available")
            .foregroundColor(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(Theme.Colors.surface.opacity(0.2))
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
    let icon: Image?
    
    init(title: String, value: String, color: Color, icon: Image? = nil) {
        self.title = title
        self.value = value
        self.color = color
        self.icon = icon
    }
    
    var body: some View {
        HStack {
            if let icon = icon {
                icon
                    .foregroundColor(color)
                    .frame(width: 16, height: 16)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Text(value)
                    .font(Theme.Fonts.header)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.spacingMedium)
        .padding(.vertical, Theme.spacingSmall)
        .background(Theme.Colors.surface.opacity(0.2))
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
