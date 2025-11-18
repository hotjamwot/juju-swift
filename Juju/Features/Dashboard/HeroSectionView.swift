import SwiftUI
import Charts

struct HeroSectionView: View {
    // MARK: - Properties
    @ObservedObject var chartDataPreparer: ChartDataPreparer

    let totalHours: Double

    var body: some View {
        VStack(spacing: Theme.spacingMedium) {
            // First Row: Two Columns
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let leftColumnWidth = totalWidth * 0.40
                let rightColumnWidth = totalWidth * 0.60

                HStack(spacing: Theme.spacingLarge) {
                    // Left Column: Logo and Text
                    VStack(alignment: .center, spacing: Theme.spacingSmall) {
                        // Juju Logo
                        Image("juju_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .shadow(radius: 1)

                        // Text Elements
                        VStack(alignment: .center, spacing: Theme.spacingExtraSmall) {
                            Text("You've spent")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.textPrimary)

                            Text(String(format: "%.1f", totalHours) + " hours")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Theme.Colors.accentColor, Theme.Colors.accentColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text("in the Juju this week!")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                    }
                    .frame(width: leftColumnWidth, alignment: .center)

                    // Right Column: Weekly Project Bubble Chart
                    WeeklyProjectBubbleChartView(
                        data: chartDataPreparer.weeklyProjectTotals()
                    )
                    .frame(width: rightColumnWidth, height: 350)
                }
                .frame(width: totalWidth)
            }
            .frame(height: 400)

            // Second Row: Full Width Session Calendar Chart
            SessionCalendarChartView(
                sessions: chartDataPreparer.currentWeekSessionsForCalendar()
            )
            .padding(Theme.spacingLarge)
            .frame(height: 350)
            .border(.clear, width: 0)

        }
        .padding(.horizontal, Theme.spacingLarge)
        .padding(.vertical, Theme.spacingExtraLarge)
        .background(Theme.Colors.surface.opacity(0.5))
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

// MARK: Preview
#Preview {
    return HeroSectionView_PreviewsContent()
        .frame(width: 1000, height: 800)
        .background(Color(NSColor.windowBackgroundColor))
        .padding()
}

struct HeroSectionView_PreviewsContent: View {
    @StateObject var chartDataPreparer = ChartDataPreparer()
    @StateObject var sessionManager = SessionManager.shared
    @StateObject var projectsViewModel = ProjectsViewModel.shared
    
    var body: some View {
        HeroSectionView(
            chartDataPreparer: chartDataPreparer,
            totalHours: chartDataPreparer.weeklyTotalHours()
        )
        .onAppear {
            // Load data just like DashboardNativeSwiftChartsView does
            Task {
                await projectsViewModel.loadProjects()
                await sessionManager.loadAllSessions()
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onChange(of: sessionManager.allSessions.count) { _ in
            // Update chart data when session data changes
            Task {
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onChange(of: projectsViewModel.projects.count) { _ in
            // Update chart data when project data changes
            Task {
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
    }
}
