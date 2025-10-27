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
    }

    var body: some View {
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
                    onCancel: { isEditing = false },
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
        .frame(minHeight: 100)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .onChange(of: isEditing) { newValue, _ in
            if newValue {
                editedDate = session.date
                editedStartTime = String(session.startTime.prefix(5))
                editedEndTime = String(session.endTime.prefix(5))
                editedProject = session.projectName
                editedNotes = session.notes
                selectedMood = session.mood.map { "\($0)" } ?? ""
            }
        }
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
            onSave()
            isEditing = false
        }
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct SessionCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
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
            .frame(width: 600, height: 120)
            .background(Color(.windowBackgroundColor))
            
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
            .frame(width: 600, height: 140)
            .background(Color(.windowBackgroundColor))
            
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
            .frame(width: 600, height: 120)
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
            .frame(width: 600, height: 120)
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
            .frame(width: 600, height: 140)
            .background(Color(.windowBackgroundColor))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
