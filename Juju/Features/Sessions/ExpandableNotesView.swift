import SwiftUI

/// Standalone expandable notes view with smooth animations and inline editing
struct ExpandableNotesView: View {
    let session: SessionRecord
    let projects: [Project]
    let isEditing: Bool
    let isExpanded: Bool
    @Binding var notes: String
    @Binding var mood: Int
    @Binding var projectName: String
    @Binding var startTime: String
    @Binding var endTime: String
    
    @State private var localNotes = ""
    @State private var localMood = 0
    @State private var localProjectName = ""
    @State private var localStartTime = ""
    @State private var localEndTime = ""
    
    // Animation state
    @State private var animationHeight: CGFloat = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .background(Theme.Colors.divider)
            
            if isEditing {
                // Editable notes field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    TextEditor(text: $localNotes)
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(minHeight: 60, maxHeight: 120)
                        .padding(.horizontal, 4)
                        .background(Theme.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.Colors.divider, lineWidth: 1)
                        )
                        .cornerRadius(8)
                    
                    HStack {
                        Text("\(localNotes.count) characters")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        Spacer()
                        
                        // Inline editing controls for other fields
                        HStack(spacing: 12) {
                            // Project picker
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Project")
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Picker("Project", selection: $localProjectName) {
                                    ForEach(projects, id: \.name) { project in
                                        Text(project.name).tag(project.name)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(width: 160)
                                .background(Theme.Colors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.Colors.divider, lineWidth: 1)
                                )
                                .cornerRadius(8)
                            }
                            
                            // Time inputs
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Start Time")
                                        .font(Theme.Fonts.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                    TextField("HH:MM", text: $localStartTime)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 80)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("End Time")
                                        .font(Theme.Fonts.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                    TextField("HH:MM", text: $localEndTime)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 80)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Mood")
                                        .font(Theme.Fonts.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                    Slider(value: Binding(
                                        get: { Double(localMood) },
                                        set: { localMood = Int($0) }
                                    ), in: 0...10, step: 1)
                                    HStack {
                                        Text(localMood == 0 ? "No mood" : "\(localMood)/10")
                                            .font(Theme.Fonts.caption)
                                            .foregroundColor(Theme.Colors.textSecondary)
                                        Spacer()
                                    }
                                }
                                .frame(width: 180)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Row.contentPadding)
                .padding(.bottom, Theme.Row.contentPadding)
            } else {
                // Read-only notes
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Text(session.notes)
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, Theme.Row.contentPadding)
                .padding(.bottom, Theme.Row.contentPadding)
            }
        }
        .opacity(isExpanded ? 1 : 0)
        .frame(height: isExpanded ? Theme.Row.expandedHeight : 0)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onAppear {
            // Initialize local values when entering edit mode
            if isEditing {
                localNotes = notes
                localMood = mood
                localProjectName = projectName
                localStartTime = startTime
                localEndTime = endTime
            }
        }
        .onChange(of: isEditing) { _, newValue in
            if newValue {
                // Initialize local values when entering edit mode
                localNotes = notes
                localMood = mood
                localProjectName = projectName
                localStartTime = startTime
                localEndTime = endTime
            } else {
                // Sync back to bindings when exiting edit mode
                notes = localNotes
                mood = localMood
                projectName = localProjectName
                startTime = localStartTime
                endTime = localEndTime
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct ExpandableNotesView_Previews: PreviewProvider {
    @State static var notes = "This is a sample note for the session."
    @State static var mood = 7
    @State static var projectName = "Project Alpha"
    @State static var startTime = "09:00:00"
    @State static var endTime = "10:30:00"
    @State static var isExpanded = true
    
    static var previews: some View {
        VStack {
            // Edit mode
            ExpandableNotesView(
                session: SessionRecord(
                    id: "1",
                    date: "2024-01-15",
                    startTime: "09:00:00",
                    endTime: "10:30:00",
                    durationMinutes: 90,
                    projectName: "Project Alpha",
                    notes: "This is a sample note for the session.",
                    mood: 7
                ),
                projects: [
                    Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0, emoji: "💼"),
                    Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0, emoji: "🏠")
                ],
                isEditing: true,
                isExpanded: true,
                notes: $notes,
                mood: $mood,
                projectName: $projectName,
                startTime: $startTime,
                endTime: $endTime
            )
            .background(Theme.Colors.background)
            
            Divider()
            
            // Read-only mode
            ExpandableNotesView(
                session: SessionRecord(
                    id: "1",
                    date: "2024-01-15",
                    startTime: "09:00:00",
                    endTime: "10:30:00",
                    durationMinutes: 90,
                    projectName: "Project Alpha",
                    notes: "This is a sample note for the session.",
                    mood: 7
                ),
                projects: [
                    Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0, emoji: "💼"),
                    Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0, emoji: "🏠")
                ],
                isEditing: false,
                isExpanded: true,
                notes: $notes,
                mood: $mood,
                projectName: $projectName,
                startTime: $startTime,
                endTime: $endTime
            )
            .background(Theme.Colors.background)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
