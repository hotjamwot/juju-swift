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
    
    init(data: [WeeklyStackedBarChartData]) {
        self.data = data
        
        // Pre-compute expensive operations once
        var projectSet = Set<String>()
        var colorMap = [String: Color]()
        
        for weeklyData in data {
            for projectData in weeklyData.projectData {
                projectSet.insert(projectData.projectName)
                if colorMap[projectData.projectName] == nil {
                    colorMap[projectData.projectName] = Color(hex: projectData.projectColor)
                }
            }
        }
        
        self.uniqueProjects = Array(projectSet).sorted()
        self.projectColorMap = colorMap
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
                .fill(Theme.Colors.surface)
                .frame(height: 250)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .stroke(Theme.Colors.foreground.opacity(0.1), lineWidth: 1)
                )
            
            // Chart container with proper padding
            VStack(spacing: 0) {
                Spacer(minLength: 10)
                
                Chart(data, id: \.week.weekNumber) { weeklyData in
                    ForEach(weeklyData.projectData) { projectData in
                        BarMark(
                            x: .value("Week", weeklyData.week.weekNumber),
                            y: .value("Hours", projectData.hours),
                            width: .fixed(8)
                        )
                        .foregroundStyle(projectData.colorSwiftUI)
                        .opacity(hoveredWeek == nil || hoveredWeek == weeklyData.week.weekNumber ? 1.0 : 0.3)
                        .cornerRadius(2)
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom, values: monthCenters) { value in
                        if let centerWeek = value.as(Double.self),
                           let index = monthCenters.firstIndex(of: centerWeek) {
                            AxisValueLabel {
                                Text(monthBoundaries[index].label)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.Colors.textPrimary)
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
                .chartXScale(domain: 1...52)
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: 52)
                .padding(.horizontal, Theme.spacingMedium)
                .padding(.bottom, 30)
                
                Spacer(minLength: 0)
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
    
    private func createTooltipView(for weekData: WeeklyStackedBarChartData, geometry: GeometryProxy) -> some View {
        let tooltipWidth: CGFloat = 200
        let tooltipHeight: CGFloat = CGFloat(weekData.projectData.count * 25 + 60)
        
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.Colors.surface)
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
                
                ForEach(weekData.projectData.sorted(by: { $0.hours > $1.hours }), id: \.id) { project in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(project.colorSwiftUI)
                            .frame(width: 8, height: 8)
                        
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
            .padding(12)
        }
        .frame(width: tooltipWidth, height: tooltipHeight)
        .position(x: geometry.size.width - tooltipWidth - 20, y: 20)
        .transition(.scale.combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: selectedWeek != nil)
    }
    
    private func createLegendView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(uniqueProjects, id: \.self) { projectName in
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
        uniqueProjects.compactMap { projectName in
            projectColorMap[projectName]
        }
    }
    
    // MARK: - Empty State
    
    private func createEmptyStateView() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .fill(Theme.Colors.surface)
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
