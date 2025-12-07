import SwiftUI
import Charts

struct HeroSectionView: View {
    // MARK: - Properties
    @ObservedObject var chartDataPreparer: ChartDataPreparer
    @StateObject var editorialEngine: EditorialEngine
    @State private var headlineText: String = "Loading your creative story..."

    var body: some View {
        VStack(spacing: Theme.spacingExtraLarge) {
            // First Row: Two Columns
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let leftColumnWidth = totalWidth * 0.40
                let rightColumnWidth = totalWidth * 0.60

                HStack(spacing: Theme.spacingLarge) {
                    // Left Column: Editorial Information
                    VStack(alignment: .center, spacing: Theme.spacingMedium) {
                        // Three-line editorial information with accent colors
                        VStack(alignment: .center, spacing: Theme.spacingSmall) {
                            // Line 1: Total logged time
                            Text("This week you logged")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text(editorialEngine.currentHeadline?.formattedHours ?? "0h 0m")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.accentColor)
                            
                            // Space between sections
                            Spacer().frame(height: Theme.spacingMedium)
                            
                            // Line 2: Focus activity
                            Text("You did a lot of")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.Colors.textPrimary)
                            if let topActivity = editorialEngine.currentHeadline?.topActivity {
                                HStack(spacing: Theme.spacingExtraSmall) {
                                    Text(topActivity.emoji)
                                        .font(.system(size: 18, weight: .medium, design: .rounded))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Text(topActivity.name)
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.Colors.accentColor)
                                }
                            } else {
                                Text("Uncategorized")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.Colors.accentColor)
                            }
                            
                            // Space between sections
                            Spacer().frame(height: Theme.spacingMedium)
                            
                            // Line 3: Milestone (conditional)
                            if let milestone = editorialEngine.currentHeadline?.milestone {
                                Text("And congrats! You")
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Text(milestone.text)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.Colors.accentColor)
                            }
                        }
                        .padding(.horizontal, Theme.spacingLarge)
                        .padding(.vertical, Theme.spacingMedium)
                    }
                    .frame(width: leftColumnWidth, alignment: .center)

                    // Right Column: Weekly Activity Bubble Chart
                    WeeklyActivityBubbleChartView(
                        data: chartDataPreparer.weeklyActivityTotals()
                    )
                    .padding(Theme.spacingExtraLarge)
                    .frame(width: rightColumnWidth, height: 270)
                }
                .frame(width: totalWidth)
            }
            .frame(height: 270)

            // Second Row: Full Width Session Calendar Chart
            SessionCalendarChartView(
                sessions: chartDataPreparer.currentWeekSessionsForCalendar()
            )
            .padding(Theme.spacingExtraLarge)
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
        .background(Theme.Colors.background)
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
