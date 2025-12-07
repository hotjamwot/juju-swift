import SwiftUI

/// Sidebar view for editing session details with a clean, spacious layout
struct SessionSidebarEditView: View {
    @EnvironmentObject var sidebarState: SidebarStateManager
    @EnvironmentObject var sessionManager: SessionManager
    
    @State private var session: SessionRecord
    @State private var tempStartTime: Date
    @State private var tempEndTime: Date
    @State private var tempNotes: String
    @State private var tempMood: Int
    @State private var tempProjectName: String
    @State private var tempActivityTypeID: String
    @State private var tempProjectPhaseID: String?
    @State private var tempMilestoneText: String
    
    // Time picker state properties
    @State private var startHour: Int = 0
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 0
    @State private var endMinute: Int = 0
    
    // Projects for the picker
    @EnvironmentObject var projectsViewModel: ProjectsViewModel
    @EnvironmentObject var activityTypesViewModel: ActivityTypesViewModel
    
    // Form validation
    @State private var hasChanges = false
    @State private var isSaving = false
    
    // Add a binding to trigger refresh in parent
    let onSessionUpdated: (() -> Void)?
    
    init(session: SessionRecord, onSessionUpdated: (() -> Void)? = nil) {
        self.onSessionUpdated = onSessionUpdated
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
        
        // Set initial hour and minute values for time pickers
        let tempStartComponents = Calendar.current.dateComponents([.hour, .minute], from: finalStartTime)
        let tempEndComponents = Calendar.current.dateComponents([.hour, .minute], from: finalEndTime)
        
        self._startHour = State(initialValue: tempStartComponents.hour ?? 0)
        self._startMinute = State(initialValue: tempStartComponents.minute ?? 0)
        self._endHour = State(initialValue: tempEndComponents.hour ?? 0)
        self._endMinute = State(initialValue: tempEndComponents.minute ?? 0)
        
        self._tempStartTime = State(initialValue: finalStartTime)
        self._tempEndTime = State(initialValue: finalEndTime)
        self._tempNotes = State(initialValue: session.notes)
        self._tempMood = State(initialValue: session.mood ?? 0)
        self._tempProjectName = State(initialValue: session.projectName)
        self._tempActivityTypeID = State(initialValue: session.activityTypeID ?? "")
        self._tempProjectPhaseID = State(initialValue: session.projectPhaseID)
        self._tempMilestoneText = State(initialValue: session.milestoneText ?? "")
    }
    
    var body: some View {
        VStack(spacing: Theme.spacingExtraLarge) {
            // Top section - project selection, notes, and time controls
            VStack(spacing: Theme.spacingExtraLarge) {
                // Project selection section
                projectSelectionSection
                
                // Notes section
                notesSection
                
                // Time controls section
                timeControlsSection
            }
            
            Spacer()
            
            // Bottom section - mood and action buttons
            VStack(spacing: Theme.spacingExtraLarge) {
                // Mood section
                moodSection
                
                // Action buttons
                actionButtons
            }
        }
        .padding(Theme.spacingLarge)
        .task {
            await projectsViewModel.loadProjects()
        }
        .onChange(of: tempStartTime) { _ in validateChanges() }
        .onChange(of: tempEndTime) { _ in validateChanges() }
        .onChange(of: tempNotes) { _ in validateChanges() }
        .onChange(of: tempMood) { _ in validateChanges() }
        .onChange(of: tempProjectName) { _ in 
            // When project changes, validate phase selection and reset if invalid
            validateAndResetPhaseIfInvalid()
            validateChanges() 
        }
        .onChange(of: tempActivityTypeID) { _ in validateChanges() }
        .onChange(of: tempProjectPhaseID) { _ in validateChanges() }
        .onChange(of: tempMilestoneText) { _ in validateChanges() }
    }
    
