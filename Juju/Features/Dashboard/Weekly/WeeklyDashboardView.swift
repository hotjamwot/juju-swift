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

struct WeeklyDashboardView: View {
    // MARK: - State objects (passed from DashboardRootView)
    @ObservedObject var chartDataPreparer: ChartDataPreparer
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var projectsViewModel: ProjectsViewModel
    @ObservedObject var editorialEngine: EditorialEngine
    
    // MARK: - Loading state
    @State private var isLoading = false
    
    // MARK: - Responsive layout helpers
    private func editorialViewWidth(availableWidth: CGFloat) -> CGFloat {
        // Account for sidebar (50px) and DashboardRootView padding (Theme.spacingLarge * 2)
        let sidebarWidth: CGFloat = 50
        let dashboardPadding: CGFloat = Theme.spacingLarge * 2
        let effectiveWidth = availableWidth - sidebarWidth - dashboardPadding
        
        // Editorial view takes 35-40% of effective width, minimum 300px, maximum 500px
        let minWidth: CGFloat = 300
        let maxWidth: CGFloat = 500
        let preferredWidth = effectiveWidth * 0.38
        return max(minWidth, min(maxWidth, preferredWidth))
    }
    
    private func bubbleChartWidth(availableWidth: CGFloat) -> CGFloat {
        // Account for sidebar (50px) and DashboardRootView padding (Theme.spacingLarge * 2)
        let sidebarWidth: CGFloat = 50
        let dashboardPadding: CGFloat = Theme.spacingLarge * 2
        let effectiveWidth = availableWidth - sidebarWidth - dashboardPadding
        
        // Bubble chart takes remaining space after editorial view
        let editorialWidth = editorialViewWidth(availableWidth: availableWidth)
        return max(300, effectiveWidth - editorialWidth - Theme.spacingLarge)
    }
    
    private func calendarChartHeight(availableHeight: CGFloat) -> CGFloat {
        // Calendar chart takes 45-55% of available height, minimum 350px, maximum 500px
        let minHeight: CGFloat = 350
        let maxHeight: CGFloat = 500
        let preferredHeight = availableHeight * 0.5
        return max(minHeight, min(maxHeight, preferredHeight))
    }
    
    // MARK: - Component Views
    // Note: Removed thisYearSection, weeklyStackedBarChart, and stackedAreaChart
    // These are now moved to YearlyDashboardView for better separation of concerns

    // MARK - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Floating navigation button (always visible in center-right, even closer to edge)
                NavigationButton()
                    .position(x: geometry.size.width - 16, y: geometry.size.height / 2)
                    .zIndex(2)
                
