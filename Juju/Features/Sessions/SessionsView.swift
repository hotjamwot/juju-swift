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

// MARK: - Pretty‑date helper
private extension Date {
    /// "Monday, 23rd October"
    var prettyHeader: String {
        let cal = Calendar.current
        let weekday = cal.weekdaySymbols[cal.component(.weekday, from: self) - 1]
        let day     = cal.component(.day, from: self)
        let month   = cal.monthSymbols[cal.component(.month, from: self) - 1]
        return "\(weekday), \(day)\(day.ordinalSuffix) \(month)"
    }
}


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
    let onSave: () -> Void
    let onDelete: (SessionRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            // 1. Date Header – centred
            Text(group.date.prettyHeader)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, Theme.spacingMedium)

            // 2. 4‑Column Grid for the Sessions …
            LazyVGrid(
                columns: Array(repeating: .init(.flexible(), spacing: Theme.spacingMedium), count: 4),
                spacing: Theme.spacingMedium
            ) {
                ForEach(group.sessions) { session in
                    SessionCardView(
                        session: session,
                        projects: projects,
                        onSave: onSave,
                        onDelete: { onDelete(session) }
                    )
                    .frame(minHeight: 180)
                }
            }
            .padding(.horizontal, Theme.spacingLarge)
        }
    }
}

/// Main view for displaying and managing sessions in a grouped grid
public struct SessionsView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var projectsViewModel = ProjectsViewModel()

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

    // MARK: - Computed Properties
    
    /// The source of truth for all filtering and sorting.
    private var fullyFilteredSessions: [SessionRecord] {
        var sessions: [SessionRecord]
        
        // Always use current week sessions for display
        // Filter panel expansion should NOT change the underlying data
        sessions = getCurrentWeekSessions()

        // Apply project filtering only (simplified for now)
        if filterExportState.projectFilter != "All" {
            sessions = sessions.filter { $0.projectName == filterExportState.projectFilter }
        }

        sessions.sort(by: { ($0.startDateTime ?? Date.distantPast) > ($1.startDateTime ?? Date.distantPast) })
        return sessions
    }
    
    /// Groups the filtered sessions by day for the grid view.
    private var groupedSessions: [GroupedSession] {
        // Always use current week sessions - filter panel is just UI
        return currentWeekSessions
    }

    
    // MARK: - Body
    public var body: some View {
        ZStack {
            // --- Main Content Area ---
            if groupedSessions.isEmpty {
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
                        ForEach(groupedSessions, id: \.id) { group in
                            GroupedSessionView(
                                group: group,
                                projects: projectsViewModel.projects,
                                onSave: { sessionManager.loadAllSessions() },
                                onDelete: { session in
                                    toDelete = session
                                    showingDeleteAlert = true
                                }
                            )
                        }
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
                        filteredSessionsCount: fullyFilteredSessions.count,
                        onDateFilterChange: handleDateFilterSelection,
                        onCustomDateRangeChange: handleCustomDateRangeChange,
                        onProjectFilterChange: { _ in },
                        onExport: { format in
                            exportSessions(format: format.fileExtension)
                        },
                        onInvoicePreviewToggle: {
                            // Future invoice preview functionality
                            print("Invoice preview requested")
                        }
                    )
                    .padding(.trailing, Theme.spacingLarge)
                    .padding(.bottom, Theme.spacingLarge)
                }
            }
        }
        .background(Theme.Colors.background)
        .task { 
            await projectsViewModel.loadProjects()
            // Load current week sessions when view appears
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
                if !filterExportState.isExpanded {
                    await loadCurrentWeekSessions()
                }
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
        .alert("Export Complete", isPresented: $showingExportAlert) {
            Button("OK") { }
        } message: { Text(exportMessage) }
        .confirmationDialog("Delete Session", isPresented: $showingDeleteAlert, presenting: toDelete) { session in
            Button("Delete session for \"\(session.projectName)\"", role: .destructive) {
                deleteSession(session)
            }
        } message: { session in
             Text("Are you sure? This action cannot be undone.")
        }
    }
    
    // MARK: - Data Loading Functions
    
    /// Load only current week sessions for default view
    private func loadCurrentWeekSessions() async {
        isLoading = true
        let sessions = getCurrentWeekSessions()
        currentWeekSessions = groupSessionsByDate(sessions)
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
        
        return grouped
            .sorted { $0.key > $1.key }                    // newer first
            .map { GroupedSession(date: $0.key, sessions: $0.value.sorted { ($0.startDateTime ?? Date.distantPast) > ($1.startDateTime ?? Date.distantPast) }) }
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
        // Create sample data for preview
        let sampleSessions = [
            SessionRecord(
                id: "1",
                date: "2024-01-15",
                startTime: "09:00:00",
                endTime: "10:30:00",
                durationMinutes: 90,
                projectName: "Project Alpha",
                notes: "Quick meeting about the new features.",
                mood: 7
            ),
            SessionRecord(
                id: "2",
                date: "2024-01-15",
                startTime: "14:00:00",
                endTime: "16:00:00",
                durationMinutes: 120,
                projectName: "Project Beta",
                notes: "Long detailed notes about the implementation process.",
                mood: 9
            ),
            SessionRecord(
                id: "3",
                date: "2024-01-16",
                startTime: "10:00:00",
                endTime: "11:00:00",
                durationMinutes: 60,
                projectName: "Project Alpha",
                notes: "Review session",
                mood: 8
            )
        ]
        
        // Create a mock session manager with sample data
        let mockSessionManager = SessionManager.shared
        mockSessionManager.allSessions = sampleSessions
        
        // Create a mock projects view model
        let mockProjectsViewModel = ProjectsViewModel()
        mockProjectsViewModel.projects = [
            Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0),
            Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0)
        ]
        
        return VStack {
            SessionsView()
                .frame(width: 1200, height: 800)
                .background(Color(.windowBackgroundColor))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
