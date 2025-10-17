import SwiftUI
import Foundation

struct SessionsView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var projectsViewModel = ProjectsViewModel()
    
    // Filter state
    @State private var projectFilter = "All"
    @State private var searchText = ""
    
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
                        Picker("Project", selection: $projectFilter) {
                            Text("All").tag("All")
                            ForEach(projectsViewModel.projects, id: \.id) { project in
                                Text(project.name).tag(String(project.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                    
                    // Date filters
                    HStack {
                        Text("Date Range:")
                        Button("Today") {
                            filterByToday()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("This Week") {
                            filterByThisWeek()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("This Month") {
                            filterByThisMonth()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Clear") {
                            clearDateFilters()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Spacer()
                    
                    // Search field
                    TextField("Search sessions...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                    
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
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .frame(height: 200)
                } else {
                    // Grid view
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                            spacing: 16
                        ) {
                            ForEach(filteredSessions, id: \.id) { session in
                                SessionCardView(session: session) {
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
            loadSessions()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let session = editingSession {
                EditSessionView(session: session, projectNames: projectsViewModel.projects.map { $0.name })
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
    
    private func loadSessions() {
        isLoading = true
        
        // Load sessions on main thread for immediate feedback
        let sessions = sessionManager.loadAllSessions()
        isLoading = false
        updateFilteredSessions()
    }
    
    private func updateFilteredSessions() {
        DispatchQueue.main.async {
            // Apply filters
            var sessions = sessionManager.allSessions
            
            // Apply project filter
            if projectFilter != "All" {
                sessions = sessions.filter { $0.projectName == projectFilter }
            }
            
            // Apply search filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                sessions = sessions.filter { session in
                    session.projectName.lowercased().contains(searchLower) ||
                    session.notes.lowercased().contains(searchLower)
                }
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
    
    // Date filtering functions
    private func filterByToday() {
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: today)
        
        searchText = ""
        projectFilter = "All"
        
        // Filter by today's date
        var sessions = sessionManager.allSessions
        sessions = sessions.filter { $0.date == todayString }
        
        // Sort by date descending (most recent first)
        sessions.sort { session1, session2 in
            let date1 = parseDate(session1.date)
            let date2 = parseDate(session2.date)
            return date1 > date2
        }
        
        currentPage = 1
        filteredSessions = sessions
        totalPages = Int(ceil(Double(sessions.count) / Double(sessionsPerPage)))
    }
    
    private func filterByThisWeek() {
        let today = Date()
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.end ?? today
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        searchText = ""
        projectFilter = "All"
        
        // Filter by this week's dates
        var sessions = sessionManager.allSessions
        sessions = sessions.filter { session in
            guard let sessionDate = formatter.date(from: session.date) else { return false }
            return sessionDate >= startOfWeek && sessionDate <= endOfWeek
        }
        
        // Sort by date descending (most recent first)
        sessions.sort { session1, session2 in
            let date1 = parseDate(session1.date)
            let date2 = parseDate(session2.date)
            return date1 > date2
        }
        
        currentPage = 1
        filteredSessions = sessions
        totalPages = Int(ceil(Double(sessions.count) / Double(sessionsPerPage)))
    }
    
    private func filterByThisMonth() {
        let today = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        let endOfMonth = calendar.dateInterval(of: .month, for: today)?.end ?? today
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        searchText = ""
        projectFilter = "All"
        
        // Filter by this month's dates
        var sessions = sessionManager.allSessions
        sessions = sessions.filter { session in
            guard let sessionDate = formatter.date(from: session.date) else { return false }
            return sessionDate >= startOfMonth && sessionDate <= endOfMonth
        }
        
        // Sort by date descending (most recent first)
        sessions.sort { session1, session2 in
            let date1 = parseDate(session1.date)
            let date2 = parseDate(session2.date)
            return date1 > date2
        }
        
        currentPage = 1
        filteredSessions = sessions
        totalPages = Int(ceil(Double(sessions.count) / Double(sessionsPerPage)))
    }
    
    private func clearDateFilters() {
        searchText = ""
        projectFilter = "All"
        currentPage = 1
        updateFilteredSessions()
    }
    
    // Pagination functions
    private func goToPage(_ page: Int) {
        guard page >= 1 && page <= totalPages else { return }
        currentPage = page
        updateFilteredSessions()
    }
}

// Session card component for grid view
struct SessionCardView: View {
    let session: SessionRecord
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date and project
            HStack {
                Text(session.date)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text(session.projectName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Duration
            HStack {
                Image(systemName: "clock")
                Text(formatDuration(session.durationMinutes))
                    .font(.caption)
                Spacer()
                // Mood
                if let mood = session.mood {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("\(mood)")
                            .font(.caption)
                    }
                    .foregroundColor(mood > 5 ? .green : mood > 2 ? .orange : .red)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // Notes (truncated)
            if !session.notes.isEmpty {
                Text(session.notes)
                    .font(.caption)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .foregroundColor(.secondary)
            }
            
            // Time range
            HStack {
                Image(systemName: "play")
                Text(String(session.startTime.prefix(5)))
                    .font(.caption)
                Spacer()
                Image(systemName: "stop")
                Text(String(session.endTime.prefix(5)))
                    .font(.caption)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Spacer()
            
            // Action buttons
            HStack {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .border(Color.gray.opacity(0.3), width: 1)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }
}

struct EditSessionView: View {
    let session: SessionRecord
    let projectNames: [String]
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedDate: String = ""
    @State private var editedStartTime: String = "09:00"
    @State private var editedEndTime: String = "17:00"
    @State private var editedProject: String = ""
    @State private var editedNotes: String = ""
    @State private var selectedMood: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Date
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date")
                            .font(.headline)
                        TextField("YYYY-MM-DD", text: $editedDate)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Times
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Times")
                            .font(.headline)
                        HStack(spacing: 16) {
                            TextField("Start", text: $editedStartTime)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 100)
                            TextField("End", text: $editedEndTime)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 100)
                        }
                    }
                    
                    // Project
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Project")
                            .font(.headline)
                        Picker("Project", selection: $editedProject) {
                            Text("-- Select Project --").tag("")
                            ForEach(projectNames, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.headline)
                        TextEditor(text: $editedNotes)
                            .frame(height: 100)
                            .border(Color.gray.opacity(0.3), width: 1)
                            .cornerRadius(4)
                    }
                    
                    // Mood
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mood (0-10)")
                            .font(.headline)
                        Picker("Mood", selection: $selectedMood) {
                            Text("-- No mood --").tag("")
                            ForEach(0...10, id: \.self) { mood in
                                Text("\(mood)").tag("\(mood)")
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSession()
                    }
                    .disabled(editedProject.isEmpty)
                }
            }
        }
        .onAppear {
            editedDate = session.date
            editedStartTime = String(session.startTime.prefix(5))
            editedEndTime = String(session.endTime.prefix(5))
            editedProject = session.projectName
            editedNotes = session.notes
            selectedMood = session.mood.map { "\($0)" } ?? ""
        }
    }
    
    private func saveSession() {
        _ = SessionManager.shared.updateSessionFull(
            id: session.id,
            date: editedDate,
            startTime: editedStartTime + ":00",
            endTime: editedEndTime + ":00",
            projectName: editedProject,
            notes: editedNotes,
            mood: selectedMood.isEmpty ? nil : Int(selectedMood)
        )
        
        dismiss()
    }
}