                // Main content with tidy, balanced layout
                VStack(spacing: Theme.spacingMedium) { // Reduced gap between top and bottom views
                    // Sticky Active Session Bar (always visible at top)
                    if sessionManager.activeSession != nil {
                        ActiveSessionStatusView(sessionManager: sessionManager)
                            .padding(.horizontal, Theme.spacingLarge)
                            .padding(.top, Theme.spacingLarge)
                            .padding(.bottom, Theme.spacingSmall)
                            .background(Theme.Colors.background)
                            .zIndex(1) // Ensure it stays above content
                    }
                    
                    // Top Row: Editorial View and Activity Bubble Chart
                    HStack(spacing: Theme.spacingLarge) {
                        // Left Column: Weekly Editorial View (already has built-in surface pane)
                        WeeklyEditorialView(
                            editorialEngine: editorialEngine
                        )
                        .frame(width: editorialViewWidth(availableWidth: geometry.size.width))
                        .frame(maxHeight: .infinity) // Allow flexible height
                        
                        // Right Column: Weekly Activity Bubble Chart (self-contained with surface pane)
                        // Use flexible height to match editorial view
                        WeeklyActivityBubbleChartView(
                            data: chartDataPreparer.weeklyActivityTotals()
                        )
                        .frame(width: bubbleChartWidth(availableWidth: geometry.size.width))
                        .frame(maxHeight: .infinity) // Allow flexible height
                    }
                    .frame(maxHeight: geometry.size.height * 0.45) // Allocate 45% of height to top row
                    
                    // Second Row: Session Calendar Chart (self-contained with surface pane)
                    SessionCalendarChartView(
                        sessions: chartDataPreparer.currentWeekSessionsForCalendar()
                    )
                    .frame(maxHeight: geometry.size.height * 0.45) // Allocate 45% of height to bottom row
                }
                .padding(Theme.spacingLarge)
                .background(Theme.Colors.background)
            }
            
            // Loading overlay
            .overlay(
                Group {
                    if isLoading {
                        Rectangle()
                            .fill(Theme.Colors.background.opacity(0.8))
                            .overlay(
                                VStack(spacing: 20) {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                    Text("Loading dashboard...")
                                        .foregroundColor(Theme.Colors.textPrimary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Theme.Colors.surface)
                                .cornerRadius(Theme.Design.cornerRadius)
                            )
                    }
                }
            )
            
            .onAppear {
                Task {
                    await projectsViewModel.loadProjects()
                    isLoading = true
                    
                    // Load all sessions for dashboard charts (will be filtered to weekly in prepareWeeklyData)
                    await MainActor.run {
                        Task {
                            await sessionManager.loadAllSessions()
                        }
                    }
                    
                    // Prepare WEEKLY data for initial display (optimized for performance)
                    chartDataPreparer.prepareWeeklyData(
                        sessions: sessionManager.allSessions,
                        projects: projectsViewModel.projects
                    )
                    
                    // Generate initial editorial headline
                    editorialEngine.generateWeeklyHeadline()
                    
                    isLoading = false
                }
            }
            // Event-driven reload when session starts
            .onReceive(NotificationCenter.default.publisher(for: .sessionDidStart)) { _ in
                Task {
                    await MainActor.run {
                        chartDataPreparer.prepareWeeklyData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
                        editorialEngine.generateWeeklyHeadline()
                    }
                }
            }
            // Event-driven reload when session ends
            .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { _ in
                Task {
                    await MainActor.run {
                        // Load current week sessions for weekly dashboard performance
                        Task {
                            await sessionManager.loadCurrentWeekSessions()
                        }
                        chartDataPreparer.prepareWeeklyData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
                        editorialEngine.generateWeeklyHeadline()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .projectsDidChange)) { _ in
                Task {
                    await MainActor.run {
                        chartDataPreparer.prepareWeeklyData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
                        editorialEngine.generateWeeklyHeadline()
                    }
                }
            }
            .onChange(of: sessionManager.allSessions.count) { _ in
                // Only prepare data if not loading to prevent conflicts
                guard !isLoading else { return }
                Task {
                    await MainActor.run {
                        chartDataPreparer.prepareWeeklyData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
                        editorialEngine.generateWeeklyHeadline()
                    }
                }
            }
            .onChange(of: projectsViewModel.projects.count) { _ in
                // Only prepare data if not loading to prevent conflicts
                guard !isLoading else { return }
                Task {
                    await MainActor.run {
                        chartDataPreparer.prepareWeeklyData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
                        editorialEngine.generateWeeklyHeadline()
                    }
                }
            }
        }
    }

    // MARK: - Components
    struct NoDataPlaceholder: View {
        var minHeight: CGFloat = 200
        var body: some View {
            Text("No data available")
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(Theme.Colors.background.opacity(0.2))
                .cornerRadius(Theme.Design.cornerRadius)
        }
    }
}

// MARK: - Navigation Button Component

/// Floating navigation button for switching between weekly and yearly views
/// This button is embedded directly in WeeklyDashboardView for better encapsulation
struct NavigationButton: View {
    @StateObject private var sessionManager = SessionManager.shared
    
    var body: some View {
        Button(action: {
            // This will be handled by parent DashboardRootView through state management
            // For now, we'll use a notification to trigger the navigation
            NotificationCenter.default.post(name: .switchToYearlyView, object: nil)
        }) {
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
        }
        .buttonStyle(.navigation) // Use shared NavigationButtonStyle
        .help("Switch to Yearly Dashboard")
    }
}

// MARK: - Preview

struct WeeklyDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        WeeklyDashboardView(
            chartDataPreparer: ChartDataPreparer(),
            sessionManager: SessionManager.shared,
            projectsViewModel: ProjectsViewModel.shared,
            editorialEngine: EditorialEngine()
        )
            .frame(width: 1200, height: 1200)
            .preferredColorScheme(.dark)
    }
}
