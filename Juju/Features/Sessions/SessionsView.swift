import SwiftUI
import Foundation
import Combine

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
    /// "Monday, 23rd October 2024"
    var prettyHeader: String {
        let cal = Calendar.current
        let weekday = cal.weekdaySymbols[cal.component(.weekday, from: self) - 1]
        let day     = cal.component(.day, from: self)
        let month   = cal.monthSymbols[cal.component(.month, from: self) - 1]
        let year    = cal.component(.year, from: self)
        return "\(weekday), \(day)\(day.ordinalSuffix) \(month) \(year)"
    }
    
    /// Short header: "Jan 15, 2024"
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
        
        // Bulk edit support
        let filterState: FilterExportState
        let flatSessionOrder: [SessionRecord]
        
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
                            onProjectChanged: onProjectChanged,
                            isSelected: filterState.selectedSessionIDs.contains(session.id),
                            isBulkEditing: filterState.isBulkEditing,
                            pendingBulkProjectID: filterState.pendingBulkProjectID,
                            pendingBulkPhaseID: filterState.pendingBulkPhaseID,
                            pendingBulkMood: filterState.pendingBulkMood,
                            onTapForSelection: {
                                // Check if NSEvent modifier flags contains shift
                                let isShiftHeld = NSEvent.modifierFlags.contains(.shift)
                                filterState.toggleSessionSelection(session.id, isShiftHeld: isShiftHeld, in: flatSessionOrder)
                            }
                        )
                        .onTapGesture(count: 2) {
                            // Double-click enters bulk edit mode
                            if !filterState.isBulkEditing {
                                filterState.enterBulkEditMode(firstSessionID: session.id)
                            }
                        }
                        .onTapGesture(count: 1) {
                            // Single click in bulk edit mode toggles selection
                            if filterState.isBulkEditing {
                                let isShiftHeld = NSEvent.modifierFlags.contains(.shift)
                                filterState.toggleSessionSelection(session.id, isShiftHeld: isShiftHeld, in: flatSessionOrder)
                            }
                        }
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
        let filtered = getFilteredSessions()
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
        let allProjects = projectsViewModel.projects
        let activeActivityTypes = activityTypesViewModel.activeActivityTypes
        
        let flatOrderedSessions: [SessionRecord] = currentWeekSessions.flatMap { $0.sessions }
        
        return ForEach(currentWeekSessions, id: \.id) { group in
            GroupedSessionView(
                group: group,
                projects: allProjects,
                activityTypes: activeActivityTypes,
                sidebarState: sidebarState,
                onDelete: handleDeleteSession,
                onNotesChanged: handleNotesChanged,
                onProjectChanged: handleProjectChanged,
                filterState: filterState,
                flatSessionOrder: flatOrderedSessions
            )
        }
        .id(lastRefreshTime)
    }
    
    // MARK: - Session Action Handlers

    private func handleDeleteSession(_ sessionToDelete: SessionRecord) {
        toDelete = sessionToDelete
        showingDeleteAlert = true
    }

    private func handleSessionUpdateNotification(_ notification: Notification) {
        guard let sessionID = notification.userInfo?["sessionID"] as? String else {
            return
        }

        if sessionID == "bulkPhaseClear" {
            Task {
                await loadCurrentWeekSessions()
                await MainActor.run { updateSessionCount() }
            }
            return
        }

        guard editingSessionID != sessionID else { return }

        editingSessionID = sessionID

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let updatedSession = self.sessionManager.allSessions.first(where: { $0.id == sessionID }) else {
                self.editingSessionID = nil
                return
            }

            let filteredSessions = self.getFilteredSessions()
            let isSessionVisible = filteredSessions.contains(where: { $0.id == updatedSession.id })

            if isSessionVisible {
                self.refreshSpecificSession(updatedSession)
            }

            self.editingSessionID = nil
        }
    }

    private func refreshSpecificSession(_ updatedSession: SessionRecord) {
        var updatedSessions = currentWeekSessions

        for groupIndex in updatedSessions.indices {
            var group = updatedSessions[groupIndex]
            var mutableSessions = group.sessions

            if let sessionIndex = mutableSessions.firstIndex(where: { $0.id == updatedSession.id }) {
                mutableSessions[sessionIndex] = updatedSession
                let updatedGroup = GroupedSession(date: group.date, sessions: mutableSessions)
                updatedSessions[groupIndex] = updatedGroup

                DispatchQueue.main.async {
                    self.currentWeekSessions = updatedSessions
                    self.lastRefreshTime = Date()
                }
                return
            }
        }
    }
    
    private func handleNotesChanged(_ session: SessionRecord, _ newNotes: String) {
        let success = sessionManager.updateSession(id: session.id, field: "notes", value: newNotes)
        
        if success {
            Task { await loadCurrentWeekSessions() }
        }
    }
    
    private func handleProjectChanged() {
        DispatchQueue.main.async {
            self.lastRefreshTime = Date()
        }
    }
    
    private var groupedCurrentWeekSessions: [GroupedSession] {
        let sessions = getCurrentWeekSessions()
        return groupSessionsByDate(sessions)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Text("Sessions")
                .font(.system(size: 32, weight: .bold, design: .default))
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Theme.spacingLarge)
        .padding(.horizontal, Theme.spacingLarge)
        .background(Theme.Colors.background)
    }
    
    // MARK: - Content Area View Components
    
    @ViewBuilder
    private var mainContentArea: some View {
        if projectsViewModel.isLoading {
            VStack {
                Spacer()
                ProgressView("Loading projects and activity types...")
                    .scaleEffect(1.5)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if currentWeekSessions.isEmpty {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading sessions...")
                        .scaleEffect(1.5)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack {
                    Spacer()
                    Text("No sessions found for the selected filters.")
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    groupedSessionViews
                }
                .padding(.vertical, Theme.spacingSmall)
            }
            .scrollContentBackground(.hidden)
        }
    }
    
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
    
    @ViewBuilder
    private func bottomFilterBarView() -> some View {
        BottomFilterBar(
            filterState: filterState,
            projects: projectsViewModel.activeProjects,
            activityTypes: activityTypesViewModel.activeActivityTypes,
            filteredSessionsCount: currentSessionCount,
            selectedSessions: sessionManager.allSessions,
            onDateFilterChange: handleDateFilterSelection,
            onCustomDateRangeChange: handleCustomDateRangeChange,
            onProjectFilterChange: handleProjectFilterChange,
            onActivityTypeFilterChange: handleActivityTypeFilterChange,
            onConfirmFilters: confirmFilters,
            onClose: { filterState.isExpanded = false },
            onBulkEditToggle: {
                filterState.enterBulkEditMode(firstSessionID: nil)
            }
        )
    }
    
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
                .padding(.bottom, Theme.spacingMedium)
            }
        }
    }
    
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
        contentStack
            .modifier(EscapeKeyHandlerViewModifier(filterState: filterState))
    }
    
    @ViewBuilder
    private var contentStack: some View {
        VStack(spacing: 0) {
            headerView
            contentAreaView
        }
        .background(Theme.Colors.background)
        .task {
            await loadCurrentWeekSessions()

            Task.detached {
                try? await Task.sleep(nanoseconds: 50_000_000)
                await MainActor.run {
                    Task {
                        await projectsViewModel.loadProjects()
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        await activityTypesViewModel.loadActivityTypes()
                    }
                }
            }
        }
        .onAppear {
            filterState.selectedDateFilter = .thisWeek
            Task {
                await loadCurrentWeekSessions()
                await applyFiltersPreservingState()
                await MainActor.run { updateSessionCount() }
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
            Task { await MainActor.run { updateSessionCount() } }
        }
        .onChange(of: filterState.projectFilter) { _, _ in
            Task { await MainActor.run { updateSessionCount() } }
        }
        .onChange(of: filterState.activityTypeFilter) { _, _ in
            Task { await MainActor.run { updateSessionCount() } }
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
    
    // MARK: - Helper Handlers
    
    private func handleActivityTypesChange() {
        Task {
            await loadCurrentWeekSessions()
            await MainActor.run { updateSessionCount() }
        }
    }
    
    private func handleFilterExpansionChange(_ isExpanded: Bool) {
        if !isExpanded {
            Task { await MainActor.run { updateSessionCount() } }
        }
    }
    
    private func handleManualRefresh() {
        if filterState.isBulkEditing {
            Task {
                let selectedIDs = filterState.selectedSessionIDs
                let sessions = sessionManager.allSessions.filter { selectedIDs.contains($0.id) }
                
                let pendingProjectID = filterState.pendingBulkProjectID
                let pendingPhaseID = filterState.pendingBulkPhaseID
                let pendingMood = filterState.pendingBulkMood
                
                for session in sessions {
                    let resolvedProjectID = pendingProjectID ?? session.projectID
                    let resolvedPhaseID = pendingPhaseID ?? session.projectPhaseID
                    let resolvedMood = pendingMood ?? session.mood
                    
                    let projectName: String
                    if let pid = pendingProjectID,
                       let project = projectsViewModel.projects.first(where: { $0.id == pid }) {
                        projectName = project.name
                    } else if let sessionProject = projectsViewModel.projects.first(where: { $0.id == session.projectID }) {
                        projectName = sessionProject.name
                    } else {
                        projectName = session.projectID
                    }
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "HH:mm"
                    
                    let success = SessionManager.shared.updateSessionFull(
                        id: session.id,
                        date: dateFormatter.string(from: session.startDate),
                        startTime: timeFormatter.string(from: session.startDate),
                        endTime: timeFormatter.string(from: session.endDate),
                        projectName: projectName,
                        notes: session.notes,
                        mood: resolvedMood,
                        activityTypeID: session.activityTypeID,
                        projectPhaseID: resolvedPhaseID,
                        action: session.action,
                        isMilestone: session.isMilestone,
                        projectID: resolvedProjectID
                    )
                    if !success {
                        print("❌ Failed to bulk update session \(session.id)")
                    }
                }
                
                await MainActor.run {
                    filterState.exitBulkEditMode()
                    updateSessionCount()
                }
                await applyFiltersPreservingState()
            }
        } else {
            Task {
                await applyFiltersPreservingState()
                await MainActor.run { updateSessionCount() }
            }
        }
    }
    
    private func handleProjectsChange() {
        Task {
            await projectsViewModel.loadProjects()
            await MainActor.run { updateSessionCount() }
        }
    }
    
    // MARK: - Data Loading Functions

    private func loadAllSessions() async {
        isLoading = true
        let sessions = getAllSessions()
        currentWeekSessions = groupSessionsByDate(sessions)
        updateSessionCount()
        isLoading = false
    }

    private func loadCurrentWeekSessions() async {
        isLoading = true
        let sessions = getCurrentWeekSessions()
        currentWeekSessions = groupSessionsByDate(sessions)
        updateSessionCount()
        isLoading = false
    }
    
    private func getAllSessions() -> [SessionRecord] {
        return sessionManager.allSessions
    }
    
    private func getCurrentWeekSessions() -> [SessionRecord] {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.startOfDay(for: today)
        
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
    
    private func groupSessionsByDate(_ sessions: [SessionRecord]) -> [GroupedSession] {
        let grouped = Dictionary(grouping: sessions) { session -> Date in
            let start = session.startDate
            return Calendar.current.startOfDay(for: start)
        }
        
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
        if sessionManager.deleteSession(id: session.id) { }
        toDelete = nil
    }
    
    // MARK: - Filter Handling
    
    private func handleDateFilterSelection(_ filter: SessionsDateFilter) {
        filterState.selectedDateFilter = filter
    }
    
    private func handleCustomDateRangeChange(_ range: DateRange?) {
        filterState.customDateRange = range
    }
    
    private func handleProjectFilterChange(_ project: String) {
        filterState.projectFilter = project
    }
    
    private func handleActivityTypeFilterChange(_ activityType: String) {
        filterState.activityTypeFilter = activityType
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

// MARK: - Escape Key Event Handler View Modifier
private struct EscapeKeyHandlerViewModifier: ViewModifier {
    @ObservedObject var filterState: FilterExportState
    
    func body(content: Content) -> some View {
        content
            .background(
                KeyEventHandlingView(filterState: filterState)
                    .frame(width: 0, height: 0)
            )
    }
}

/// NSViewRepresentable that captures key events for Escape handling
private struct KeyEventHandlingView: NSViewRepresentable {
    @ObservedObject var filterState: FilterExportState
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.filterState = filterState
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) { }
    
    class KeyView: NSView {
        weak var filterState: FilterExportState?
        
        override var acceptsFirstResponder: Bool { return true }
        
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53, let filterState = filterState, filterState.isBulkEditing {
                filterState.exitBulkEditMode()
                return
            }
            super.keyDown(with: event)
        }
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct SessionsView_Previews: PreviewProvider {
    static var previews: some View {
        SessionsView()
            .onAppear {
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