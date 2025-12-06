import SwiftUI

/// Sidebar view for editing session details with a clean, spacious layout
struct SessionSidebarEditView: View {
    @StateObject private var sidebarState = SidebarStateManager()
    @StateObject private var sessionManager = SessionManager.shared
    
    @State private var session: SessionRecord
    @State private var tempStartTime: Date
    @State private var tempEndTime: Date
    @State private var tempNotes: String
    @State private var tempMood: Int
    @State private var tempProjectName: String
    
    // Projects for the picker
    @StateObject private var projectsViewModel = ProjectsViewModel()
    
    // Form validation
    @State private var hasChanges = false
    @State private var isSaving = false
    
    init(session: SessionRecord) {
        self._session = State(initialValue: session)
        
        // Convert string times to Date objects
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let paddedStartTime = session.startTime.count == 5 ? session.startTime + ":00" : session.startTime
        let paddedEndTime = session.endTime.count == 5 ? session.endTime + ":00" : session.endTime
        
        let date = dateFormatter.date(from: session.date) ?? Date()
        let startTime = timeFormatter.date(from: paddedStartTime) ?? Date()
        let endTime = timeFormatter.date(from: paddedEndTime) ?? Date()
        
        // Combine date and time
        var startComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let startComponentsTime = Calendar.current.dateComponents([.hour, .minute, .second], from: startTime)
        startComponents.hour = startComponentsTime.hour
        startComponents.minute = startComponentsTime.minute
        startComponents.second = startComponentsTime.second ?? 0
        let finalStartTime = Calendar.current.date(from: startComponents) ?? Date()
        
        var endComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let endComponentsTime = Calendar.current.dateComponents([.hour, .minute, .second], from: endTime)
        endComponents.hour = endComponentsTime.hour
        endComponents.minute = endComponentsTime.minute
        endComponents.second = endComponentsTime.second ?? 0
        let finalEndTime = Calendar.current.date(from: endComponents) ?? Date()
        
        self._tempStartTime = State(initialValue: finalStartTime)
        self._tempEndTime = State(initialValue: finalEndTime)
        self._tempNotes = State(initialValue: session.notes)
        self._tempMood = State(initialValue: session.mood ?? 0)
        self._tempProjectName = State(initialValue: session.projectName)
    }
    
    var body: some View {
        VStack(spacing: Theme.spacingMedium) {
            // Time controls section
            timeControlsSection
            
            // Project selection section
            projectSelectionSection
            
            // Notes section
            notesSection
            
            // Mood section
            moodSection
            
            // Action buttons
            actionButtons
        }
        .formStyle(.grouped)
        .task {
            await projectsViewModel.loadProjects()
        }
        .onChange(of: tempStartTime) { _ in validateChanges() }
        .onChange(of: tempEndTime) { _ in validateChanges() }
        .onChange(of: tempNotes) { _ in validateChanges() }
        .onChange(of: tempMood) { _ in validateChanges() }
        .onChange(of: tempProjectName) { _ in validateChanges() }
    }
    
    private var timeControlsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Time")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                HStack {
                    VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                        Text("Start Time")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        DatePicker(
                            "Start Time",
                            selection: $tempStartTime,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                        Text("End Time")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        DatePicker(
                            "End Time",
                            selection: $tempEndTime,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                    }
                }
                
