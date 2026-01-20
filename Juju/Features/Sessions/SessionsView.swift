import SwiftUI
import Foundation

// MARK: - Ordinal Helper
private extension Int {
    var ordinalSuffix: String {
        switch (self % 100) {
        case 11, 12, 13: return "th"
        default:
            switch (self % 10) {
            case 1: return "st"
            case 2: return "nd"
            case 3: return "rd"
            default: return "th"
            }
        }
    }
}


// MARK: - Pretty date helper
private extension Date {
    /// "Monday, 23rd October"
    var prettyHeader: String {
        let cal = Calendar.current
        let weekday = cal.weekdaySymbols[cal.component(.weekday, from: self) - 1]
        let day     = cal.component(.day, from: self)
        let month   = cal.monthSymbols[cal.component(.month, from: self) - 1]
        return "\(weekday), \(day)\(day.ordinalSuffix) \(month)"
    }
    
    /// "Jan 15, 2024"
    var shortHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: self)
    }
    
    /// "Today", "Yesterday", or "Jan 15"
    var relativeHeader: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thisDate = calendar.startOfDay(for: self)
        
        if calendar.isDate(today, inSameDayAs: thisDate) {
            return "Today"
        } else if calendar.isDate(calendar.date(byAdding: .day, value: -1, to: today)!, inSameDayAs: thisDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
        }
    }
}


// MARK: - Sessions View

struct GroupedSession: Identifiable {
    let id      = UUID()
    let date    : Date
    let sessions: [SessionRecord]
    
    /// Calculate total duration for all sessions in this group
    var totalDurationMinutes: Int {
        return sessions.reduce(0, { result, session in
            result + session.durationMinutes
        })
    }
    
