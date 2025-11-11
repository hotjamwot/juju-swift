import SwiftUI
import Charts

// 1️⃣  Extension moved out of the struct
extension Date {
    var isInCurrentYear: Bool {
        let cal = Calendar.current
        return cal.component(.year, from: self) ==
               cal.component(.year, from: Date())
    }
}

struct DashboardNativeSwiftChartsView: View {
    // MARK: - State objects
    @StateObject private var chartDataPreparer = ChartDataPreparer()
    @StateObject private var sessionManager   = SessionManager.shared
    @StateObject private var projectsViewModel = ProjectsViewModel.shared

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                HeroSectionView(
                    chartDataPreparer: chartDataPreparer,
                    totalHours: chartDataPreparer.weeklyTotalHours() )

                VStack(spacing: Theme.spacingMedium) {
                    // Header for the container
                    Text("This Year")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    GeometryReader { geo in
                        HStack(spacing: Theme.spacingMedium) {
                            YearlyTotalBarChartView(
                                data: chartDataPreparer.yearlyProjectTotals()
                            )
                            .layoutPriority(3)
                            .frame(maxHeight: .infinity, alignment: .center)

                            VStack(alignment: .center, spacing: Theme.spacingMedium) {
                                SummaryMetricView(
                                    title: "Total Hours",
                                    value: String(format: "%.1f h", chartDataPreparer.yearlyTotalHours())
                                )
                                SummaryMetricView(
                                    title: "Total Sessions",
                                    value: "\(chartDataPreparer.yearlyTotalSessions())"
                                )
                                SummaryMetricView(
                                    title: "Average Duration",
                                    value: chartDataPreparer.yearlyAvgDurationString()
                                )
                                
                            }
                            .frame(width: 400)
                            .layoutPriority(1)
                            .frame(maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .frame(height: 300)
                }
                .padding(Theme.spacingLarge)
                .background(
                    Theme.Colors.surface
                )
                .cornerRadius(Theme.Design.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .stroke(Theme.Colors.divider, lineWidth: 1)
                )

                GeometryReader { geo in
                    WeeklyStackedBarChartView(
                        data: chartDataPreparer.weeklyStackedBarChartData()
                    )
                }
                .frame(height: 300)
                .padding(Theme.spacingMedium)
                .background(Theme.Colors.surface)
                .cornerRadius(Theme.Design.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .stroke(Theme.Colors.divider, lineWidth: 1)
                )

                StackedAreaChartCardView(
                    data: chartDataPreparer.monthlyProjectTotals()
                )
            }
            .padding(.vertical, Theme.spacingLarge)
            .padding(.horizontal, 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.background)
            .cornerRadius(Theme.Design.cornerRadius)
            
        }
        .padding(.top, 20)
        .padding(.bottom, 20)
        .padding(.trailing, 20)
        .background(Theme.Colors.background)
        
        .onAppear {
            Task {
                await projectsViewModel.loadProjects()
                await sessionManager.loadAllSessions()

                // Pull fresh data into the chart model
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
                // (Reset the viewModel if you ever need a clean slate)
                chartDataPreparer.viewModel = ChartViewModel()
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onChange(of: sessionManager.allSessions.count) { _ in
            chartDataPreparer.prepareAllTimeData(
                sessions: sessionManager.allSessions,
                projects: projectsViewModel.projects
            )
        }
        .onChange(of: projectsViewModel.projects.count) { _ in
            chartDataPreparer.prepareAllTimeData(
                sessions: sessionManager.allSessions,
                projects: projectsViewModel.projects
            )
        }
    }

    // MARK: - Components
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
}

struct DashboardNativeSwiftChartsView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardNativeSwiftChartsView()
            .frame(width: 1200, height: 1200)
            .preferredColorScheme(.dark)
    }
}