                // Duration display
                HStack {
                    Text("Duration:")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    Text(durationString)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }
            .padding()
        }
        .background(Theme.Colors.surface)
        .cornerRadius(8)
    }
    
    private var projectSelectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Project")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Picker("Project", selection: $tempProjectName) {
                    Text("No Project").tag("")
                    ForEach(projectsViewModel.projects.filter { !$0.archived }) { project in
                        HStack {
                            Text(project.emoji)
                            Text(project.name)
                        }
                        .tag(project.name)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            .padding()
        }
        .background(Theme.Colors.surface)
        .cornerRadius(8)
    }
    
    private var notesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Notes")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                TextEditor(text: $tempNotes)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Theme.Colors.background)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
            }
            .padding()
        }
        .background(Theme.Colors.surface)
        .cornerRadius(8)
    }
    
    private var moodSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Mood")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                HStack {
                    ForEach(0..<11, id: \.self) { moodValue in
                        Button(action: {
                            tempMood = moodValue
                        }) {
                            VStack {
                                Circle()
                                    .fill(moodColor(for: moodValue))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(Theme.Colors.divider, lineWidth: 1)
                                    )
                                Text("\(moodValue)")
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .scaleEffect(tempMood == moodValue ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: tempMood)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if moodValue < 10 {
                            Spacer()
                        }
                    }
                }
            }
            .padding()
        }
        .background(Theme.Colors.surface)
        .cornerRadius(8)
    }
    
    private var actionButtons: some View {
        HStack {
            Button("Cancel") {
                sidebarState.hide()
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Spacer()
            
            Button("Save") {
                saveSession()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!hasChanges || isSaving)
            .opacity(hasChanges ? 1.0 : 0.5)
        }
        .padding(.horizontal)
    }
    
    private var durationString: String {
        let duration = tempEndTime.timeIntervalSince(tempStartTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    private func moodColor(for mood: Int) -> Color {
        // Color gradient from red (0) to green (10)
        let red = Double(10 - mood) / 10.0
        let green = Double(mood) / 10.0
        return Color(red: red, green: green, blue: 0.2)
    }
    
    private func validateChanges() {
        // Convert session's string times to Date for comparison
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let paddedStartTime = session.startTime.count == 5 ? session.startTime + ":00" : session.startTime
        let paddedEndTime = session.endTime.count == 5 ? session.endTime + ":00" : session.endTime
        
        let date = dateFormatter.date(from: session.date) ?? Date()
        let startTime = timeFormatter.date(from: paddedStartTime) ?? Date()
        let endTime = timeFormatter.date(from: paddedEndTime) ?? Date()
        
        // Combine date and time
        var startComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let startComponentsTime = Calendar.current.dateComponents([.hour, .minute, .second], from: startTime)
        startComponents.hour = startComponentsTime.hour
        startComponents.minute = startComponentsTime.minute
        startComponents.second = startComponentsTime.second ?? 0
        let sessionStartTime = Calendar.current.date(from: startComponents) ?? Date()
        
        var endComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let endComponentsTime = Calendar.current.dateComponents([.hour, .minute, .second], from: endTime)
        endComponents.hour = endComponentsTime.hour
        endComponents.minute = endComponentsTime.minute
        endComponents.second = endComponentsTime.second ?? 0
        let sessionEndTime = Calendar.current.date(from: endComponents) ?? Date()
        
        hasChanges = (
            tempStartTime != sessionStartTime ||
            tempEndTime != sessionEndTime ||
            tempNotes != session.notes ||
            tempMood != (session.mood ?? 0) ||
            tempProjectName != session.projectName
        )
    }
    
    private func saveSession() {
        isSaving = true
        
        // Convert Date objects back to strings
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let date = dateFormatter.string(from: tempStartTime)
        let startTime = timeFormatter.string(from: tempStartTime)
        let endTime = timeFormatter.string(from: tempEndTime)
        
        // Calculate duration
        let durationMinutes = Int(tempEndTime.timeIntervalSince(tempStartTime) / 60)
        
        // Save using SessionManager
        let success = sessionManager.updateSessionFull(
            id: session.id,
            date: date,
            startTime: startTime,
            endTime: endTime,
            projectName: tempProjectName,
            notes: tempNotes,
            mood: tempMood
        )
        
        if success {
            // Update local session copy
            session = SessionRecord(
                id: session.id,
                date: date,
                startTime: startTime,
                endTime: endTime,
                durationMinutes: durationMinutes,
                projectName: tempProjectName,
                projectID: session.projectID,
                activityTypeID: session.activityTypeID,
                projectPhaseID: session.projectPhaseID,
                milestoneText: session.milestoneText,
                notes: tempNotes,
                mood: tempMood
            )
            hasChanges = false
            
            // Close sidebar after successful save
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                sidebarState.hide()
            }
        } else {
            // Handle error (could show alert)
            print("Failed to save session")
        }
        
        isSaving = false
    }
}

    // MARK: - Preview
    #if DEBUG
    @available(macOS 12.0, *)
    struct SessionSidebarEditView_Previews: PreviewProvider {
        static var previews: some View {
            let now = Date()
            let startDate = Calendar.current.date(byAdding: .hour, value: -2, to: now)!
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            
            let sampleDate = dateFormatter.string(from: now)
            let sampleStartTime = timeFormatter.string(from: startDate)
            let sampleEndTime = timeFormatter.string(from: now)
            let duration = Int(now.timeIntervalSince(startDate) / 60)
            
            let sampleSession = SessionRecord(
                id: UUID().uuidString,
                date: sampleDate,
                startTime: sampleStartTime,
                endTime: sampleEndTime,
                durationMinutes: duration,
                projectName: "Sample Project",
                notes: "This is a sample session with some notes about the work done.",
                mood: 7
            )
            
            return SessionSidebarEditView(session: sampleSession)
                .environmentObject(SidebarStateManager())
                .environmentObject(SessionManager.shared)
                .frame(width: 420)
                .padding()
        }
    }
    #endif