    /// Format duration as "1h 30m" or similar
    var formattedDuration: String {
        let hours = totalDurationMinutes / 60
        let minutes = totalDurationMinutes % 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
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

    // MARK: - Nested GroupedSessionView
    private struct GroupedSessionView: View {
        let group: GroupedSession
        let projects: [Project]
        let activityTypes: [ActivityType]
        let sidebarState: SidebarStateManager
        let onDelete: ((SessionRecord) -> Void)
        let onNotesChanged: ((SessionRecord, String) -> Void)
        let onProjectChanged: (() -> Void)
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Day Header - now integrated directly into SessionsView
                HStack {
                    // Left section: Date and session count
                    HStack(spacing: 12) {
                        // Date text
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.date.prettyHeader)
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        
                        // Session count badge
                        Text("\(group.sessions.count) session\(group.sessions.count != 1 ? "s" : "")")
                            .font(Theme.Fonts.caption.weight(.semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.divider.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Total duration badge (right aligned)
                    Text(group.formattedDuration)
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .padding(.vertical, Theme.spacingSmall)
                .padding(.horizontal, Theme.spacingMedium)
                
                // Session rows (always visible now - no expansion needed)
                VStack(spacing: Theme.spacingSmall) {
                    ForEach(group.sessions) { session in
                        SessionsRowView(
                            session: session,
                            projects: projects,
                            activityTypes: activityTypes,
                            onDelete: onDelete,
                            onNotesChanged: { newNotes in
                                onNotesChanged(session, newNotes)
                            },
                            onProjectChanged: onProjectChanged
                        )
                    }
                }
                .padding(.horizontal, Theme.spacingMedium)
                .padding(.vertical, Theme.spacingSmall)
            }
        }
    }

    // MARK: - State Properties
    
    // Filter and export state (now managed by the modular component)
    @StateObject private var filterState = FilterExportState()
    
    // Editing state
    @State private var showingDeleteAlert = false
    @State private var toDelete: SessionRecord? = nil
    
    // UI state
    @State private var isLoading = false // This can be used for initial load if needed
    
    // Current week sessions only - no pagination needed
    @State private var currentWeekSessions: [GroupedSession] = []
    
    // Track which session is being edited
    @State private var editingSessionID: String? = nil
    
    // Track last update time to force UI refresh
    @State private var lastRefreshTime = Date()
    
    
    // Filter persistence: store the last applied filter state
    @State private var lastAppliedFilter: SessionsDateFilter = .thisWeek
    @State private var lastAppliedProjectFilter: String = "All"
    @State private var lastAppliedCustomRange: DateRange? = nil
    
    // Cached session count to avoid recalculation
    @State private var cachedSessionCount = 0
    
    // Force session count update when sessions change
    @State private var sessionCountVersion = 0
    
    // Track filter state changes to update session count
    @State private var filterStateVersion = 0
    
    // Track when sessions are loaded to ensure count is accurate
    @State private var sessionsLoaded = false

    // MARK: - Computed Properties
    
    /// Apply all filters to sessions with consistent logic
    ///
    /// **AI Context**: This method provides the main filtering pipeline for sessions,
    /// applying all active filters in sequence and returning the final filtered results.
    /// It's the central point where all filter logic comes together.
    ///
    /// **Business Rules**:
    /// - Starts with all sessions as the base
    /// - Applies project filter if not "All"
    /// - Applies activity type filter if not "All"
    /// - Applies date filtering based on selected filter
    /// - Sorts by start date (newest first) for consistent ordering
    /// - Returns filtered and sorted session array
    ///
    /// **Performance Notes**:
    /// - Uses optimized Array+SessionExtensions methods
    /// - Single pass through data for each filter type
    /// - Minimal memory allocation with method chaining
    ///
    /// **Integration**: Leverages Array+SessionExtensions for all filtering operations
    ///
    /// - Returns: Filtered and sorted array of SessionRecord objects
    private func getFilteredSessions() -> [SessionRecord] {
        // Start with all sessions
        var sessions = sessionManager.allSessions
        
        // Apply project filter using Array+SessionExtensions if not "All"
        if filterState.projectFilter != "All" {
            sessions = sessions.filteredByProject(filterState.projectFilter)
        }
        
        // Apply activity type filter using Array+SessionExtensions if not "All"
        if filterState.activityTypeFilter != "All" {
            sessions = sessions.filteredByActivityType(filterState.activityTypeFilter)
        }
        
        // Apply date filtering based on selected filter
        let filteredByDate = applyDateFilter(to: sessions)
        
        // Sort by start date using Array+SessionExtensions
        let sortedSessions = filteredByDate.sortedByStartDate()
        
        return sortedSessions
    }
    
    /// Count of sessions based on current filter state
    private var currentSessionCount: Int {
        // For the filter badge, we want to show the count of sessions that match the current filters
        // This should reflect what would be shown if the user applied the filters
        let filtered = getFilteredSessions()
        print("🔢 Current session count: \(filtered.count) sessions")
        return filtered.count
    }
    
    /// Apply date filtering to sessions
    private func applyDateFilter(to sessions: [SessionRecord]) -> [SessionRecord] {
        switch filterState.selectedDateFilter {
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            return sessions.filter { session in
                let start = session.startDate
                return Calendar.current.isDate(start, inSameDayAs: today)
            }
        case .thisWeek:
            let calendar = Calendar.current
            let today = Date()
            guard let weekRange = calendar.dateInterval(of: .weekOfYear, for: today) else { return sessions }
            return sessions.filter { session in
                let start = session.startDate
                return start >= weekRange.start && start <= weekRange.end
            }
        case .thisMonth:
            let calendar = Calendar.current
            let today = Date()
            guard let monthRange = calendar.dateInterval(of: .month, for: today) else { return sessions }
            return sessions.filter { session in
                let start = session.startDate
                return start >= monthRange.start && start <= monthRange.end
            }
        case .thisYear:
            let calendar = Calendar.current
            let today = Date()
            guard let yearRange = calendar.dateInterval(of: .year, for: today) else { return sessions }
            return sessions.filter { session in
                let start = session.startDate
                return start >= yearRange.start && start <= yearRange.end
            }
        case .allTime:
            // No date filtering - use all sessions
            return sessions
        case .custom:
            if let customRange = filterState.customDateRange {
                return sessions.filter { session in
                    let start = session.startDate
                    return start >= customRange.startDate && start <= customRange.endDate
                }
            }
            return sessions
        case .clear:
            // No additional filtering - use all sessions
            return sessions
        }
    }
    
    /// Update session count when sessions change
    private func updateSessionCount() {
        var count = 0
        for group in currentWeekSessions {
            count += group.sessions.count
        }
        cachedSessionCount = count
        sessionCountVersion += 1
    }
    
    /// Create grouped session views for display
    private var groupedSessionViews: some View {
        let activeProjects = projectsViewModel.activeProjects
        let activeActivityTypes = activityTypesViewModel.activeActivityTypes
        return ForEach(currentWeekSessions, id: \.id) { group in
            GroupedSessionView(
                group: group,
                projects: activeProjects,
                activityTypes: activeActivityTypes,
                sidebarState: sidebarState,
                onDelete: handleDeleteSession,
                onNotesChanged: handleNotesChanged,
                onProjectChanged: handleProjectChanged
            )
        }
        .id(lastRefreshTime) // Force refresh when lastRefreshTime changes
    }
    
    // MARK: - Session Action Handlers

    private func handleDeleteSession(_ sessionToDelete: SessionRecord) {
        toDelete = sessionToDelete
        showingDeleteAlert = true
    }

    /// Handle session update notifications to refresh specific session rows
    private func handleSessionUpdateNotification(_ notification: Notification) {
        // Check if this notification contains a sessionID
        guard let sessionID = notification.userInfo?["sessionID"] as? String else {
            return
        }

        print("🔔 Received session update notification for session ID: \(sessionID)")

        // Debounce multiple notifications for the same session
        guard editingSessionID != sessionID else {
            print("🔄 Skipping duplicate notification for session \(sessionID)")
            return
        }

        // Set the editing session ID to prevent duplicate processing
        editingSessionID = sessionID

        // Small delay to ensure the session manager has the latest data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Find the updated session in the session manager
            guard let updatedSession = self.sessionManager.allSessions.first(where: { $0.id == sessionID }) else {
                print("⚠️ Updated session \(sessionID) not found in session manager")
                self.editingSessionID = nil
                return
            }

            // Check if this session should be visible with current filters
            // This ensures we only update sessions that are actually visible in the UI
            let filteredSessions = self.getFilteredSessions()
            let isSessionVisible = filteredSessions.contains(where: { $0.id == updatedSession.id })

            if isSessionVisible {
                print("👀 Session \(updatedSession.id) is visible in current filtered view - updating UI")
                // Update the specific session in our currentWeekSessions array
                self.refreshSpecificSession(updatedSession)
            } else {
                print("🔍 Session \(updatedSession.id) is not visible in current filtered view - skipping UI update")
                // Session is filtered out, so we don't need to update the UI
                // The user can't see this session anyway, so no UI refresh needed
            }

            // Clear the editing session ID after processing
            self.editingSessionID = nil
        }
    }

    /// Refresh a specific session in the UI without affecting filters
    private func refreshSpecificSession(_ updatedSession: SessionRecord) {
        print("🔄 Refreshing session \(updatedSession.id) in UI")

        // Create a new array with the updated session
        var updatedSessions = currentWeekSessions

        // Find the group that contains this session
        for groupIndex in updatedSessions.indices {
            var group = updatedSessions[groupIndex]

            // Create a mutable copy of the sessions array
            var mutableSessions = group.sessions

            // Check if this group contains our session
            if let sessionIndex = mutableSessions.firstIndex(where: { $0.id == updatedSession.id }) {
                // Replace the old session with the updated one
                mutableSessions[sessionIndex] = updatedSession

                // Create a new group with the updated sessions
                let updatedGroup = GroupedSession(date: group.date, sessions: mutableSessions)

                // Update the group in our array
                updatedSessions[groupIndex] = updatedGroup

                print("✅ Successfully updated session \(updatedSession.id) in group \(group.date)")

                // Update the state to trigger UI refresh
                DispatchQueue.main.async {
                    self.currentWeekSessions = updatedSessions
                    self.lastRefreshTime = Date() // Force refresh timestamp
                }

                return
            }
        }

        print("ℹ️ Session \(updatedSession.id) not found in current week sessions - may be filtered out")
    }
    
    private func handleNotesChanged(_ session: SessionRecord, _ newNotes: String) {
        // Update only the session notes using the single-field update method
        // This avoids any date/time parsing issues that could cause midnight duration bugs
        let success = sessionManager.updateSession(id: session.id, field: "notes", value: newNotes)
        
        if success {
            // Trigger refresh to update the UI
            Task {
                await loadCurrentWeekSessions()
            }
        }
    }
    
    private func handleProjectChanged() {
        print("🔄 Project changed callback triggered in SessionsView")
        // This callback is triggered when a session is edited, not just when project changes
        // We need to refresh the session data to show the latest changes

        // Since we don't have the session ID here, we need to force a UI refresh
        // by updating the lastRefreshTime, which will cause SwiftUI to re-evaluate
        // the view and pick up the latest session data from SessionManager
        DispatchQueue.main.async {
            self.lastRefreshTime = Date()
        }
    }
    
    /// Computed property that automatically updates when sessionManager.allSessions changes
    private var groupedCurrentWeekSessions: [GroupedSession] {
        let sessions = getCurrentWeekSessions()
        return groupSessionsByDate(sessions)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Text("Sessions")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Theme.spacingLarge)
        .padding(.horizontal, Theme.spacingLarge)
        .background(Theme.Colors.background)
    }
    
