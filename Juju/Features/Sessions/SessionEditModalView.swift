import SwiftUI

/// Modal view for editing session details
struct SessionEditModalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var editedDate = ""
    @State private var editedStartTime = ""
    @State private var editedEndTime = ""
    @State private var editedProject = ""
    @State private var editedNotes = ""
    @State private var selectedMood: String = ""
    
    let session: SessionRecord
    let projects: [Project]
    let onSave: (SessionRecord) -> Void
    
    var projectNames: [String] {
        projects.map { $0.name }
    }
    
    var isProjectEmpty: Bool {
        editedProject.isEmpty
    }
    
    init(session: SessionRecord, projects: [Project], onSave: @escaping (SessionRecord) -> Void) {
        self.session = session
        self.projects = projects
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            // Header
            HStack {
                Text("Edit Session")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
            }
            .padding(.bottom, Theme.spacingMedium)
            
            // Date Field
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Date")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                TextField("Date (YYYY-MM-DD)", text: $editedDate)
                    .textFieldStyle(.plain)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.horizontal, Theme.spacingMedium)
                    .padding(.vertical, Theme.spacingSmall)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
            }
            
            // Time Fields
            HStack(spacing: Theme.spacingMedium) {
                // Start Time
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    Text("Start Time")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    TextField("HH:MM", text: $editedStartTime)
                        .textFieldStyle(.plain)
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(.horizontal, Theme.spacingMedium)
                        .padding(.vertical, Theme.spacingSmall)
                        .background(Theme.Colors.surface)
                        .cornerRadius(Theme.Design.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .stroke(Theme.Colors.divider, lineWidth: 1)
                        )
                }
                
                // End Time
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    Text("End Time")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    TextField("HH:MM", text: $editedEndTime)
                        .textFieldStyle(.plain)
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(.horizontal, Theme.spacingMedium)
                        .padding(.vertical, Theme.spacingSmall)
                        .background(Theme.Colors.surface)
                        .cornerRadius(Theme.Design.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .stroke(Theme.Colors.divider, lineWidth: 1)
                        )
                }
            }
            
            // Project Field
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Project")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Picker("Project", selection: $editedProject) {
                    ForEach(projectNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.spacingMedium)
                .padding(.vertical, Theme.spacingSmall)
                .background(Theme.Colors.surface)
                .cornerRadius(Theme.Design.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .stroke(Theme.Colors.divider, lineWidth: 1)
                )
            }
            
            // Mood Field
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Mood (1-10)")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Picker("Mood", selection: $selectedMood) {
                    Text("None").tag("")
                    ForEach(1...10, id: \.self) { number in
                        Text("\(number)/10").tag("\(number)")
                    }
                }
                .pickerStyle(.menu)
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.spacingMedium)
                .padding(.vertical, Theme.spacingSmall)
                .background(Theme.Colors.surface)
                .cornerRadius(Theme.Design.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .stroke(Theme.Colors.divider, lineWidth: 1)
                )
            }
            
            // Notes Field
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Notes")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                TextEditor(text: $editedNotes)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(minHeight: 100)
                    .padding(Theme.spacingMedium)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
            }
            
            Spacer()
            
            // Action Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.Colors.textSecondary)
                .font(Theme.Fonts.caption)
                .padding(.horizontal, Theme.spacingExtraSmall)
                .pointingHandOnHover()
                
                Spacer()
                
                Button("Save Session") {
                    saveSession()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.primary)
                .disabled(isProjectEmpty)
                .pointingHandOnHover()
            }
        }
        .padding(Theme.spacingLarge)
        .frame(minWidth: 450, minHeight: 600)
        .background(Theme.Colors.background)
        .onAppear {
            startEditing()
        }
    }
    
    private func startEditing() {
        editedDate = session.date
        editedStartTime = String(session.startTime.prefix(5))
        editedEndTime = String(session.endTime.prefix(5))
        editedProject = session.projectName
        editedNotes = session.notes
        selectedMood = session.mood.map { "\($0)" } ?? ""
    }
    
    private func saveSession() {
        let moodInt = selectedMood.isEmpty ? nil : Int(selectedMood)
        
        if SessionManager.shared.updateSessionFull(
            id: session.id,
            date: editedDate,
            startTime: editedStartTime + ":00",
            endTime: editedEndTime + ":00",
            projectName: editedProject,
            notes: editedNotes,
            mood: moodInt
        ) {
            // Create updated session record to pass back, preserving new fields
            let updatedSession = SessionRecord(
                id: session.id,
                date: editedDate,
                startTime: editedStartTime + ":00",
                endTime: editedEndTime + ":00",
                durationMinutes: session.durationMinutes, // Recalculate if needed
                projectName: editedProject,
                projectID: session.projectID,
                activityTypeID: session.activityTypeID,
                projectPhaseID: session.projectPhaseID,
                milestoneText: session.milestoneText,
                notes: editedNotes,
                mood: moodInt
            )
            
            DispatchQueue.main.async {
                onSave(updatedSession)
                dismiss()
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct SessionEditModalView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSession = SessionRecord(
            id: "1",
            date: "2024-01-15",
            startTime: "09:00:00",
            endTime: "10:30:00",
            durationMinutes: 90,
            projectName: "Project Alpha",
            notes: "Quick meeting about the new features.",
            mood: 7
        )
        
        let sampleProjects = [
            Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0, emoji: "💼"),
            Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0, emoji: "🏠")
        ]
        
        SessionEditModalView(
            session: sampleSession,
            projects: sampleProjects,
            onSave: { _ in }
        )
        .frame(minWidth: 450, minHeight: 600)
        .previewLayout(.sizeThatFits)
    }
}
#endif
