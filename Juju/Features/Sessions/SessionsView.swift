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

            // 2. 3‑Column Grid for the Sessions …
            LazyVGrid(
                columns: Array(repeating: .init(.flexible(), spacing: Theme.spacingMedium), count: 3),
                spacing: Theme.spacingMedium
            ) {
                ForEach(group.sessions) { session in
                    SessionCardView(
                        session: session,
                        projects: projects,
                        onSave: onSave,
                        onDelete: { onDelete(session) }
                    )
                    .frame(minHeight: 120)
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
    
    // Filter state
    @State private var projectFilter = "All"
    @State private var selectedDateFilter: DateFilter = .thisWeek
    @State private var currentDateInterval: DateInterval? = nil
    
    // Editing state
    @State private var showingDeleteAlert = false
    @State private var toDelete: SessionRecord? = nil
    
    // UI state
    @State private var isLoading = false // This can be used for initial load if needed
    @State private var showingExportAlert = false
    @State private var exportMessage = ""
    
    // Pagination state
    @State private var visibleGroupCount = 5
    private let groupsPerPage = 5
    @State private var allGroupedSessions: [GroupedSession] = []

    // MARK: - Computed Properties
    
    /// The source of truth for all filtering and sorting.
    private var fullyFilteredSessions: [SessionRecord] {
        var sessions = sessionManager.allSessions

        if let interval = currentDateInterval {
            sessions = sessions.filter { session in
                guard let start = session.startDateTime else { return false }
                return interval.contains(start)
            }
        }

        if projectFilter != "All" {
            sessions = sessions.filter { $0.projectName == projectFilter }
        }

        sessions.sort(by: { ($0.startDateTime ?? Date.distantPast) > ($1.startDateTime ?? Date.distantPast) })
        return sessions
    }
    
    /// Groups the filtered sessions by day for the grid view.
    private var groupedSessions: [GroupedSession] {
        // Return the pre-computed grouped sessions
        return Array(allGroupedSessions.prefix(visibleGroupCount))
    }

    
    // MARK: - Body
    public var body: some View {
        VStack(spacing: 0) {
            
            // --- Main Content Area ---
            if allGroupedSessions.isEmpty {
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
                        // Iterate over the visible groups based on pagination
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

                    
                    // --- NEW: "Load More" Button ---
                    if visibleGroupCount < allGroupedSessions.count {
                        Button("Load More...") {
                            visibleGroupCount += groupsPerPage
                        }
                        .buttonStyle(.primary)
                        .padding()
                    }
                }
                .scrollContentBackground(.hidden)
            }
            
            // --- Sticky filter header at the bottom ---
            VStack(spacing: 0) {
                HStack {
                    // Project filter
                    HStack {
                        Text("Project:")
                        Picker(selection: $projectFilter, label: EmptyView()) {
                            Text("All").tag("All")
                            ForEach(projectsViewModel.projects) { Text($0.name).tag($0.name) }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                        .onChange(of: projectFilter) { _, _ in
                            // CHANGED: Reset pagination on filter change
                            visibleGroupCount = groupsPerPage
                        }
                    }
                    
                    // Date filters
                    HStack(spacing: Theme.spacingSmall) {
                        Text("Date Range:")
                        ForEach(DateFilter.allCases) { filter in
                            SessionFilterButton(
                                title: filter.title,
                                isSelected: selectedDateFilter == filter,
                                action: { handleDateFilterSelection(filter) }
                            )
                        }
                    }
                    
                    Spacer()
                    
                    // Export button
                    Menu {
                        Button("Export as CSV") { exportSessions(format: "csv") }
                        Button("Export as Text") { exportSessions(format: "txt") }
                        Button("Export as Markdown") { exportSessions(format: "md") }
                    } label: {
                        HStack(spacing: Theme.spacingExtraSmall) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Export")
                        }
                    }
                    .buttonStyle(.primary)
                }
                .padding()
                .background(Theme.Colors.surface)
            }
        }
        .background(Theme.Colors.background)
        .task { 
            await projectsViewModel.loadProjects()
            // Load sessions when view appears
            Task {
                await loadGroupedSessions()
            }
        }
        .onAppear { handleDateFilterSelection(.thisWeek) }
        .onChange(of: sessionManager.lastUpdated) { _ in
            // Auto-refresh when session data changes (after edit, delete, etc.)
            Task {
                await loadGroupedSessions()
            }
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
    
    private func loadGroupedSessions() async {
        isLoading = true
        // Load all sessions first
        let sessions = sessionManager.loadAllSessions()
        
        // Group sessions by date
        let grouped = Dictionary(grouping: sessions) { session -> Date in
            guard let start = session.startDateTime else { return Date() }
            return Calendar.current.startOfDay(for: start)
        }
        
        // Sort by date descending, then map to `GroupedSession`
        let sortedGroupedSessions = grouped
            .sorted { $0.key > $1.key }                    // newer first
            .map { GroupedSession(date: $0.key, sessions: $0.value.sorted { ($0.startDateTime ?? Date.distantPast) > ($1.startDateTime ?? Date.distantPast) }) }
        
        allGroupedSessions = sortedGroupedSessions
        visibleGroupCount = groupsPerPage
        isLoading = false
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
    
    private func handleDateFilterSelection(_ filter: DateFilter) {
        selectedDateFilter = filter
        
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        switch filter {
        case .today:
            currentDateInterval = DateInterval(start: todayStart, end: calendar.date(byAdding: .day, value: 1, to: todayStart)!)
        case .thisWeek:
            currentDateInterval = DateInterval(start: calendar.date(byAdding: .day, value: -6, to: todayStart)!, end: calendar.date(byAdding: .day, value: 1, to: todayStart)!)
        case .thisMonth:
            currentDateInterval = DateInterval(start: calendar.date(byAdding: .day, value: -29, to: todayStart)!, end: calendar.date(byAdding: .day, value: 1, to: todayStart)!)
        case .clear:
            currentDateInterval = nil
        }
        
        visibleGroupCount = groupsPerPage
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
