import SwiftUI
import Foundation

// MARK: - Date Filter Enum
public enum DateFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case clear = "Clear"
    
    public var id: String { rawValue }
    public var title: String { rawValue }
}

// MARK: - Sessions View

struct GroupedSession: Identifiable {
    let id      = UUID()
    let date    : Date
    let sessions: [SessionRecord]
}

struct GroupedSessionView: View {
    let group: GroupedSession
    let projects: [Project]
    let activityTypes: [ActivityType]
    let onDelete: (SessionRecord) -> Void
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let sidebarState: SidebarStateManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date Header with expand/collapse
            let isExpandedBinding = Binding(
                get: { isExpanded },
                set: { _ in onToggleExpand() }
            )
            
            DayHeaderView(
                date: group.date,
                sessionCount: group.sessions.count,
                isExpanded: isExpandedBinding
            )
            
            // Session rows (only show if expanded)
            if isExpanded {
                VStack(spacing: Theme.spacingSmall) {
                    ForEach(group.sessions) { session in
                        SessionsRowView(
                            session: .constant(session),
                            projects: projects,
                            activityTypes: activityTypes,
                            sidebarState: sidebarState,
                            onDelete: onDelete
                        )
                    }
                }
                .padding(.horizontal, Theme.spacingMedium)
                .padding(.vertical, Theme.spacingSmall)
            }
        }
    }
}

