import SwiftUI
import Charts

struct WeeklyStackedBarChartView: View {
    let data: [WeeklyStackedBarChartData]
    
    @State private var selectedWeek: WeeklyStackedBarChartData?
    @State private var hoveredWeek: Int?
    
    // Cache expensive computed properties
    private let monthBoundaries: [(month: Int, weekStart: Int, weekEnd: Int, label: String)] = [
        (1, 1, 4, "J"),   (2, 5, 8, "F"),   (3, 9, 13, "M"),  (4, 14, 17, "A"),
        (5, 18, 22, "M"), (6, 23, 26, "J"), (7, 27, 30, "J"), (8, 31, 35, "A"),
        (9, 36, 39, "S"), (10, 40, 43, "O"), (11, 44, 48, "N"), (12, 49, 52, "D")
    ]
    
    private let monthCenters: [Double] = [2.5, 6.5, 11, 15.5, 20, 24.5, 28.5, 33, 37.5, 41.5, 46, 50.5]
    
    private var hasData: Bool {
        !data.isEmpty && data.contains { !$0.projectData.isEmpty }
    }
    
    private var maxWeeklyHours: Double {
        data.map { $0.totalHours }.max() ?? 10.0
    }
    
    // Cache unique projects and colors for performance
    private let uniqueProjects: [String]
    private let projectColorMap: [String: Color]
    
    // Global project ordering based on total duration (descending)
    private let globalProjectOrder: [String]
    
    init(data: [WeeklyStackedBarChartData]) {
        self.data = data
        
        // Pre-compute expensive operations once
        var projectSet = Set<String>()
        var colorMap = [String: Color]()
        var projectTotals = [String: Double]()
        
        for weeklyData in data {
            for projectData in weeklyData.projectData {
                projectSet.insert(projectData.projectName)
                if colorMap[projectData.projectName] == nil {
                    colorMap[projectData.projectName] = Color(hex: projectData.projectColor)
                }
                // Calculate total duration for each project across all weeks
                projectTotals[projectData.projectName, default: 0] += projectData.hours
            }
        }
        
        self.uniqueProjects = Array(projectSet).sorted()
        self.projectColorMap = colorMap
        
        // Create global ordering by total duration (descending), then by name for consistency
        self.globalProjectOrder = projectTotals
            .sorted { 
                if $0.value == $1.value {
                    return $0.key < $1.key // Alphabetical fallback for equal durations
                }
                return $0.value > $1.value 
            }
            .map { $0.key }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if hasData {
                    createContentView(geometry: geometry)
                } else {
                    createEmptyStateView()
                }
            }
        }
        .frame(height: 280, alignment: .center)
    }
    
    // MARK: - Main Content View
    
    private func createContentView(geometry: GeometryProxy) -> some View {
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .fill(.clear)
                .frame(height: 280)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .stroke(Theme.Colors.foreground.opacity(0.1), lineWidth: 1)
                )
            
            // Chart container with proper padding
            VStack(spacing: 0) {
                Spacer(minLength: 10)
                
                Chart(data, id: \.week.weekNumber) { weeklyData in
                    // Create data in global project order for consistent stacking
                    let orderedProjectData = createOrderedProjectData(from: weeklyData.projectData)
                    
                    ForEach(orderedProjectData) { projectData in
                        BarMark(
                            x: .value("Week", weeklyData.week.weekNumber),
                            y: .value("Hours", projectData.hours),
                            width: .fixed(8)
                        )
                        .foregroundStyle(projectData.colorSwiftUI)
                        .opacity(hoveredWeek == nil || hoveredWeek == weeklyData.week.weekNumber ? 1.0 : 0.3)
                        .cornerRadius(8)
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(Color.clear)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom, values: monthCenters) { value in
                        if let centerWeek = value.as(Double.self),
                           let index = monthCenters.firstIndex(of: centerWeek) {
                            AxisValueLabel {
                                Text(monthBoundaries[index].label)
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        if let hours = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(hours))h")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                    }
                }
                .chartLegend(position: .bottom, alignment: .center) {
                    createLegendView()
                }
                .chartForegroundStyleScale(range: createColorRange())
                .chartYScale(domain: 0...maxWeeklyHours)
                .chartXScale(domain: 0...53)
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: 52)
                .padding(.horizontal, Theme.spacingMedium)
                .padding(.bottom, Theme.spacingMedium)
                
                Spacer(minLength: Theme.spacingMedium)
            }
            
            createMonthDividers(geometry: geometry)
            
            if let selectedWeek = selectedWeek {
                createTooltipView(for: selectedWeek, geometry: geometry)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func createMonthDividers(geometry: GeometryProxy) -> some View {
        return ForEach(monthBoundaries.dropFirst().indices, id: \.self) { index in
            let boundary = monthBoundaries.dropFirst()[index]
            let monthWidth = (geometry.size.width - 40) / 12
            let x = CGFloat(boundary.weekStart - 1) * (monthWidth / 4) + 20
            
            Rectangle()
                .fill(Theme.Colors.divider.opacity(0.4))
                .frame(width: 1, height: 200)
                .position(x: x, y: 125)
                .allowsHitTesting(false)
        }
    }
    
    // Helper method to create ordered project data using global ordering
    private func createOrderedProjectData(from projectData: [ProjectWeeklyData]) -> [ProjectWeeklyData] {
        return projectData.sorted { project1, project2 in
            // Get positions in global order
            guard let index1 = globalProjectOrder.firstIndex(of: project1.projectName),
                  let index2 = globalProjectOrder.firstIndex(of: project2.projectName) else {
                // Fallback to original order if not found
                return false
            }
            return index1 < index2
        }
    }
    
    private func createTooltipView(for weekData: WeeklyStackedBarChartData, geometry: GeometryProxy) -> some View {
        let tooltipWidth: CGFloat = 200
        let tooltipHeight: CGFloat = CGFloat(weekData.projectData.count * 25 + 60)
        
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.Colors.surface.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.Colors.divider, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Week \(weekData.week.weekNumber) - \(weekData.week.monthLabel)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Divider()
                    .background(Theme.Colors.divider)
                
                // Use global order in tooltip too for consistency
                let orderedProjectData = createOrderedProjectData(from: weekData.projectData)
                ForEach(orderedProjectData, id: \.id) { project in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(project.colorSwiftUI)
                            .frame(width: 12, height: 8)
                        
                        Text("\(project.projectEmoji) \(project.projectName)")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\(String(format: "%.1f", project.hours))h")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
            }
            .padding(Theme.spacingMedium)
        }
        .frame(width: tooltipWidth, height: tooltipHeight)
        .position(x: geometry.size.width - tooltipWidth - 20, y: 20)
        .transition(.scale.combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: selectedWeek != nil)
    }
    
    private func createLegendView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(globalProjectOrder, id: \.self) { projectName in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(projectColorMap[projectName] ?? Color.gray)
                            .frame(width: 8, height: 8)
                        
                        // Get emoji from first occurrence
                        if let firstProject = data.flatMap({ $0.projectData }).first(where: { $0.projectName == projectName }) {
                            Text("\(firstProject.projectEmoji) \(projectName)")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.spacingSmall)
        }
    }
    
    private func createColorRange() -> [Color] {
        globalProjectOrder.compactMap { projectName in
            projectColorMap[projectName]
        }
    }
    
    // MARK: - Empty State
    
    private func createEmptyStateView() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .fill(Theme.Colors.surface.opacity(0.5))
                .frame(height: 250)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .stroke(Theme.Colors.foreground.opacity(0.1), lineWidth: 1)
                )
            
            VStack(spacing: Theme.spacingMedium) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 24))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Text("No Weekly Data yet!")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Start tracking your productivity to see weekly project distribution")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            .padding(Theme.spacingExtraLarge)
        }
    }
}

