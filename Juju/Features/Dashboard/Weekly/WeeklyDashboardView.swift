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
    // MARK: - State objects
    @StateObject private var chartDataPreparer = ChartDataPreparer()
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var projectsViewModel = ProjectsViewModel.shared
    @StateObject private var editorialEngine = EditorialEngine()
    
    // MARK: - Loading state
    @State private var isLoading = false
    
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
                
                // Main content
                VStack(spacing: 0) {
                    // Sticky Active Session Bar (always visible at top)
                    if sessionManager.activeSession != nil {
                        ActiveSessionStatusView(sessionManager: sessionManager)
                            .padding(.horizontal, Theme.spacingLarge)
                            .padding(.top, Theme.spacingLarge)
                            .padding(.bottom, Theme.spacingSmall)
                            .background(Theme.Colors.background)
                            .zIndex(1) // Ensure it stays above content
                    }
                    
                    // Scrollable content below - NOW ONLY HERO SECTION
                    ScrollView {
                        VStack(spacing: 32) {
                            // Hero Section (no longer includes active session)
                            HeroSectionView(
                                chartDataPreparer: chartDataPreparer,
                                editorialEngine: editorialEngine
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, Theme.spacingLarge)
                        .padding(.horizontal, Theme.spacingLarge)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.background)
                        .cornerRadius(Theme.Design.cornerRadius)
                    }
                }
                .padding(.top, 20)
                .padding(.trailing, 20)
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
                    }
                }
            }
            // Event-driven reload when session ends
            .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { _ in
                Task {
                    await MainActor.run {
                        Task {
                            await sessionManager.loadRecentSessions(limit: 40)
                        }
                        chartDataPreparer.prepareWeeklyData(
                            sessions: sessionManager.allSessions,
                            projects: projectsViewModel.projects
                        )
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
        WeeklyDashboardView()
            .frame(width: 1200, height: 1200)
            .preferredColorScheme(.dark)
    }
}
