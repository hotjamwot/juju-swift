import SwiftUI
import Foundation

/// Main view for displaying and managing sessions
public struct SessionsView: View {
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

// MARK: — Computed helpers
private var fullyFilteredSessions: [SessionRecord] {
    // 1️⃣ Grab *all* raw sessions
    var sessions = sessionManager.allSessions

    // 2️⃣ Apply the *date* filter (only keep sessions inside currentDateInterval)
    if let interval = currentDateInterval {
        sessions = sessions.filter { session in
            guard let start = session.startDateTime else { return false }
            return interval.contains(start)
        }
    }

    // 3️⃣ Apply the *project* filter
    if projectFilter != "All" {
        sessions = sessions.filter { $0.projectName == projectFilter }
    }

    // 4️⃣ Re‑sort by most‑recent first – the same order the UI shows
    sessions.sort(by: { ($0.startDateTime ?? Date.distantPast) > ($1.startDateTime ?? Date.distantPast) })

    // 5️⃣ Return everything (no pagination!)
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
                    .frame(height: 400)
                    .background(Theme.Colors.background)
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
                                .fontWeight(.medium)
                        }
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(.horizontal, Theme.spacingMedium)
                        .padding(.vertical, Theme.spacingSmall)
                        .background(Theme.Colors.accent)
                        .cornerRadius(Theme.Design.cornerRadius)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { isHovered in
                        if isHovered {
                            NSCursor.pointingHand.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                }
                .padding()
                .background(Theme.Colors.surface)
            }
        }
        .background(Theme.Colors.background)
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
            sessions.sort(by: { ($0.startDateTime ?? Date.distantPast) > ($1.startDateTime ?? Date.distantPast) })
            
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
    // ←‑ Change this line
    let sessions = fullyFilteredSessions   // 🚨 NEW

    guard !sessions.isEmpty else {
        exportMessage = "Nothing to export – no sessions match the current filter."
        showingExportAlert = true
        return
    }

    if let path = sessionManager.exportSessions(sessions, format: format) {
        exportMessage = "Sessions exported to \(path.path)"
        showingExportAlert = true
    } else {
        exportMessage = "Export failed."
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

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct SessionsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SessionsView()
                .frame(width: 800, height: 600)
                .background(Color(.windowBackgroundColor))
            
            Divider()
            
            SessionsView()
                .frame(width: 1000, height: 700)
                .background(Color(.windowBackgroundColor))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