    private var timeControlsSection: some View {
        VStack(spacing: Theme.spacingLarge) {
            // Date picker
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Date")
                    .font(.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                DatePicker(
                    "",
                    selection: $tempStartTime,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .labelsHidden()
            }
            
            // Start and End time dropdowns - reorganized for better space usage
            VStack(spacing: Theme.spacingMedium) {
                // Start Time dropdown
                HStack {
                    Text("Start Time")
                        .font(.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    // Hour picker
                    Picker("Hour", selection: Binding(
                        get: { startHour },
                        set: { startHour = $0; updateStartTime() }
                    )) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 100)
                    
                    Text(":")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    // Minute picker
                    Picker("Minute", selection: Binding(
                        get: { startMinute },
                        set: { startMinute = $0; updateStartTime() }
                    )) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 100)
                }
                
                // End Time dropdown
                HStack {
                    Text("End Time")
                        .font(.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    // Hour picker
                    Picker("Hour", selection: Binding(
                        get: { endHour },
                        set: { endHour = $0; updateEndTime() }
                    )) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 100)
                    
                    Text(":")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    // Minute picker
                    Picker("Minute", selection: Binding(
                        get: { endMinute },
                        set: { endMinute = $0; updateEndTime() }
                    )) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 100)
                }
            }
        }
        .padding(Theme.spacingMedium)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
    }
    
    private var projectSelectionSection: some View {
        VStack(spacing: Theme.spacingLarge) {
            // Project selection
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Picker("Project", selection: $tempProjectName) {
                    Text("No Project").tag("")
                    ForEach(projectsViewModel.projects.filter { !$0.archived }) { project in
                        Text("\(project.emoji) \(project.name)").tag(project.name)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Activity Type selection
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Picker("Activity Type", selection: $tempActivityTypeID) {
                    Text("Select Activity Type").tag("")
                    ForEach(activityTypesViewModel.activeActivityTypes, id: \.id) { activityType in
                        Text("\(activityType.emoji) \(activityType.name)").tag(activityType.id)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Phase selection (based on selected project)
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                if let selectedProject = projectsViewModel.projects.first(where: { $0.name == tempProjectName }) {
                    Picker("Phase", selection: $tempProjectPhaseID) {
                        Text("No Phase").tag(nil as String?)
                        ForEach(selectedProject.phases.filter { !$0.archived }, id: \.id) { phase in
                            Text(phase.name).tag(phase.id as String?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(height: 40)
                } else if !tempProjectName.isEmpty {
                    // Show placeholder when project has no phases
                    Text("No phases available")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Theme.Colors.surface)
                        .cornerRadius(Theme.Design.cornerRadius)
                } else {
                    // Show placeholder when no project selected
                    Text("Select a project first")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Theme.Colors.surface)
                        .cornerRadius(Theme.Design.cornerRadius)
                }
            }
            
            // Milestone field with star emoji
            HStack(spacing: 8) {
                Text("⭐")
                TextField("Enter milestone", text: $tempMilestoneText)
                    .textFieldStyle(.plain)
                    .padding(Theme.spacingSmall)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Design.cornerRadius)
            }
        }
        .padding(Theme.spacingMedium)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            Text("Notes")
                .font(.body)
                .foregroundColor(Theme.Colors.textSecondary)
            TextEditor(text: $tempNotes)
                .font(.body)
                .frame(minHeight: 120, maxHeight: 160)
                .textFieldStyle(.plain)
                .padding(Theme.spacingSmall)
                .background(Theme.Colors.surface)
                .cornerRadius(Theme.Design.cornerRadius)
                .frame(maxWidth: .infinity)
        }
        .padding(Theme.spacingMedium)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
    }
    
    private var moodSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            HStack {
                Text("Mood")
                    .font(.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                Spacer()
                Text("\(tempMood)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            
            Slider(value: Binding(
                get: { Double(tempMood) },
                set: { tempMood = Int($0) }
            ), in: 0...10, step: 1)
            .accentColor(moodColor(for: tempMood))
        }
        .padding(Theme.spacingMedium)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
    }
    
    private var actionButtons: some View {
        HStack(spacing: Theme.spacingSmall) {
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
        .padding(Theme.spacingMedium)
        .padding(.bottom, Theme.spacingLarge)
    }
    
    // Update computed properties to use @State values
    private var startHourBinding: Int {
        get { startHour }
        set { 
            startHour = newValue
            updateStartTime()
        }
    }
    
    private var startMinuteBinding: Int {
        get { startMinute }
        set { 
            startMinute = newValue
            updateStartTime()
        }
    }
    
    private var endHourBinding: Int {
        get { endHour }
        set { 
            endHour = newValue
            updateEndTime()
        }
    }
    
    private var endMinuteBinding: Int {
        get { endMinute }
        set { 
            endMinute = newValue
            updateEndTime()
        }
    }
    
    private func updateStartTime() {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: tempStartTime)
        tempStartTime = Calendar.current.date(from: DateComponents(year: components.year, month: components.month, day: components.day, hour: startHour, minute: startMinute)) ?? tempStartTime
    }
    
    private func updateEndTime() {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: tempEndTime)
        tempEndTime = Calendar.current.date(from: DateComponents(year: components.year, month: components.month, day: components.day, hour: endHour, minute: endMinute)) ?? tempEndTime
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
        
        // Check if any field has changed from the original session
        let startTimeChanged = tempStartTime != sessionStartTime
        let endTimeChanged = tempEndTime != sessionEndTime
        let notesChanged = tempNotes != session.notes
        let moodChanged = tempMood != (session.mood ?? 0)
        let projectChanged = tempProjectName != session.projectName
        let activityTypeChanged = tempActivityTypeID != (session.activityTypeID ?? "")
        
        // Improved phase change detection - handle nil values properly
        let phaseChanged: Bool
        if let tempPhase = tempProjectPhaseID, let originalPhase = session.projectPhaseID {
            // Both have values, compare them
            phaseChanged = tempPhase != originalPhase
        } else if tempProjectPhaseID == nil && session.projectPhaseID == nil {
            // Both are nil (no phase selected), no change
            phaseChanged = false
        } else {
            // One is nil and the other isn't, definitely changed
            phaseChanged = true
        }
        
        let milestoneChanged = tempMilestoneText != (session.milestoneText ?? "")
        
        hasChanges = (
            startTimeChanged ||
            endTimeChanged ||
            notesChanged ||
            moodChanged ||
            projectChanged ||
            activityTypeChanged ||
            phaseChanged ||
            milestoneChanged
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
        
        // Debug logging
        print("🔍 Saving session with phase ID: \(tempProjectPhaseID ?? "nil")")
        print("🔍 Project name: \(tempProjectName)")
        print("🔍 All projects count: \(projectsViewModel.projects.count)")
        
        // Validate phase selection against current project
        var validatedPhaseID: String? = tempProjectPhaseID
        
        if let selectedProject = projectsViewModel.projects.first(where: { $0.name == tempProjectName }) {
            print("🔍 Found project: \(selectedProject.name)")
            print("🔍 Project phases count: \(selectedProject.phases.count)")
            
            if let phaseID = tempProjectPhaseID {
                let phaseExists = selectedProject.phases.contains { $0.id == phaseID && !$0.archived }
                print("🔍 Phase \(phaseID) exists: \(phaseExists)")
                
                if !phaseExists {
                    // Phase doesn't exist in current project, clear it
                    validatedPhaseID = nil
                    print("⚠️ Selected phase \(phaseID) not found in project \(tempProjectName), clearing phase selection")
                }
            }
        } else if !tempProjectName.isEmpty {
            print("⚠️ Project \(tempProjectName) not found in projects list")
        }
        
        // Save using SessionManager
        print("🔍 Attempting to save session with:")
        print("  - ID: \(session.id)")
        print("  - Phase ID: \(validatedPhaseID ?? "nil")")
        print("  - Project: \(tempProjectName)")
        print("  - Activity Type: \(tempActivityTypeID.isEmpty ? "nil" : tempActivityTypeID)")
        
        let success = sessionManager.updateSessionFull(
            id: session.id,
            date: date,
            startTime: startTime,
            endTime: endTime,
            projectName: tempProjectName,
            notes: tempNotes,
            mood: tempMood,
            activityTypeID: tempActivityTypeID.isEmpty ? nil : tempActivityTypeID,
            projectPhaseID: validatedPhaseID,
            milestoneText: tempMilestoneText.isEmpty ? nil : tempMilestoneText
        )
        
        print("🔍 Save result: \(success ? "SUCCESS" : "FAILED")")
        
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
                activityTypeID: tempActivityTypeID.isEmpty ? nil : tempActivityTypeID,
                projectPhaseID: validatedPhaseID,
                milestoneText: tempMilestoneText.isEmpty ? nil : tempMilestoneText,
                notes: tempNotes,
                mood: tempMood
            )
            hasChanges = false
            
            // Trigger refresh callback if provided (either direct or shared)
            onSessionUpdated?()
            SessionSidebarEditView.sharedSessionUpdatedCallback?()
            
            // Close sidebar after successful save
            sidebarState.hide()
        } else {
            // Handle error (could show alert)
            print("Failed to save session")
        }
        
        isSaving = false
    }
    
    private func validateAndResetPhaseIfInvalid() {
        // When project changes, check if the current phase selection is still valid
        if let selectedProject = projectsViewModel.projects.first(where: { $0.name == tempProjectName }),
           let phaseID = tempProjectPhaseID {
            // Check if the selected phase exists in the current project
            let phaseExists = selectedProject.phases.contains { $0.id == phaseID && !$0.archived }
            if !phaseExists {
                // Phase doesn't exist in current project, clear it
                tempProjectPhaseID = nil
                print("⚠️ Selected phase \(phaseID) not found in project \(tempProjectName), clearing phase selection")
            }
        }
    }
    
    private func deleteSession() {
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Delete Session"
        alert.informativeText = "Are you sure you want to delete this session? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // User confirmed deletion
            let success = sessionManager.deleteSession(id: session.id)
            
            if success {
                // Close sidebar after successful deletion
                sidebarState.hide()
            } else {
                // Handle error (could show alert)
                print("Failed to delete session")
            }
        }
    }
}