struct WeeklyStackedBarChartView_Previews: PreviewProvider {
    static var previews: some View {
        // Simplified preview data for better performance
        WeeklyStackedBarChartView(data: [
            WeeklyStackedBarChartData(
                week: WeekOfYear(weekNumber: 1, year: 2025, month: 1, startDate: Date(), endDate: Date().addingTimeInterval(604800)),
                projectData: [
                    ProjectWeeklyData(projectName: "Work", projectColor: "#4E79A7", projectEmoji: "💼", hours: 8.5, weekId: 1),
                    ProjectWeeklyData(projectName: "Personal", projectColor: "#F28E2C", projectEmoji: "🏠", hours: 3.2, weekId: 1)
                ]
            ),
            WeeklyStackedBarChartData(
                week: WeekOfYear(weekNumber: 2, year: 2025, month: 1, startDate: Date().addingTimeInterval(604800), endDate: Date().addingTimeInterval(1209600)),
                projectData: [
                    ProjectWeeklyData(projectName: "Work", projectColor: "#4E79A7", projectEmoji: "💼", hours: 6.0, weekId: 2),
                    ProjectWeeklyData(projectName: "Learning", projectColor: "#E15759", projectEmoji: "📚", hours: 4.5, weekId: 2)
                ]
            ),
            WeeklyStackedBarChartData(
                week: WeekOfYear(weekNumber: 10, year: 2025, month: 3, startDate: Date().addingTimeInterval(604800 * 9), endDate: Date().addingTimeInterval(604800 * 10)),
                projectData: [
                    ProjectWeeklyData(projectName: "Work", projectColor: "#4E79A7", projectEmoji: "💼", hours: 9.0, weekId: 10),
                    ProjectWeeklyData(projectName: "Personal", projectColor: "#F28E2C", projectEmoji: "🏠", hours: 2.5, weekId: 10)
                ]
            ),
            WeeklyStackedBarChartData(
                week: WeekOfYear(weekNumber: 25, year: 2025, month: 6, startDate: Date().addingTimeInterval(604800 * 24), endDate: Date().addingTimeInterval(604800 * 25)),
                projectData: [
                    ProjectWeeklyData(projectName: "Work", projectColor: "#4E79A7", projectEmoji: "💼", hours: 7.0, weekId: 25),
                    ProjectWeeklyData(projectName: "Learning", projectColor: "#E15759", projectEmoji: "📚", hours: 5.0, weekId: 25),
                    ProjectWeeklyData(projectName: "Hobby", projectColor: "#59A14F", projectEmoji: "🎨", hours: 1.5, weekId: 25)
                ]
            ),
            WeeklyStackedBarChartData(
                week: WeekOfYear(weekNumber: 40, year: 2025, month: 10, startDate: Date().addingTimeInterval(604800 * 39), endDate: Date().addingTimeInterval(604800 * 40)),
                projectData: [
                    ProjectWeeklyData(projectName: "Work", projectColor: "#4E79A7", projectEmoji: "💼", hours: 8.0, weekId: 40),
                    ProjectWeeklyData(projectName: "Personal", projectColor: "#F28E2C", projectEmoji: "🏠", hours: 4.0, weekId: 40)
                ]
            )
        ])
        .frame(width: 1200, height: 280)
        .preferredColorScheme(.dark)
    }
}
