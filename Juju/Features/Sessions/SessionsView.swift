import SwiftUI
import Foundation

// Import the filter types that are defined in FilterExportTypes
// These are needed for the filter state management

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
            result + DurationCalculator.calculateDuration(start: session.startDate, end: session.endDate)
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
        let onShowNoteOverlay: ((SessionRecord) -> Void)
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
                        .background(Theme.Colors.divider.opacity(0.2))
                        .clipShape(Capsule())
                }
                .padding(.vertical, Theme.spacingSmall)
                .padding(.horizontal, Theme.spacingMedium)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Theme.Colors.divider),
                    alignment: .bottom
                )
                
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
                            onShowNoteOverlay: onShowNoteOverlay,
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
    
    // Note overlay state
    @State private var showingNoteOverlay = false
    @State private var overlaySession: SessionRecord?
    @State private var isEditingNotes = false
    @State private var editedNotes: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
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
    
    /// The source of truth for all filtering and sorting.
    private func getFullyFilteredSessions() -> [SessionRecord] {
        // Start with current week sessions
        let initialSessions = getCurrentWeekSessions()
        
        // Apply project filter if not "All"
        let filteredByProject = applyProjectFilter(to: initialSessions)
        
        // Apply activity type filter if not "All"
        let filteredByActivityType = applyActivityTypeFilter(to: filteredByProject)
        
        // Sort by start date time (most recent first)
        let sortedSessions = sortSessionsByDate(filteredByActivityType)
        
        return sortedSessions
    }
    
    /// Apply project filter to sessions
    private func applyProjectFilter(to sessions: [SessionRecord]) -> [SessionRecord] {
        guard filterState.projectFilter != "All" else {
            return sessions
        }
        
        // Filter by project ID instead of project name
        return sessions.filter { $0.projectID == filterState.projectFilter }
    }
    
    /// Apply activity type filter to sessions
    private func applyActivityTypeFilter(to sessions: [SessionRecord]) -> [SessionRecord] {
        guard filterState.activityTypeFilter != "All" else {
            return sessions
        }
        
        // Filter by activity type ID
        return sessions.filter { $0.activityTypeID == filterState.activityTypeFilter }
    }
    
    /// Sort sessions by start date time (most recent first)
    private func sortSessionsByDate(_ sessions: [SessionRecord]) -> [SessionRecord] {
        return sessions.sorted { session1, session2 in
            return session1.startDate > session2.startDate
        }
    }
    
    /// Count of sessions based on current filter state (accurate count for filtered sessions)
    private var currentSessionCount: Int {
        // Start with all sessions instead of just current week
        let initialSessions = sessionManager.allSessions
        
        // Apply project filter if not "All"
        let filteredByProject = applyProjectFilter(to: initialSessions)
        
        // Apply activity type filter if not "All"
        let filteredByActivityType = applyActivityTypeFilter(to: filteredByProject)
        
        // Apply date filtering based on selected filter
        let filteredByDate = applyDateFilter(to: filteredByActivityType)
        
        // Sort by start date time (most recent first)
        let sortedSessions = sortSessionsByDate(filteredByDate)
        
        return sortedSessions.count
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
                onShowNoteOverlay: handleShowNoteOverlay,
                onProjectChanged: handleProjectChanged
            )
        }
    }
    
    // MARK: - Session Action Handlers
    
    private func handleDeleteSession(_ sessionToDelete: SessionRecord) {
        toDelete = sessionToDelete
        showingDeleteAlert = true
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
    
    private func handleShowNoteOverlay(_ sessionToOverlay: SessionRecord) {
        let sessionNotes = sessionToOverlay.notes
        withAnimation(.easeInOut(duration: 0.2)) {
            overlaySession = sessionToOverlay
            editedNotes = sessionNotes
            showingNoteOverlay = true
            isEditingNotes = false
        }
    }
    
    private func handleProjectChanged() {
        print("🔄 Project changed callback triggered in SessionsView")
        // Do NOT automatically refresh sessions when project is changed
        // Only refresh when user clicks "Confirm" button
        Task {
            await projectsViewModel.loadProjects()
            // Removed: await self.loadCurrentWeekSessions()
            // Sessions will be refreshed when user clicks "Confirm" button
        }
    }
    
    /// Computed property that automatically updates when sessionManager.allSessions changes
    private var groupedCurrentWeekSessions: [GroupedSession] {
        let sessions = getCurrentWeekSessions()
        return groupSessionsByDate(sessions)
    }
    
    // MARK: - Note Overlay
    @ViewBuilder
    private var noteOverlay: some View {
        if showingNoteOverlay, let session = overlaySession {
            contextualNoteOverlay(for: session)
        }
    }
    
    @ViewBuilder
    private func contextualNoteOverlay(for session: SessionRecord) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Subtle background dimming - only dim the area outside the session row
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingNoteOverlay = false
                            isEditingNotes = false
                            overlaySession = nil
                            editedNotes = ""
                        }
                    }
                
                // Contextual notes overlay positioned relative to session row
                VStack(spacing: 0) {
                    if isEditingNotes {
                        contextualNoteEditorView(session: session)
                    } else {
                        contextualNoteDisplayView(session: session)
                    }
                }
                .padding(.horizontal, Theme.spacingMedium)
                .padding(.vertical, Theme.spacingMedium)
                .background(Theme.Colors.surface)
                .cornerRadius(Theme.Design.cornerRadius)
                .shadow(color: Theme.Colors.divider.opacity(0.3), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .stroke(Theme.Colors.divider, lineWidth: 1)
                )
                .transition(.asymmetric(
                    insertion: AnyTransition.move(edge: .trailing).combined(with: .opacity),
                    removal: AnyTransition.move(edge: .trailing).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.25), value: isEditingNotes)
                .animation(.easeInOut(duration: 0.25), value: showingNoteOverlay)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zIndex(100) // Ensure overlay appears above all other content
    }
    
    @ViewBuilder
    private func contextualNoteEditorView(session: SessionRecord) -> some View {
        VStack(spacing: Theme.spacingMedium) {
            VStack(spacing: Theme.spacingSmall) {
                // Text editor with improved styling
                TextEditor(text: $editedNotes)
                    .font(Theme.Fonts.body)
                    .frame(minHeight: 120, maxHeight: 200)
                    .textFieldStyle(.plain)
                    .padding(Theme.spacingSmall)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
                    .focused($isTextFieldFocused)
                
                // Action buttons with better styling
                HStack(spacing: Theme.spacingSmall) {
                    Spacer()
                    
                    Button("Cancel") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditingNotes = false
                            editedNotes = session.notes // Reset to original
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                showingNoteOverlay = false
                                overlaySession = nil
                                editedNotes = ""
                            }
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])
                    
                    Button("Save") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            // Update only the session notes using the single-field update method
                            // This avoids any date/time parsing issues that could cause midnight duration bugs
                            let success = sessionManager.updateSession(id: session.id, field: "notes", value: editedNotes)
                            
                            if success {
                                // Trigger refresh to update the UI
                                Task {
                                    await loadCurrentWeekSessions()
                                }
                            }
                            
                            isEditingNotes = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                showingNoteOverlay = false
                                overlaySession = nil
                                editedNotes = ""
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(editedNotes == session.notes) // Disable if no changes
                    .opacity(editedNotes == session.notes ? 0.5 : 1.0)
                }
            }
        }
        .padding(Theme.spacingMedium)
    }
    
    @ViewBuilder
    private func contextualNoteDisplayView(session: SessionRecord) -> some View {
        VStack(spacing: Theme.spacingMedium) {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                HStack {
                    Text("Notes")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Spacer()
                    
                    // Session context info
                    HStack(spacing: 8) {
                        Text(session.projectName)
                            .font(Theme.Fonts.caption.weight(.medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.divider.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                
                Text(session.notes.isEmpty ? "No notes yet. Click to add notes." : session.notes)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .padding(Theme.spacingSmall)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
                    .contentShape(Rectangle()) // Make entire area tappable
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditingNotes = true
                        }
                    }
            }
        }
        .padding(Theme.spacingMedium)
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
    
    
    /// Note overlay that appears above all content
    @ViewBuilder
    private var noteOverlayLayer: some View {
        noteOverlay
    }
    
    // MARK: - Content Area View
    private var contentAreaView: some View {
        ZStack {
            mainContentArea
            noteOverlayLayer
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
            DispatchQueue.global(qos: .background).async {
                // Small delay to let sessions load first
                Thread.sleep(forTimeInterval: 0.05)
                
                Task {
                    await projectsViewModel.loadProjects()
                    
                    // Another small delay before loading activity types
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
                    
                    await activityTypesViewModel.loadActivityTypes()
                }
            }
        }
        .onAppear {
            // Initialize with current week filter
            filterState.selectedDateFilter = .thisWeek
        }
        .onChange(of: sessionManager.lastUpdated) { _ in
            // Only handle session updates that don't require filter refresh
            // This prevents automatic filter refresh when sessions are edited inline
            // Filters will only refresh when user clicks "Confirm" button
            Task {
                // Update chart data when sessions change, but don't refresh filters
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
                // Refresh projects data to ensure phases are up to date
                await projectsViewModel.loadProjects()
                // Update session count when sessions change
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
        .onReceive(NotificationCenter.default.publisher(for: .projectsDidChange)) { _ in
            handleProjectsChange()
        }
        .confirmationDialog("Delete Session", isPresented: $showingDeleteAlert, presenting: toDelete) { session in
            Button("Delete session for \"\(session.projectName)\"", role: .destructive) {
                deleteSession(session)
            }
        } message: { session in
            Text("Are you sure you want to delete this session for \"\(session.projectName)\"? This action cannot be undone.")
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
            let sortedSessions = sortSessionsByDate(group.value)
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
    
    
    private func applyFilters() {
        // Apply filters and update the session list
        Task {
            // Start with all sessions instead of just current week
            var filteredSessions = sessionManager.allSessions
            
            // Apply project filtering first (by project ID now)
            if filterState.projectFilter != "All" {
                filteredSessions = filteredSessions.filter { $0.projectID == filterState.projectFilter }
            }
            
            // Apply activity type filtering
            if filterState.activityTypeFilter != "All" {
                filteredSessions = filteredSessions.filter { $0.activityTypeID == filterState.activityTypeFilter }
            }
            
            // Apply date filtering based on selected filter
            switch filterState.selectedDateFilter {
            case .today:
                let today = Calendar.current.startOfDay(for: Date())
                filteredSessions = filteredSessions.filter { session in
                    let start = session.startDate
                    return Calendar.current.isDate(start, inSameDayAs: today)
                }
            case .thisWeek:
                let calendar = Calendar.current
                let today = Date()
                guard let weekRange = calendar.dateInterval(of: .weekOfYear, for: today) else { break }
                filteredSessions = filteredSessions.filter { session in
                    let start = session.startDate
                    return start >= weekRange.start && start <= weekRange.end
                }
            case .thisMonth:
                let calendar = Calendar.current
                let today = Date()
                guard let monthRange = calendar.dateInterval(of: .month, for: today) else { break }
                filteredSessions = filteredSessions.filter { session in
                    let start = session.startDate
                    return start >= monthRange.start && start <= monthRange.end
                }
            case .thisYear:
                let calendar = Calendar.current
                let today = Date()
                guard let yearRange = calendar.dateInterval(of: .year, for: today) else { break }
                filteredSessions = filteredSessions.filter { session in
                    let start = session.startDate
                    return start >= yearRange.start && start <= yearRange.end
                }
            case .allTime:
                // No date filtering - use all sessions
                break
            case .custom:
                if let customRange = filterState.customDateRange {
                    filteredSessions = filteredSessions.filter { session in
                        let start = session.startDate
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
    
    /// Apply current filters while preserving filter state (used for auto-refresh)
    private func applyFiltersPreservingState() async {
        // Apply filters and update the session list
        // Start with all sessions instead of just current week
        var filteredSessions = sessionManager.allSessions
        
        // Apply project filtering first (by project ID now)
        if filterState.projectFilter != "All" {
            filteredSessions = filteredSessions.filter { $0.projectID == filterState.projectFilter }
        }
        
        // Apply activity type filtering
        if filterState.activityTypeFilter != "All" {
            filteredSessions = filteredSessions.filter { $0.activityTypeID == filterState.activityTypeFilter }
        }
        
        // Apply date filtering based on selected filter
        switch filterState.selectedDateFilter {
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            filteredSessions = filteredSessions.filter { session in
                let start = session.startDate
                return Calendar.current.isDate(start, inSameDayAs: today)
            }
        case .thisWeek:
            let calendar = Calendar.current
            let today = Date()
            guard let weekRange = calendar.dateInterval(of: .weekOfYear, for: today) else { break }
            filteredSessions = filteredSessions.filter { session in
                let start = session.startDate
                return start >= weekRange.start && start <= weekRange.end
            }
        case .thisMonth:
            let calendar = Calendar.current
            let today = Date()
            guard let monthRange = calendar.dateInterval(of: .month, for: today) else { break }
            filteredSessions = filteredSessions.filter { session in
                let start = session.startDate
                return start >= monthRange.start && start <= monthRange.end
            }
        case .thisYear:
            let calendar = Calendar.current
            let today = Date()
            guard let yearRange = calendar.dateInterval(of: .year, for: today) else { break }
            filteredSessions = filteredSessions.filter { session in
                let start = session.startDate
                return start >= yearRange.start && start <= yearRange.end
            }
        case .allTime:
            // No date filtering - use all sessions
            break
        case .custom:
            if let customRange = filterState.customDateRange {
                filteredSessions = filteredSessions.filter { session in
                    let start = session.startDate
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
