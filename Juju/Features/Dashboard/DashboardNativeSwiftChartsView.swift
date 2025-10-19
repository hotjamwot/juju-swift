import SwiftUI
import Charts

/// Modern native SwiftUI Charts dashboard
struct DashboardNativeSwiftChartsView: View {
    @StateObject private var chartDataPreparer = ChartDataPreparer()
    @State private var currentFilter = "This Year"
    @State private var sessions: [SessionRecord] = []
    @State private var projects: [Project] = []
    @Namespace private var filterNamespace
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
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
                
                HStack(spacing: 8) {
                    FilterButton(title: "Last month", filter: "Last month", currentFilter: $currentFilter)
                    FilterButton(title: "Last 90 days", filter: "Last 90 days", currentFilter: $currentFilter)
                    FilterButton(title: "This Year", filter: "This Year", currentFilter: $currentFilter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
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
                            // Adjust tick density based on filter to reduce clutter
                            StackedAreaChartView(
                                data: chartDataPreparer.viewModel.weeklyStackedData,
                                desiredTickCount: desiredTickCountForFilter(currentFilter)
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
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color(red: 0.10, green: 0.10, blue: 0.12))
        .onAppear(perform: loadData)
        .onChange(of: currentFilter) { _ in
            // Smoothly animate chart transitions when filter changes
            withAnimation(.easeInOut(duration: 0.22)) {
                updateChartData()
            }
        }
    }
    
    private func loadData() {
        sessions = SessionManager.shared.loadAllSessions()
        projects = ProjectManager.shared.loadProjects()
        updateChartData()
    }
    
    private func updateChartData() {
        chartDataPreparer.prepareData(sessions: sessions, projects: projects, filter: currentFilter)
    }

    // Choose reasonable axis tick counts per filter window
    private func desiredTickCountForFilter(_ filter: String) -> Int {
        switch filter {
        case "Last month":
            return 6 // about every 5 days
        case "Last 90 days":
            return 8 // weekly-ish
        case "This Year":
            return 6 // roughly bi-monthly
        default:
            return 6
        }
    }
}

// MARK: - Components

struct FilterButton: View {
    let title: String
    let filter: String
    @Binding var currentFilter: String
    
    var body: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.18)) { currentFilter = filter } }) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.25))
                        if currentFilter == filter {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.9))
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                )
                .foregroundColor(currentFilter == filter ? .white : .primary)
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
        .cornerRadius(12)
    }
}

struct NoDataPlaceholder: View {
    var minHeight: CGFloat = 200
    var body: some View {
        Text("No data available")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
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