/// Main view for displaying and managing sessions in a grouped grid
public struct SessionsView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var projectsViewModel = ProjectsViewModel()
    @StateObject private var chartDataPreparer = ChartDataPreparer()
    @StateObject private var activityTypesViewModel = ActivityTypesViewModel()
    @EnvironmentObject private var sidebarState: SidebarStateManager

    // MARK: - State Properties
    
    // Filter and export state (now managed by the modular component)
    @StateObject private var filterExportState = FilterExportState()
    
    // Editing state
    @State private var showingDeleteAlert = false
    @State private var toDelete: SessionRecord? = nil
    
    // UI state
    @State private var isLoading = false // This can be used for initial load if needed
    @State private var showingExportAlert = false
    @State private var exportMessage = ""
    
    // Current week sessions only - no pagination needed
    @State private var currentWeekSessions: [GroupedSession] = []
    
    // Track expansion state for each group - expanded by default
    @State private var expandedGroups: Set<UUID> = Set()
    
    // Track which session is being edited
    @State private var editingSessionID: String? = nil
    
    // Track last update time to force UI refresh
    @State private var lastRefreshTime = Date()

    // MARK: - Computed Properties
    
    /// The source of truth for all filtering and sorting.
    private var fullyFilteredSessions: [SessionRecord] {
        // Start with current week sessions
        var sessions = getCurrentWeekSessions()
        
        // Apply project filter if not "All"
        sessions = applyProjectFilter(to: sessions)
        
        // Sort by start date time (most recent first)
        sessions = sortSessionsByDate(sessions)
        
        return sessions
    }
    
    /// Apply project filter to sessions
    private func applyProjectFilter(to sessions: [SessionRecord]) -> [SessionRecord] {
        guard filterExportState.projectFilter != "All" else {
            return sessions
        }
        
        return sessions.filter { $0.projectName == filterExportState.projectFilter }
    }
    
    /// Sort sessions by start date time (most recent first)
    private func sortSessionsByDate(_ sessions: [SessionRecord]) -> [SessionRecord] {
        return sessions.sorted { session1, session2 in
            let date1 = session1.startDateTime ?? Date.distantPast
            let date2 = session2.startDateTime ?? Date.distantPast
            return date1 > date2
        }
    }
    
    /// Count of sessions in currentWeekSessions
    private var currentSessionCount: Int {
        var count = 0
        for group in currentWeekSessions {
            count += group.sessions.count
        }
        return count
    }
    
    /// Create grouped session views for display
    private var groupedSessionViews: some View {
        ForEach(currentWeekSessions, id: \.id) { group in
                GroupedSessionView(
                    group: group,
                    projects: projectsViewModel.projects,
                    activityTypes: activityTypesViewModel.activeActivityTypes,
                    onDelete: { session in
                        toDelete = session
                        showingDeleteAlert = true
                    },
                    isExpanded: expandedGroups.contains(group.id),
                    onToggleExpand: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedGroups.contains(group.id) {
                                expandedGroups.remove(group.id)
                            } else {
                                expandedGroups.insert(group.id)
                            }
                        }
                    },
                    sidebarState: sidebarState
                )
        }
    }
    
    /// Computed property that automatically updates when sessionManager.allSessions changes
    private var groupedCurrentWeekSessions: [GroupedSession] {
        let sessions = getCurrentWeekSessions()
        return groupSessionsByDate(sessions)
    }
    

    
    // MARK: - Body
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sessions")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, Theme.spacingLarge)
            .padding(.horizontal, Theme.spacingLarge)
            .background(Theme.Colors.background)

            // Content Area
            ZStack {
                // --- Main Content Area ---
                if projectsViewModel.isLoading {
                    // Projects are loading
                    VStack {
                        Spacer()
                        ProgressView("Loading projects...")
                            .scaleEffect(1.5)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if currentWeekSessions.isEmpty {
                    if isLoading {
                        // Loading indicator
                        VStack {
                            Spacer()
                            ProgressView("Loading sessions...")
                                .scaleEffect(1.5)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Empty state view
                        VStack {
                            Spacer()
                            Text("No sessions found for the selected filters.")
                                .foregroundColor(Theme.Colors.textSecondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    // Grid View
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Theme.spacingLarge) {
                            groupedSessionViews
                        }
                        .padding(.vertical, Theme.spacingMedium)
                    }
                    .scrollContentBackground(.hidden)
                }
                
                // --- Floating Filter Toggle Button ---
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FilterExportControls(
                            state: filterExportState,
                            projects: projectsViewModel.projects,
                            filteredSessionsCount: currentSessionCount,
            onDateFilterChange: handleDateFilterSelection,
            onCustomDateRangeChange: handleCustomDateRangeChange,
            onProjectFilterChange: { _ in },
            onExport: { format in
                exportSessions(format: format.fileExtension)
            },
                            onInvoicePreviewToggle: {
                                // Future invoice preview functionality
                                print("Invoice preview requested")
                            },
                            onApplyFilters: applyFilters
                        )
                        .padding(.trailing, Theme.spacingLarge)
                        .padding(.bottom, Theme.spacingLarge)
                    }
                }
            }
        }
        .background(Theme.Colors.background)
        .task { 
            await projectsViewModel.loadProjects()
            activityTypesViewModel.loadActivityTypes()
            // Load current week sessions when view appears
            Task {
                await loadCurrentWeekSessions()
            }
        }
        .onAppear {
            // Ensure we only have current week sessions loaded
            Task {
                await loadCurrentWeekSessions()
            }
        }
        .onAppear { 
            // Initialize with current week filter
            filterExportState.selectedDateFilter = .thisWeek
        }
        .onChange(of: sessionManager.lastUpdated) { _ in
            // Auto-refresh when session data changes (after edit, delete, etc.)
            Task {
                await loadCurrentWeekSessions()
                // Update chart data when sessions change
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
                // Refresh projects data to ensure phases are up to date
                await projectsViewModel.loadProjects()
            }
        }
        .onChange(of: activityTypesViewModel.activityTypes) { _ in
            // Refresh sessions when activity types change
            Task {
                await loadCurrentWeekSessions()
            }
        }
        .onChange(of: filterExportState.isExpanded) { _, isExpanded in
            // Filter panel toggle should NOT load different data
            // The panel is just UI controls - data loading happens when filters are applied
            if !isExpanded {
                // When filter is closed, go back to current week only
                Task {
                    await loadCurrentWeekSessions()
                }
            }
            // When filter is opened, do nothing - keep current data visible
        }
        .onChange(of: filterExportState.projectFilter) { _, _ in
            // No pagination needed anymore
        }
        .onReceive(NotificationCenter.default.publisher(for: .projectsDidChange)) { _ in
            // Refresh projects data when projects change (e.g., phases added)
            Task {
                await projectsViewModel.loadProjects()
            }
        }
        .alert("Export Complete", isPresented: $showingExportAlert) {
            Button("OK") { }
        } message: { Text(exportMessage) }
        .confirmationDialog("Delete Session", isPresented: $showingDeleteAlert, presenting: toDelete) { session in
            Button("Delete session for \"\(session?.projectName ?? "Unknown")\"", role: .destructive) {
                if let sessionToDelete = session {
                    deleteSession(sessionToDelete)
                }
            }
        } message: { _ in
             Text("Are you sure? This action cannot be undone.")
        }
    }
    
    // MARK: - Data Loading Functions
    
    /// Load only current week sessions for default view
    private func loadCurrentWeekSessions() async {
        isLoading = true
        let sessions = getCurrentWeekSessions()
        currentWeekSessions = groupSessionsByDate(sessions)
        
        // Expand all groups by default
        expandedGroups = Set(currentWeekSessions.map { $0.id })
        
        isLoading = false
    }
    
    /// Get sessions from current week only
    private func getCurrentWeekSessions() -> [SessionRecord] {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.startOfDay(for: today)
        
        // Get start of current week (Sunday)
        let currentWeekStart: Date
        if let weekRange = calendar.dateInterval(of: .weekOfYear, for: today) {
            currentWeekStart = weekRange.start
        } else {
            currentWeekStart = weekStart
        }
        
        return sessionManager.allSessions.filter { session in
            guard let start = session.startDateTime else { return false }
            return start >= currentWeekStart && start <= today
        }
    }
    
    /// Group sessions by date for display
    private func groupSessionsByDate(_ sessions: [SessionRecord]) -> [GroupedSession] {
        let grouped = Dictionary(grouping: sessions) { session -> Date in
            guard let start = session.startDateTime else { return Date() }
            return Calendar.current.startOfDay(for: start)
        }
        
        // Sort groups by date in descending order (most recent first)
        // This will show Monday at the top if it's the most recent day
        let sortedGroups = grouped.sorted(by: { group1, group2 in
            return group1.key > group2.key
        })
        
        return sortedGroups.map { group in
            let sortedSessions = sortSessionsByDate(group.value)
            return GroupedSession(date: group.key, sessions: sortedSessions)
        }
    }
    
    // MARK: - Data Functions
    
    private func exportSessions(format: String) {
        let sessions = fullyFilteredSessions
        guard !sessions.isEmpty else {
            exportMessage = "Nothing to export – no sessions match the current filter."
            showingExportAlert = true
            return
        }

        if let path = sessionManager.exportSessions(sessions, format: format) {
            exportMessage = "Sessions exported to \(path.path)"
        } else {
            exportMessage = "Export failed."
        }
        showingExportAlert = true
    }
    
    private func deleteSession(_ session: SessionRecord) {
        if sessionManager.deleteSession(id: session.id) {
        }
        toDelete = nil
    }
    
    // MARK: - Filter Handling
    
    private func handleDateFilterSelection(_ filter: SessionsDateFilter) {
        filterExportState.selectedDateFilter = filter
        
        // Note: Date filtering logic simplified for now
        // Will be reimplemented when needed
    }
    
    private func handleCustomDateRangeChange(_ range: DateRange?) {
        filterExportState.customDateRange = range
    }
    
    private func applyFilters() {
        // Apply filters and update the session list
        Task {
            // Start with all sessions instead of just current week
            var filteredSessions = sessionManager.allSessions
            
            // Apply project filtering first
            if filterExportState.projectFilter != "All" {
                filteredSessions = filteredSessions.filter { $0.projectName == filterExportState.projectFilter }
            }
            
            // Apply date filtering based on selected filter
            switch filterExportState.selectedDateFilter {
            case .today:
                let today = Calendar.current.startOfDay(for: Date())
                filteredSessions = filteredSessions.filter { session in
                    guard let start = session.startDateTime else { return false }
                    return Calendar.current.isDate(start, inSameDayAs: today)
                }
            case .thisWeek:
                let calendar = Calendar.current
                let today = Date()
                guard let weekRange = calendar.dateInterval(of: .weekOfYear, for: today) else { break }
                filteredSessions = filteredSessions.filter { session in
                    guard let start = session.startDateTime else { return false }
                    return start >= weekRange.start && start <= weekRange.end
                }
            case .thisMonth:
                let calendar = Calendar.current
                let today = Date()
                guard let monthRange = calendar.dateInterval(of: .month, for: today) else { break }
                filteredSessions = filteredSessions.filter { session in
                    guard let start = session.startDateTime else { return false }
                    return start >= monthRange.start && start <= monthRange.end
                }
            case .thisYear:
                let calendar = Calendar.current
                let today = Date()
                guard let yearRange = calendar.dateInterval(of: .year, for: today) else { break }
                filteredSessions = filteredSessions.filter { session in
                    guard let start = session.startDateTime else { return false }
                    return start >= yearRange.start && start <= yearRange.end
                }
            case .custom:
                if let customRange = filterExportState.customDateRange {
                    filteredSessions = filteredSessions.filter { session in
                        guard let start = session.startDateTime else { return false }
                        return start >= customRange.startDate && start <= customRange.endDate
                    }
                }
            case .clear:
                // No additional filtering - use all sessions
                break
            }
            
            // Update the grouped sessions with filtered results
            currentWeekSessions = groupSessionsByDate(filteredSessions)
        }
    }

    // MARK: - Nested Filter Button Component
    struct SessionFilterButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(title, action: action)
                .buttonStyle(FilterButtonStyle(isSelected: isSelected))
        }
    }
}


// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct SessionsView_Previews: PreviewProvider {
    static var previews: some View {
        return SessionsView_PreviewsContent()
            .frame(width: 1200, height: 800)
            .background(Color(.windowBackgroundColor))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}

struct SessionsView_PreviewsContent: View {
    @StateObject var sessionManager = SessionManager.shared
    @StateObject var projectsViewModel = ProjectsViewModel.shared
    
    var body: some View {
        SessionsView()
            .onAppear {
                // Load data just like the main app does
                Task {
                    await projectsViewModel.loadProjects()
                    await sessionManager.loadAllSessions()
                }
            }
    }
}
#endif