    // MARK: - Content Area View Components
    
    /// Main content area showing sessions grid, loading states, or empty states
    @ViewBuilder
    private var mainContentArea: some View {
        if projectsViewModel.isLoading {
            // Projects or activity types are loading
            VStack {
                Spacer()
                ProgressView("Loading projects and activity types...")
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
                LazyVStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    groupedSessionViews
                }
                .padding(.vertical, Theme.spacingSmall)
            }
            .scrollContentBackground(.hidden)
        }
    }
    
    /// Floating filter bar that appears when filters are expanded
    @ViewBuilder
    private var floatingFilterBar: some View {
        if filterState.isExpanded {
            VStack {
                Spacer()
                bottomFilterBarView()
                    .padding(.bottom, Theme.spacingLarge)
            }
        }
    }
    
    /// Bottom filter bar view (extracted to simplify type checking)
    @ViewBuilder
    private func bottomFilterBarView() -> some View {
        BottomFilterBar(
            filterState: filterState,
            projects: projectsViewModel.activeProjects,
            activityTypes: activityTypesViewModel.activeActivityTypes,
            filteredSessionsCount: currentSessionCount,
            onDateFilterChange: handleDateFilterSelection,
            onCustomDateRangeChange: handleCustomDateRangeChange,
            onProjectFilterChange: handleProjectFilterChange,
            onActivityTypeFilterChange: handleActivityTypeFilterChange,
            onConfirmFilters: confirmFilters,
            onClose: { filterState.isExpanded = false }
        )
    }
    
    /// Filter toggle button that appears centered at the bottom
    @ViewBuilder
    private var filterToggleButton: some View {
        if !filterState.isExpanded {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FilterToggleButton(
                        filterState: filterState,
                        filteredSessionsCount: currentSessionCount,
                        onToggle: { filterState.isExpanded.toggle() }
                    )
                    Spacer()
                }
                .padding(.bottom, Theme.spacingMedium) // Reduced padding for smaller appearance
            }
        }
    }
    
    // MARK: - Content Area View
    private var contentAreaView: some View {
        ZStack {
            mainContentArea
            floatingFilterBar
            filterToggleButton
        }
    }
    
    // MARK: - Body
    public var body: some View {
        mainView()
    }

    @ViewBuilder
    private func mainView() -> some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Content Area
            contentAreaView
        }
        .background(Theme.Colors.background)
        .task {
            // Load current week sessions first (essential for display)
            await loadCurrentWeekSessions()

            // Load projects and activity types in background with delays to avoid blocking
            // Use Task.detached to avoid blocking UI, but ensure UI updates happen on main thread
            Task.detached {
                // Small delay to let sessions load first
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay

                await MainActor.run {
                    Task {
                        await projectsViewModel.loadProjects()

                        // Another small delay before loading activity types
                        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay

                        await activityTypesViewModel.loadActivityTypes()
                    }
                }
            }
        }
        .onAppear {
            // Initialize with current week filter and apply it immediately
            filterState.selectedDateFilter = .thisWeek // Ensure default is current week
            // Apply the default filter to load weekly sessions
            Task {
                // First load the current week sessions
                await loadCurrentWeekSessions()
                // Then apply filters to ensure everything is properly initialized
                await applyFiltersPreservingState()
                await MainActor.run {
                    updateSessionCount()
                }
            }
        }
        .onChange(of: activityTypesViewModel.activityTypes) { _ in
            handleActivityTypesChange()
        }
        .onChange(of: filterState.isExpanded) { _, isExpanded in
            handleFilterExpansionChange(isExpanded)
        }
        .onChange(of: filterState.shouldRefresh) { _, _ in
            handleManualRefresh()
        }
        .onChange(of: filterState.selectedDateFilter) { _, _ in
            // When date filter changes, update the session count
            Task {
                await MainActor.run {
                    updateSessionCount()
                }
            }
        }
        .onChange(of: filterState.projectFilter) { _, _ in
            // When project filter changes, update the session count
            Task {
                await MainActor.run {
                    updateSessionCount()
                }
            }
        }
        .onChange(of: filterState.activityTypeFilter) { _, _ in
            // When activity type filter changes, update the session count
            Task {
                await MainActor.run {
                    updateSessionCount()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .projectsDidChange)) { _ in
            handleProjectsChange()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { notification in
            handleSessionUpdateNotification(notification)
        }
        .confirmationDialog("Delete Session", isPresented: $showingDeleteAlert, presenting: toDelete) { session in
            Button("Delete session for \"\(session.getProjectName(from: projectsViewModel.projects))\"", role: .destructive) {
                deleteSession(session)
            }
        } message: { session in
            Text("Are you sure you want to delete this session for \"\(session.getProjectName(from: projectsViewModel.projects))\"? This action cannot be undone.")
        }
    }
    
    // MARK: - Helper methods to simplify mainView
    private func handleActivityTypesChange() {
        Task {
            await loadCurrentWeekSessions()
            await MainActor.run {
                updateSessionCount()
            }
        }
    }
    
    private func handleFilterExpansionChange(_ isExpanded: Bool) {
        // Filter panel toggle should NOT load different data
        // The panel is just UI controls - data loading happens when filters are applied
        if !isExpanded {
            // When filter is closed, DO NOT reset filters - preserve current state
            // Only update the session count to reflect current filters
            Task {
                await MainActor.run {
                    updateSessionCount()
                }
            }
        }
        // When filter is opened, do nothing - keep current data visible
    }
    
    private func handleManualRefresh() {
        Task {
            await applyFiltersPreservingState()
            await MainActor.run {
                updateSessionCount()
            }
        }
    }
    
    private func handleProjectsChange() {
        Task {
            await projectsViewModel.loadProjects()
            await MainActor.run {
                updateSessionCount()
            }
        }
    }
    
    // MARK: - Data Loading Functions

    /// Load all sessions for default view
    private func loadAllSessions() async {
        isLoading = true
        let sessions = getAllSessions()
        currentWeekSessions = groupSessionsByDate(sessions)
        // Force session count update
        updateSessionCount()
        isLoading = false
    }

    /// Load only current week sessions for default view
    private func loadCurrentWeekSessions() async {
        isLoading = true
        // Get current week sessions based on the current date filter
        let sessions = getCurrentWeekSessions()
        currentWeekSessions = groupSessionsByDate(sessions)
        // Force session count update
        updateSessionCount()
        isLoading = false
    }
    
    /// Get all sessions (not just current week)
    private func getAllSessions() -> [SessionRecord] {
        return sessionManager.allSessions
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
            let start = session.startDate
            return start >= currentWeekStart && start <= today
        }
    }
    
    /// Group sessions by date for display
    private func groupSessionsByDate(_ sessions: [SessionRecord]) -> [GroupedSession] {
        let grouped = Dictionary(grouping: sessions) { session -> Date in
            let start = session.startDate
            return Calendar.current.startOfDay(for: start)
        }
        
        // Sort groups by date in descending order (most recent first)
        // This will show Monday at the top if it's the most recent day
        let sortedGroups = grouped.sorted(by: { group1, group2 in
            return group1.key > group2.key
        })
        
        return sortedGroups.map { group in
            let sortedSessions = group.value.sortedByStartDate()
            return GroupedSession(date: group.key, sessions: sortedSessions)
        }
    }
    
    // MARK: - Data Functions
    
    private func deleteSession(_ session: SessionRecord) {
        if sessionManager.deleteSession(id: session.id) {
        }
        toDelete = nil
    }
    
    
    // MARK: - Filter Handling
    
    private func handleDateFilterSelection(_ filter: SessionsDateFilter) {
        filterState.selectedDateFilter = filter
        
        // Note: Date filtering logic simplified for now
        // Will be reimplemented when needed
    }
    
    private func handleCustomDateRangeChange(_ range: DateRange?) {
        filterState.customDateRange = range
    }
    
    private func handleProjectFilterChange(_ project: String) {
        filterState.projectFilter = project
    }
    
    private func handleActivityTypeFilterChange(_ activityType: String) {
        filterState.activityTypeFilter = activityType
        // Do NOT refresh immediately - wait for user to click "Confirm"
        // The filter will be applied when confirmFilters() is called
    }
    
    private func confirmFilters() {
        filterState.requestManualRefresh()
    }
    
    
    
    /// Apply current filters while preserving filter state (used for auto-refresh)
    private func applyFiltersPreservingState() async {
        let filteredSessions = getFilteredSessions()
        currentWeekSessions = groupSessionsByDate(filteredSessions)
        lastRefreshTime = Date()
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct SessionsView_Previews: PreviewProvider {
    static var previews: some View {
        SessionsView()
            .onAppear {
                // Load data just like the main app does
                Task {
                    await ProjectsViewModel.shared.loadProjects()
                    await SessionManager.shared.loadAllSessions()
                }
            }
            .frame(width: 1200, height: 800)
            .background(Theme.Colors.background)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
