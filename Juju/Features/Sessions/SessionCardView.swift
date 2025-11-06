import SwiftUI

/// Main view for displaying a session card with edit functionality
struct SessionCardView: View {
    let session: SessionRecord
    let projects: [Project]
    let onSave: () -> Void
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var editedDate = ""
    @State private var editedStartTime = ""
    @State private var editedEndTime = ""
    @State private var editedProject = ""
    @State private var editedNotes = ""
    @State private var selectedMood: String = ""
    
    // Cache the project color to avoid repeated lookups
    @State private var sessionProjectColor: Color = Color.gray
    
    var projectNames: [String] {
        projects.map { $0.name }
    }
    
    var isProjectEmpty: Bool {
        editedProject.isEmpty
    }

    init(
        session: SessionRecord,
        projects: [Project],
        onSave: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.session = session
        self.projects = projects
        self.onSave = onSave
        self.onDelete = onDelete
        
        // Initialize the project color
        let project = projects.first { $0.name == session.projectName }
        self._sessionProjectColor = State(initialValue: project?.swiftUIColor ?? Color.gray)
    }

    
    // MARK: BODY
    
    var body: some View {
        // 1️⃣  Card – gradient + content
        ZStack(alignment: .leading) {
            // --- Gradient strip
            LinearGradient(
                colors: [
                    sessionProjectColor,
                    sessionProjectColor.opacity(0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 8)
            .clipped()
            // --- Card content
            Group {
                if isEditing {
                    SessionEditOptions(
                        editedDate: $editedDate,
                        editedStartTime: $editedStartTime,
                        editedEndTime: $editedEndTime,
                        editedProject: $editedProject,
                        selectedMood: $selectedMood,
                        editedNotes: $editedNotes,
                        projects: projectNames,
                        onSave: saveSession,
                        onCancel: cancelEdit,
                        isProjectEmpty: isProjectEmpty
                    )
                } else {
                    SessionViewOptions(
                        session: session,
                        projects: projects,
                        onEdit: { isEditing = true },
                        onDelete: onDelete
                    )
                }
            }
            .padding(Theme.spacingMedium)
        }
        // 3️⃣  Card background + border (MOVED UP!)
        .background(Theme.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )

        .clipShape(RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)) // Clip AFTER background/overlay
        // 4️⃣  Final layout tweaks
        .frame(minHeight: 180)
        .contentShape(Rectangle())
        .onChange(of: isEditing) { newValue in
            newValue ? startEditing() : resetToOriginalValues()
        }
        .onChange(of: projects) { _, newProjects in
            // Update the project color when projects change
            let project = newProjects.first { $0.name == session.projectName }
            sessionProjectColor = project?.swiftUIColor ?? Color.gray
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
    
    private func resetToOriginalValues() {
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
            // Only call onSave if the update was successful
            DispatchQueue.main.async {
                onSave()
                isEditing = false
            }
        }
    }
    
    private func cancelEdit() {
        // Reset to original values and exit edit mode
        resetToOriginalValues()
        isEditing = false
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct SessionCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
            // Preview with short notes
            SessionCardView(
                session: SessionRecord(
                    id: "1",
                    date: "2024-01-15",
                    startTime: "09:00:00",
                    endTime: "10:30:00",
                    durationMinutes: 90,
                    projectName: "Project Alpha",
                    notes: "Quick meeting about the new features.",
                    mood: 7
                ),
                projects: [
                    Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0),
                    Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0)
                ],
                onSave: { print("Saved") },
                onDelete: { print("Deleted") }
            )
            .frame(width: 300, height: 140)
            .background(Theme.Colors.surface)

            Divider()

            
            // Preview with long notes
            SessionCardView(
                session: SessionRecord(
                    id: "2",
                    date: "2024-01-15",
                    startTime: "14:00:00",
                    endTime: "16:00:00",
                    durationMinutes: 120,
                    projectName: "Project Beta",
                    notes: "Long detailed notes about the implementation process and technical decisions made during the development session. This should demonstrate how the notes field handles longer text content and how the layout adapts to accommodate it.",
                    mood: 9
                ),
                projects: [
                    Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0),
                    Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0)
                ],
                onSave: { print("Saved") },
                onDelete: { print("Deleted") }
            )
            .frame(width: 300, height: 140)
            .background(Theme.Colors.surface)

            Divider()
            
            // Preview with mood
            SessionCardView(
                session: SessionRecord(
                    id: "3",
                    date: "2024-01-16",
                    startTime: "10:00:00",
                    endTime: "11:00:00",
                    durationMinutes: 60,
                    projectName: "Project Alpha",
                    notes: "Review session",
                    mood: 10
                ),
                projects: [
                    Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0),
                    Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0)
                ],
                onSave: { print("Saved") },
                onDelete: { print("Deleted") }
            )
            .frame(width: 300, height: 140)
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            // Preview with no mood
            SessionCardView(
                session: SessionRecord(
                    id: "4",
                    date: "2024-01-17",
                    startTime: "13:00:00",
                    endTime: "14:30:00",
                    durationMinutes: 90,
                    projectName: "Project Beta",
                    notes: "Development work on new features",
                    mood: nil
                ),
                projects: [
                    Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0),
                    Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0)
                ],
                onSave: { print("Saved") },
                onDelete: { print("Deleted") }
            )
            .frame(width: 300, height: 140)
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            // Preview with very long session duration
            SessionCardView(
                session: SessionRecord(
                    id: "5",
                    date: "2024-01-18",
                    startTime: "09:00:00",
                    endTime: "17:00:00",
                    durationMinutes: 480,
                    projectName: "Project Alpha",
                    notes: "Long work day with multiple meetings and focused development time. This session demonstrates how the layout handles longer time ranges and how the duration calculation works.",
                    mood: 8
                ),
                projects: [
                    Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0),
                    Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0)
                ],
                onSave: { print("Saved") },
                onDelete: { print("Deleted") }
            )
            .frame(width: 300, height: 140)
            .background(Theme.Colors.surface)
            
            Divider()
            
            // Preview with no notes
            SessionCardView(
                session: SessionRecord(
                    id: "6",
                    date: "2024-01-19",
                    startTime: "11:00:00",
                    endTime: "12:00:00",
                    durationMinutes: 60,
                    projectName: "Project Gamma",
                    notes: "",
                    mood: 5
                ),
                projects: [
                    Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0),
                    Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0),
                    Project(id: "3", name: "Project Gamma", color: "#8B5CF6", about: nil, order: 0)
                ],
                onSave: { print("Saved") },
                onDelete: { print("Deleted") }
            )
            .frame(width: 300, height: 140)
            .background(Theme.Colors.background)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