// MARK: - Shared callback for session updates
extension SessionSidebarEditView {
    static var sharedSessionUpdatedCallback: (() -> Void)?
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
            
            // Create preview-specific view models with sample data
            let previewProjectsViewModel = ProjectsViewModel()
            let sampleProject = Project(
                id: UUID().uuidString,
                name: "Sample Project",
                color: "#8E44AD",
                about: "Sample project for preview",
                order: 1,
                emoji: "🎨",
                phases: [
                    Phase(name: "Planning", order: 0, archived: false),
                    Phase(name: "Development", order: 1, archived: false),
                    Phase(name: "Testing", order: 2, archived: false)
                ]
            )
            previewProjectsViewModel.projects = [sampleProject]
            
            let previewActivityTypesViewModel = ActivityTypesViewModel()
            let sampleActivityType = ActivityType(
                id: UUID().uuidString,
                name: "Sample Activity",
                emoji: "⚡",
                description: "Sample activity type for preview",
                archived: false
            )
            previewActivityTypesViewModel.activityTypes = [sampleActivityType]
            
            return SessionSidebarEditView(session: sampleSession)
                .environmentObject(SidebarStateManager())
                .environmentObject(SessionManager.shared)
                .environmentObject(previewProjectsViewModel)
                .environmentObject(previewActivityTypesViewModel)
                .frame(width: 420)
                .padding()
        }
    }
    #endif
