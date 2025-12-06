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
        self._tempActivityTypeID = State(initialValue: session.activityTypeID ?? "")
        self._tempProjectPhaseID = State(initialValue: session.projectPhaseID)
        self._tempMilestoneText = State(initialValue: session.milestoneText ?? "")
    }
    
    var body: some View {
        VStack(spacing: Theme.spacingExtraLarge) {
            // Top section - time controls, project selection, and notes
            VStack(spacing: Theme.spacingExtraLarge) {
                // Time controls section
                timeControlsSection
                
                // Project selection section
                projectSelectionSection
                
                // Notes section
                notesSection
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
        .onChange(of: tempProjectName) { _ in validateChanges() }
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
            
            // Start and End time dropdowns
            HStack(spacing: Theme.spacingLarge) {
                // Start Time dropdown
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    Text("Start Time")
                        .font(.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                    HStack {
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
                        .frame(width: 80)
                        
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
                        .frame(width: 80)
                    }
                }
                
                Spacer()
                
                // End Time dropdown
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    Text("End Time")
                        .font(.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                    HStack {
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
                        .frame(width: 80)
                        
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
                        .frame(width: 80)
                    }
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
            if let selectedProject = projectsViewModel.projects.first(where: { $0.name == tempProjectName }) {
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    Text("Phase")
                        .font(.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Picker("Phase", selection: $tempProjectPhaseID) {
                        Text("No Phase").tag("")
                        ForEach(selectedProject.phases.filter { !$0.archived }, id: \.id) { phase in
                            Text(phase.name).tag(phase.id)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            
            // Milestone field with star emoji
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                HStack(spacing: 8) {
                    Text("Milestone")
                        .font(.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text("⭐")
                }
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
        
        hasChanges = (
            tempStartTime != sessionStartTime ||
            tempEndTime != sessionEndTime ||
            tempNotes != session.notes ||
            tempMood != (session.mood ?? 0) ||
            tempProjectName != session.projectName ||
            tempActivityTypeID != (session.activityTypeID ?? "") ||
            tempProjectPhaseID != session.projectPhaseID ||
            tempMilestoneText != (session.milestoneText ?? "")
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
            mood: tempMood,
            activityTypeID: tempActivityTypeID.isEmpty ? nil : tempActivityTypeID,
            projectPhaseID: tempProjectPhaseID,
            milestoneText: tempMilestoneText.isEmpty ? nil : tempMilestoneText
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
                activityTypeID: tempActivityTypeID.isEmpty ? nil : tempActivityTypeID,
                projectPhaseID: tempProjectPhaseID,
                milestoneText: tempMilestoneText.isEmpty ? nil : tempMilestoneText,
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
                    Phase(name: "Planning", order: 0),
                    Phase(name: "Development", order: 1),
                    Phase(name: "Testing", order: 2)
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
