import SwiftUI

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
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
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
