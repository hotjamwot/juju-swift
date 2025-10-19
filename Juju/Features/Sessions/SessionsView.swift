import SwiftUI
import Foundation

struct SessionsView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var projectsViewModel = ProjectsViewModel()
    
    // Filter state
    @State private var projectFilter = "All"
    @State private var currentDateInterval: DateInterval? = nil
    
    // Pagination state
    @State private var currentPage = 1
    @State private var sessionsPerPage = 20
    @State private var totalPages = 1
    
    // Editing state
    @State private var editingSession: SessionRecord? = nil
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var toDelete: SessionRecord? = nil
    
    // UI state
    @State private var isLoading = false
    @State private var showingExportAlert = false
    @State private var exportMessage = ""
    
    // Cached data
    @State private var filteredSessions: [SessionRecord] = []
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with filters and actions
            VStack(spacing: 12) {
                // Filter controls
                HStack {
                    // Project filter
                    HStack {
                        Text("Project:")
                        Picker(selection: $projectFilter, label: EmptyView()) {
                            Text("All").tag("All")
                            ForEach(projectsViewModel.projects, id: \.id) { project in
                                Text(project.name).tag(project.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                        .onChange(of: projectFilter) { _ in
                            updateFilteredSessions()
                        }
                    }
                    
                    // Date filters
                    HStack {
                        Text("Date Range:")
                        Button("Today") {
                            let today = Date()
                            let calendar = Calendar.current
                            let start = calendar.startOfDay(for: today)
                            let end = calendar.date(byAdding: .day, value: 1, to: start)!
                            currentDateInterval = DateInterval(start: start, end: end)
                            currentPage = 1
                            updateFilteredSessions()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("This Week") {
                            let today = Date()
                            let calendar = Calendar.current
                            let todayStart = calendar.startOfDay(for: today)
                            let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart)!
                            let end = calendar.date(byAdding: .day, value: 1, to: todayStart)!
                            currentDateInterval = DateInterval(start: weekStart, end: end)
                            currentPage = 1
                            updateFilteredSessions()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("This Month") {
                            let today = Date()
                            let calendar = Calendar.current
                            let todayStart = calendar.startOfDay(for: today)
                            let monthStart = calendar.date(byAdding: .day, value: -30, to: todayStart)!
                            let end = calendar.date(byAdding: .day, value: 1, to: todayStart)!
                            currentDateInterval = DateInterval(start: monthStart, end: end)
                            currentPage = 1
                            updateFilteredSessions()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Clear") {
                            currentDateInterval = nil
                            projectFilter = "All"
                            currentPage = 1
                            updateFilteredSessions()
                        }
                        .buttonStyle(.borderedProminent)
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
                        Image(systemName: "square.and.arrow.down")
                        Text("Export")
                    }
                    .buttonStyle(.bordered)
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
                                .foregroundColor(.foreground)
                        }
                        Spacer()
                    }
                    .frame(height: 200)
                } else {
                    // Grid view
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 1),
                            spacing: 16
                        ) {
                            ForEach(filteredSessions, id: \.id) { session in
                                SessionCardView(session: session, projects: projectsViewModel.projects) {
                                    editingSession = session
                                    showingEditSheet = true
                                } onDelete: {
                                    toDelete = session
                                    showingDeleteAlert = true
                                }
                            }
                        }
                        .padding()
                    }
                    
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
                                .font(.caption)
                            
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
        .padding()
        .onAppear {
            let today = Date()
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: today)
            let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart)!
            let end = calendar.date(byAdding: .day, value: 1, to: todayStart)!
            currentDateInterval = DateInterval(start: weekStart, end: end)
            projectFilter = "All"
            currentPage = 1
            updateFilteredSessions()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let session = editingSession {
                EditSessionView(session: session, projectNames: projectsViewModel.projects.map { $0.name })
            }
        }
        .onChange(of: showingEditSheet) { newValue in
            if !newValue {
                updateFilteredSessions()
            }
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
            sessions.sort { session1, session2 in
                let date1 = parseDate(session1.date)
                let date2 = parseDate(session2.date)
                return date1 > date2
            }
            
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
    private func goToPage(_ page: Int) {
        guard page >= 1 && page <= totalPages else { return }
        currentPage = page
        updateFilteredSessions()
    }
}
