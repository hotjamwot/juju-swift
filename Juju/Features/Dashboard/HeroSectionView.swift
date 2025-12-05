import SwiftUI
import Charts

struct HeroSectionView: View {
    // MARK: - Properties
    @ObservedObject var chartDataPreparer: ChartDataPreparer
    @StateObject var editorialEngine: EditorialEngine
    @State private var headlineText: String = "Loading your creative story..."

    var body: some View {
        VStack(spacing: Theme.spacingMedium) {
            // First Row: Two Columns
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let leftColumnWidth = totalWidth * 0.40
                let rightColumnWidth = totalWidth * 0.60

                HStack(spacing: Theme.spacingLarge) {
                    // Left Column: Logo and Dynamic Narrative
                    VStack(alignment: .center, spacing: Theme.spacingSmall) {
                        // Juju Logo
                        Image("juju_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .shadow(radius: 1)

                        // Dynamic Narrative Headline
                        VStack(alignment: .center, spacing: Theme.spacingExtraSmall) {
                            Text(headlineText)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .padding(.horizontal, Theme.spacingLarge)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, Theme.spacingMedium)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .fill(Theme.Colors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                        .stroke(Theme.Colors.divider, lineWidth: 1)
                                )
                        )
                    }
                    .frame(width: leftColumnWidth, alignment: .center)

                    // Right Column: Weekly Activity Bubble Chart
                    WeeklyActivityBubbleChartView(
                        data: chartDataPreparer.weeklyActivityTotals()
                    )
                    .frame(width: rightColumnWidth, height: 250)
                }
                .frame(width: totalWidth)
            }
            .frame(height: 250)

            // Second Row: Full Width Session Calendar Chart
            SessionCalendarChartView(
                sessions: chartDataPreparer.currentWeekSessionsForCalendar()
            )
            .padding(Theme.spacingLarge)
            .frame(height: 450)
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
        .onAppear {
            // Generate initial headline
            editorialEngine.generateWeeklyHeadline()
            headlineText = editorialEngine.getCurrentHeadlineText()
        }
        .onChange(of: editorialEngine.currentHeadline) { _ in
            headlineText = editorialEngine.getCurrentHeadlineText()
        }
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
    @StateObject var editorialEngine = EditorialEngine()
    
    var body: some View {
        HeroSectionView(
            chartDataPreparer: chartDataPreparer,
            editorialEngine: editorialEngine
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
                editorialEngine.generateWeeklyHeadline()
            }
        }
        .onChange(of: sessionManager.allSessions.count) { _ in
            // Update chart data when session data changes
            Task {
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
                editorialEngine.generateWeeklyHeadline()
            }
        }
        .onChange(of: projectsViewModel.projects.count) { _ in
            // Update chart data when project data changes
            Task {
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
                editorialEngine.generateWeeklyHeadline()
            }
        }
    }
}
