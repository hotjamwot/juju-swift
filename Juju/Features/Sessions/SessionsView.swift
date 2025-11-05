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
/// Main view for displaying and managing sessions
public struct SessionsView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var projectsViewModel = ProjectsViewModel()
    
    // Filter state
    @State private var projectFilter = "All"
    @State private var selectedDateFilter: DateFilter = .thisWeek // This now works!
    @State private var currentDateInterval: DateInterval? = nil
    
    // Pagination state
    @State private var currentPage = 1
    @State private var sessionsPerPage = 20
    @State private var totalPages = 1
    
    // Editing state
    @State private var showingDeleteAlert = false
    @State private var toDelete: SessionRecord? = nil
    
    // UI state
    @State private var isLoading = false
    @State private var showingExportAlert = false
    @State private var exportMessage = ""
    
    // Cached data
    @State private var filteredSessions: [SessionRecord] = []

    // MARK: — Computed helpers
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

    public var body: some View {
        VStack(spacing: 0) {
            // Main content area
            VStack(spacing: 0) {
                // Empty state or sessions list
                if filteredSessions.isEmpty {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView("Loading sessions...")
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("No sessions found")
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                        Spacer()
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    // ScrollView for sessions
                    ScrollView {
                        LazyVStack(spacing: Theme.spacingMedium) {
                            ForEach(filteredSessions, id: \.id) { session in
                                SessionCardView(
                                    session: session,
                                    projects: projectsViewModel.projects,
                                    onSave: {
                                        updateFilteredSessions()
                                    },
                                    onDelete: {
                                        toDelete = session
                                        showingDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding(Theme.spacingMedium)
                    }
                    .scrollContentBackground(.hidden)
                    
                    // Pagination controls
                    if totalPages > 1 {
                        HStack {
                            Button("Previous") {
                                goToPage(currentPage - 1)
                            }
                            .disabled(currentPage <= 1)
                            .buttonStyle(.secondary)
                            
                            Text("Page \(currentPage) of \(totalPages)")
                                .font(Theme.Fonts.caption)
                            
                            Button("Next") {
                                goToPage(currentPage + 1)
                            }
                            .disabled(currentPage >= totalPages)
                            .buttonStyle(.secondary)
                        }
                        .padding(.top)
                        .padding(.bottom, Theme.spacingMedium)
                    }
                }
            }
            .background(Theme.Colors.background)
            
            // Sticky filter header at the bottom
            VStack(spacing: 0) {
                // Filter controls
                HStack {
                    // Project filter
                    HStack {
                        Text("Project:")
                            .font(Theme.Fonts.caption)
                        Picker(selection: $projectFilter, label: EmptyView()) {
                            Text("All").tag("All")
                            ForEach(projectsViewModel.projects, id: \.id) { project in
                                Text(project.name).tag(project.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                        .onChange(of: projectFilter) { _ in
                            currentPage = 1 // Reset to first page on filter change
                            updateFilteredSessions()
                        }
                    }
                    
                    // Date filters
                    HStack(spacing: Theme.spacingSmall) {
                        Text("Date Range:")
                            .font(Theme.Fonts.caption)
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
        }
        .onAppear { handleDateFilterSelection(.thisWeek) }
        .alert("Export Complete", isPresented: $showingExportAlert) {
            Button("OK") { }
        } message: {
            Text(exportMessage)
        }
        .confirmationDialog("Delete Session", isPresented: $showingDeleteAlert, presenting: toDelete) { session in

            Button("Delete session for \"\(session.projectName)\"", role: .destructive) {
                deleteSession(session)
            }
        } message: { session in
             Text("Are you sure you want to delete the session for \"\(session.projectName)\" on \(session.date)? This action cannot be undone.")
        }
    }
    
    // MARK: - Data Functions
    
    /// ✅ REFACTORED: Now only responsible for pagination logic.
    private func updateFilteredSessions() {
        DispatchQueue.main.async {
            // 1. Start with the already filtered and sorted list
            let sessions = fullyFilteredSessions
            
            // 2. Calculate total pages based on the filtered list
            let totalSessions = sessions.count
            totalPages = max(1, Int(ceil(Double(totalSessions) / Double(sessionsPerPage))))
            
            // 3. Ensure current page is valid
            if currentPage > totalPages { currentPage = totalPages }
            
            // 4. Get the slice for the current page
            let startIndex = (currentPage - 1) * sessionsPerPage
            let endIndex = min(startIndex + sessionsPerPage, totalSessions)
            
            if startIndex < endIndex {
                self.filteredSessions = Array(sessions[startIndex..<endIndex])
            } else {
                self.filteredSessions = []
            }
        }
    }
    
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
            updateFilteredSessions()
        }
        toDelete = nil
    }
    
    // MARK: - Filter & Pagination
    
    private func handleDateFilterSelection(_ filter: DateFilter) {
        selectedDateFilter = filter
        
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        switch filter {
        case .today:
            let end = calendar.date(byAdding: .day, value: 1, to: todayStart)!
            currentDateInterval = DateInterval(start: todayStart, end: end)
        case .thisWeek:
            // Correctly goes back 6 days from today, covering a 7-day period.
            let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart)!
            let end = calendar.date(byAdding: .day, value: 1, to: todayStart)!
            currentDateInterval = DateInterval(start: weekStart, end: end)
        case .thisMonth:
            // Goes back 30 days from today.
            let monthStart = calendar.date(byAdding: .day, value: -29, to: todayStart)!
            let end = calendar.date(byAdding: .day, value: 1, to: todayStart)!
            currentDateInterval = DateInterval(start: monthStart, end: end)
        case .clear:
            currentDateInterval = nil
        }
        
        currentPage = 1
        updateFilteredSessions()
    }
    
    private func goToPage(_ page: Int) {
        guard page >= 1 && page <= totalPages else { return }
        currentPage = page
        updateFilteredSessions()
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
        VStack {
            
            SessionsView()
                .frame(width: 1000, height: 700)
                .background(Color(.windowBackgroundColor))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
