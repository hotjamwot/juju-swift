import SwiftUI
import Charts
import Foundation

struct DashboardNativeSwiftChartsView: View {
    @StateObject private var chartDataPreparer = ChartDataPreparer()
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var projectsViewModel = ProjectsViewModel.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                HeroSectionView(
                    chartDataPreparer: chartDataPreparer,
                    totalHours: chartDataPreparer.weeklyTotalHours(),
                    totalAllTimeHours: chartDataPreparer.allTimeTotalHours(),
                    totalSessions: chartDataPreparer.allTimeTotalSessions()
                )
                
                SessionCalendarChartView(sessions: chartDataPreparer.currentWeekSessionsForCalendar())
                
                BubbleChartCardView(data: chartDataPreparer.yearlyProjectTotals())
                
                GroupedBarChartCardView(data: chartDataPreparer.monthlyProjectTotals())
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
                print("Projects after load:", projectsViewModel.projects.count)
                
                let _ = sessionManager.loadAllSessions()
                print("Sessions after load:", sessionManager.allSessions.count)
                
                // Force refresh the chart data
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
                
                // Create a new instance to force refresh
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
            // Create a new instance to force refresh
            chartDataPreparer.viewModel = ChartViewModel()
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
            // Create a new instance to force refresh
            chartDataPreparer.viewModel = ChartViewModel()
            chartDataPreparer.prepareAllTimeData(
                sessions: sessionManager.allSessions,
                projects: projectsViewModel.projects
            )
        }
    }
    
    // MARK: - Components
    
    struct FilterButton: View {
        let title: String
        let filter: ChartTimePeriod
        @Binding var selectedPeriod: ChartTimePeriod
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
            VStack(alignment: .leading, spacing: Theme.spacingMedium) {
                Text(title)
                    .font(Theme.Fonts.header)
                    .foregroundColor(Theme.Colors.textPrimary)
                content
            }
            .padding(Theme.spacingSmall)
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
}
    
    // MARK: - Preview
    struct DashboardNativeSwiftChartsView_Previews: PreviewProvider {
        static var previews: some View {
            DashboardNativeSwiftChartsView()
                .frame(width: 1200, height: 900)
                .preferredColorScheme(.dark)
        }
    }

