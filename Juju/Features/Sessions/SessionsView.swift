import SwiftUI
import Foundation

// MARK: - Session Filter Button Style
struct SessionFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Fonts.caption)
                .lineLimit(1)
                .padding(.horizontal, Theme.spacingSmall)
                .padding(.vertical, Theme.spacingExtraSmall)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .fill(isSelected ? Theme.Colors.accent : Theme.Colors.surface)
                        if isSelected {
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .fill(Theme.Colors.accent.opacity(0.9))
                                .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 6, x: 0, y: 2)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                )
                .foregroundColor(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: Theme.Design.animationDuration), value: isSelected)
    }
}

// MARK: - Date Filter Options
enum DateFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case clear = "Clear"
    
    var id: String { rawValue }
    
    var title: String { rawValue }
}

struct SessionsView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var projectsViewModel = ProjectsViewModel()
    
    // Filter state
    @State private var projectFilter = "All"
    @State private var selectedDateFilter: DateFilter = .thisWeek
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
    
    var body: some View {
        VStack(spacing: Theme.spacingMedium) {
            // Header with filters and actions
            VStack(spacing: Theme.spacingSmall) {
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
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .fill(Theme.Colors.surface)
                        )
                        .onChange(of: projectFilter) { _ in
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
                                action: {
                                    handleDateFilterSelection(filter)
                                }
                            )
                        }
                    }
                    
                    Spacer()
                    
                    // Export button
                    Menu {
                        Button("Export as CSV") {
                            exportSessions(format: "csv")
                        }
                        Button("Export as Text") {
                            exportSessions(format: "txt")
                        }
                        Button("Export as Markdown") {
                            exportSessions(format: "md")
                        }
                    } label: {
                        HStack(spacing: Theme.spacingExtraSmall) {
                            Image(systemName: "square.and.arrow.down")
                                .font(Theme.Fonts.icon)
                            Text("Export")
                                .font(Theme.Fonts.caption)
                        }
                        .padding(.horizontal, Theme.spacingSmall)
                        .padding(.vertical, Theme.spacingExtraSmall)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .fill(Theme.Colors.accent)
                        )
                        .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .frame(width: 100)
                }
                
                // Pagination info
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
                    .frame(height: 200)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Design.cornerRadius)
                } else {
                    // Grid view
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: Theme.spacingSmall), count: 1),
                            spacing: Theme.spacingMedium
                        ) {
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
                                if currentPage > 1 {
                                    currentPage -= 1
                                    updateFilteredSessions()
                                }
                            }
                            .disabled(currentPage <= 1)
                            .buttonStyle(.bordered)
                            
                            Text("Page \(currentPage) of \(totalPages)")
                                .font(Theme.Fonts.caption)
                            
                            Button("Next") {
                                if currentPage < totalPages {
                                    currentPage += 1
                                    updateFilteredSessions()
                                }
                            }
                            .disabled(currentPage >= totalPages)
                            .buttonStyle(.bordered)
                        }
                        .padding(.top)
                    }
                }
            }
        }
        .padding(Theme.spacingMedium)
        .task {
            await projectsViewModel.loadProjects()
        }
        .onAppear {
            let today = Date()
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: today)
            let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart)!
            let end = calendar.date(byAdding: .day, value: 1, to: todayStart)!
            currentDateInterval = DateInterval(start: weekStart, end: end)
            projectFilter = "All"
            currentPage = 1
            selectedDateFilter = .thisWeek
            updateFilteredSessions()
        }
        .alert("Export Complete", isPresented: $showingExportAlert) {
            Button("OK") { }
        } message: {
            Text(exportMessage)
        }
        .confirmationDialog("Delete Session", isPresented: $showingDeleteAlert) {
            if let session = toDelete {
                Text("Are you sure you want to delete the session for \"\(session.projectName)\" on \(session.date)?")
                Button("Delete", role: .destructive) {
                    deleteSession(session)
                }
                Button("Cancel", role: .cancel) { 
                    toDelete = nil
                }
            }
        }
    }


            /// Turns a SessionRecord into a Date that represents the session’s
            /// *start* moment (date + time).
            private func startDateTime(_ session: SessionRecord) -> Date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"          // include seconds to match CSV format
                formatter.timeZone = TimeZone.current            // or .utc if your data is UTC
             let combined = "\(session.date) \(session.startTime)"
          return formatter.date(from: combined) ?? Date()
            }
    
    
    private func updateFilteredSessions() {
        DispatchQueue.main.async {
            let loadedSessions: [SessionRecord]
            if let interval = currentDateInterval {
                loadedSessions = sessionManager.loadSessions(in: interval)
            } else {
                loadedSessions = sessionManager.allSessions
            }
            
            var sessions = loadedSessions
            
            // Apply project filter
            if projectFilter != "All" {
                sessions = sessions.filter { $0.projectName == projectFilter }
            }
            
            // Sort by date descending (most recent first)
            sessions.sort { startDateTime($0) > startDateTime($1) }

            
            // Update pagination
            let totalSessions = sessions.count
            totalPages = Int(ceil(Double(totalSessions) / Double(sessionsPerPage)))
            
            // Ensure current page is valid
            if currentPage > totalPages && totalPages > 0 {
                currentPage = totalPages
            } else if currentPage < 1 {
                currentPage = 1
            }
            
            // Get paginated sessions
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
        let sessions = sessionManager.allSessions
        
        if let path = sessionManager.exportSessions(sessions, format: format) {
            exportMessage = "Sessions exported to \(path.path)"
            showingExportAlert = true
        } else {
            exportMessage = "Export failed. No sessions to export."
            showingExportAlert = true
        }
    }
    
    private func deleteSession(_ session: SessionRecord) {
        if sessionManager.deleteSession(id: session.id) {
            // Update the list
            DispatchQueue.main.async {
                updateFilteredSessions()
            }
        }
        toDelete = nil
    }
    
    private func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString) ?? Date()
    }
    
    // Pagination functions
    private func handleDateFilterSelection(_ filter: DateFilter) {
        selectedDateFilter = filter
        
        switch filter {
        case .today:
            let today = Date()
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: today)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            currentDateInterval = DateInterval(start: start, end: end)
        case .thisWeek:
            let today = Date()
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: today)
            let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart)!
            let end = calendar.date(byAdding: .day, value: 1, to: todayStart)!
            currentDateInterval = DateInterval(start: weekStart, end: end)
        case .thisMonth:
            let today = Date()
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: today)
            let monthStart = calendar.date(byAdding: .day, value: -30, to: todayStart)!
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
}
