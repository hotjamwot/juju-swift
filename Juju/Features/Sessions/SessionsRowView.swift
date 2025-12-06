import SwiftUI

/// Compact row view for displaying session information in list layout
/// Supports inline editing mode and expandable notes
struct SessionsRowView: View {
    @Binding var session: SessionRecord
    let projects: [Project]
    let isEditing: Bool
    let onEdit: () -> Void
    let onSave: (SessionRecord) -> Void
    let onDelete: () -> Void
    
    @State private var isExpanded = false
    @State private var tempNotes = ""
    @State private var tempMood: Int = 0
    @State private var tempProjectName = ""
    @State private var tempStartTime = ""
    @State private var tempEndTime = ""
    @State private var tempDate = Date()
    @State private var tempActivityTypeID = ""
    @State private var tempProjectPhaseID = ""
    
    // Hover state for interactive feedback
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row content
            HStack(spacing: Theme.Row.compactSpacing) {
                // Project color dot
                Circle()
                    .fill(projectColor)
                    .frame(width: Theme.Row.projectDotSize, height: Theme.Row.projectDotSize)
                    .padding(.leading, Theme.Row.contentPadding)
                
                // Project emoji
                Text(projectEmoji)
                    .font(.system(size: Theme.Row.emojiSize))
                    .frame(width: 24, alignment: .leading)
                
                // Session details (compact)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(session.projectName)
                            .font(Theme.Fonts.caption.weight(.semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Mood indicator (if set)
                        if let mood = session.mood {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(moodColor(for: mood))
                                Text("\(mood)/10")
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(moodColor(for: mood))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(moodColor(for: mood).opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    
                    HStack {
                        // Time info
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("\(formattedStartTime) - \(formattedEndTime)")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Duration
                        Text(formatDuration(session.durationMinutes))
                            .font(Theme.Fonts.caption.weight(.semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                .padding(.vertical, Theme.Row.contentPadding)
                
                Spacer()
                
                // Notes preview (truncated)
                if !session.notes.isEmpty {
                    Text(session.notes)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: 200, alignment: .leading)
                }
                
                // Edit controls (only in edit mode)
                if isEditing {
                    HStack(spacing: 12) {
                        Button(action: saveSession) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12))
                                Text("Save")
                                    .font(Theme.Fonts.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .pointingHandOnHover()
                        
                        Button(action: cancelEdit) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12))
                                Text("Cancel")
                                    .font(Theme.Fonts.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.divider.opacity(0.3))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .pointingHandOnHover()
                        
                        Button(action: onDelete) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                Text("Delete")
                                    .font(Theme.Fonts.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.error.opacity(0.2))
                            .foregroundColor(Theme.Colors.error)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .pointingHandOnHover()
                    }
                    .padding(.trailing, Theme.Row.contentPadding)
                } else {
                    // Edit button (normal mode)
                    Button(action: onEdit) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                            Text("Edit")
                                .font(Theme.Fonts.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.divider.opacity(0.3))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .pointingHandOnHover()
                    .padding(.trailing, Theme.Row.contentPadding)
                }
            }
            .frame(height: Theme.Row.height)
            .background(
                isEditing ? 
                Theme.Colors.surface.opacity(0.8) :
                (isHovering ? Theme.Colors.surface.opacity(Theme.Row.hoverOpacity) : Theme.Colors.surface.opacity(0.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Row.cornerRadius)
                    .stroke(Theme.Colors.divider, lineWidth: 1)
            )
            .cornerRadius(Theme.Row.cornerRadius)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                if !isEditing {
                    toggleNotes()
                }
            }
            
            // Expandable notes section
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Theme.Colors.divider)
                    
                    if isEditing {
                        // Editable notes field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes")
                                .font(Theme.Fonts.caption.weight(.semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                            
                            TextEditor(text: $tempNotes)
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
                                Text("\(tempNotes.count) characters")
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                
                                Spacer()
                                
                                // Inline editing controls for other fields - improved styling
                                VStack(alignment: .leading, spacing: 12) {
                                    // Date picker with better styling
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Date")
                                            .font(Theme.Fonts.caption)
                                            .foregroundColor(Theme.Colors.textSecondary)
                                        DatePicker(
                                            "",
                                            selection: $tempDate,
                                            displayedComponents: .date
                                        )
                                        .labelsHidden()
                                        .padding(.horizontal, Theme.spacingMedium)
                                        .padding(.vertical, Theme.spacingSmall)
                                        .background(Theme.Colors.surface)
                                        .cornerRadius(Theme.Design.cornerRadius)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                                .stroke(Theme.Colors.divider, lineWidth: 1)
                                        )
                                    }
                                    
                                    // Project and Activity Type pickers with better styling
                                    HStack(spacing: 12) {
                                        // Project picker
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Project")
                                                .font(Theme.Fonts.caption)
                                                .foregroundColor(Theme.Colors.textSecondary)
                                            Picker("Project", selection: $tempProjectName) {
                                                ForEach(projects, id: \.name) { project in
                                                    Text(project.name).tag(project.name)
                                                }
                                            }
                                            .pickerStyle(MenuPickerStyle())
                                            .padding(.horizontal, Theme.spacingMedium)
                                            .padding(.vertical, Theme.spacingSmall)
                                            .background(Theme.Colors.surface)
                                            .cornerRadius(Theme.Design.cornerRadius)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                                    .stroke(Theme.Colors.divider, lineWidth: 1)
                                            )
                                            .frame(width: 200)
                                        }
                                        
                                        // Activity Type picker
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Activity Type")
                                                .font(Theme.Fonts.caption)
                                                .foregroundColor(Theme.Colors.textSecondary)
                                            Picker("Activity Type", selection: $tempActivityTypeID) {
                                                Text("Uncategorized").tag("")
                                                ForEach(ActivityTypeManager.shared.getActiveActivityTypes(), id: \.id) { activityType in
                                                    Text("\(activityType.emoji) \(activityType.name)").tag(activityType.id)
                                                }
                                            }
                                            .pickerStyle(MenuPickerStyle())
                                            .padding(.horizontal, Theme.spacingMedium)
                                            .padding(.vertical, Theme.spacingSmall)
                                            .background(Theme.Colors.surface)
                                            .cornerRadius(Theme.Design.cornerRadius)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                                    .stroke(Theme.Colors.divider, lineWidth: 1)
                                            )
                                            .frame(width: 240)
                                        }
                                    }
                                    
                                    // Phase picker (based on selected project) with better styling
                                    if let selectedProject = projects.first(where: { $0.name == tempProjectName }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Phase")
                                                .font(Theme.Fonts.caption)
                                                .foregroundColor(Theme.Colors.textSecondary)
                                            Picker("Phase", selection: $tempProjectPhaseID) {
                                                Text("No Phase").tag("")
                                                ForEach(selectedProject.phases.filter { !$0.archived }, id: \.id) { phase in
                                                    Text(phase.name).tag(phase.id)
                                                }
                                            }
                                            .pickerStyle(MenuPickerStyle())
                                            .padding(.horizontal, Theme.spacingMedium)
                                            .padding(.vertical, Theme.spacingSmall)
                                            .background(Theme.Colors.surface)
                                            .cornerRadius(Theme.Design.cornerRadius)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                                    .stroke(Theme.Colors.divider, lineWidth: 1)
                                            )
                                            .frame(width: 200)
                                        }
                                    }
                                    
                                    // Time inputs with better styling
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Start Time")
                                                .font(Theme.Fonts.caption)
                                                .foregroundColor(Theme.Colors.textSecondary)
                                            TextField("HH:MM", text: $tempStartTime)
                                                .textFieldStyle(PlainTextFieldStyle())
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
                                                .frame(width: 100)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("End Time")
                                                .font(Theme.Fonts.caption)
                                                .foregroundColor(Theme.Colors.textSecondary)
                                            TextField("HH:MM", text: $tempEndTime)
                                                .textFieldStyle(PlainTextFieldStyle())
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
                                                .frame(width: 100)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Mood")
                                                .font(Theme.Fonts.caption)
                                                .foregroundColor(Theme.Colors.textSecondary)
                                            HStack {
                                                Slider(value: Binding(
                                                    get: { Double(tempMood) },
                                                    set: { tempMood = Int($0) }
                                                ), in: 0...10, step: 1)
                                                .frame(width: 120)
                                                
                                                Text(tempMood == 0 ? "No mood" : "\(tempMood)/10")
                                                    .font(Theme.Fonts.caption)
                                                    .foregroundColor(Theme.Colors.textSecondary)
                                                    .frame(width: 60)
                                            }
                                        }
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
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
        }
        .onAppear {
            // Initialize temp values when entering edit mode
            if isEditing {
                tempNotes = session.notes
                tempMood = session.mood ?? 0
                tempProjectName = session.projectName
                tempStartTime = session.startTime
                tempEndTime = session.endTime
                
                // Initialize date from session date string
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                if let sessionDate = dateFormatter.date(from: session.date) {
                    tempDate = sessionDate
                } else {
                    tempDate = Date()
                }
                
                // Initialize activity type and phase
                tempActivityTypeID = session.activityTypeID ?? ""
                tempProjectPhaseID = session.projectPhaseID ?? ""
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var projectColor: Color {
        projects.first { $0.name == session.projectName }?.swiftUIColor ?? Theme.Colors.accentColor
    }
    
    private var projectEmoji: String {
        projects.first { $0.name == session.projectName }?.emoji ?? "📁"
    }
    
    private var formattedStartTime: String {
        formatTime(session.startTime)
    }
    
    private var formattedEndTime: String {
        formatTime(session.endTime)
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ timeString: String) -> String {
        let components = timeString.components(separatedBy: ":")
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return timeString
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeStyle = .short
        
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
    
    private func moodColor(for mood: Int) -> Color {
        switch mood {
        case 1...4: return Theme.Colors.error
        case 5...7: return projectColor.opacity(0.8)
        case 8: return projectColor.opacity(0.8)
        case 9: return projectColor.opacity(0.9)
        case 10: return projectColor
        default: return Theme.Colors.error
        }
    }
    
    private func toggleNotes() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
        }
    }
    
    private func saveSession() {
        // Validate time format
        guard isValidTimeFormat(tempStartTime) && isValidTimeFormat(tempEndTime) else {
            // Show error message
            return
        }
        
        // Format date to string
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: tempDate)
        
        // Calculate new duration
        let newDuration: Int
        if let startComponents = parseTimeComponents(tempStartTime),
           let endComponents = parseTimeComponents(tempEndTime) {
            let startMinutes = startComponents.hour * 60 + startComponents.minute
            let endMinutes = endComponents.hour * 60 + endComponents.minute
            newDuration = max(0, endMinutes - startMinutes)
        } else {
            newDuration = session.durationMinutes
        }
        
        // Get project ID for the selected project name
        let projectID = projects.first { $0.name == tempProjectName }?.id
        
        // Create a completely new SessionRecord with all updated values
        let updatedSession = SessionRecord(
            id: session.id,
            date: dateString,
            startTime: tempStartTime,
            endTime: tempEndTime,
            durationMinutes: newDuration,
            projectName: tempProjectName,
            projectID: projectID,
            activityTypeID: tempActivityTypeID.isEmpty ? nil : tempActivityTypeID,
            projectPhaseID: tempProjectPhaseID.isEmpty ? nil : tempProjectPhaseID,
            milestoneText: session.milestoneText, // Keep existing milestone text
            notes: tempNotes,
            mood: tempMood > 0 ? tempMood : nil
        )
        
        // Assign the updated session back to the binding
        session = updatedSession
        onSave(session)
    }
    
    private func cancelEdit() {
        // Reset temp values and exit edit mode
        tempNotes = session.notes
        tempMood = session.mood ?? 0
        tempProjectName = session.projectName
        tempStartTime = session.startTime
        tempEndTime = session.endTime
        
        // Trigger parent to exit edit mode
        onSave(session)
    }
    
    private func isValidTimeFormat(_ timeString: String) -> Bool {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return false
        }
        return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59
    }
    
    private func parseTimeComponents(_ timeString: String) -> (hour: Int, minute: Int)? {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }
        return (hour, minute)
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct SessionsRowView_Previews: PreviewProvider {
    @State static var normalSession = SessionRecord(
        id: "1",
        date: "2024-01-15",
        startTime: "09:00:00",
        endTime: "10:30:00",
        durationMinutes: 90,
        projectName: "Project Alpha",
        notes: "Quick meeting about the new features.",
        mood: 7
    )
    
    @State static var editSession = SessionRecord(
        id: "2",
        date: "2024-01-15",
        startTime: "14:00:00",
        endTime: "16:00:00",
        durationMinutes: 120,
        projectName: "Project Beta",
        notes: "Long detailed notes about the implementation process.",
        mood: 9
    )
    
    static var previews: some View {
        VStack(spacing: 10) {
            // Normal mode
            SessionsRowView(
                session: $normalSession,
                projects: [
                    Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0, emoji: "💼"),
                    Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0, emoji: "🏠")
                ],
                isEditing: false,
                onEdit: { },
                onSave: { _ in },
                onDelete: { }
            )
            .frame(width: 800)
            .background(Theme.Colors.background)
            
            // Edit mode
            SessionsRowView(
                session: $editSession,
                projects: [
                    Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0, emoji: "💼"),
                    Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0, emoji: "🏠")
                ],
                isEditing: true,
                onEdit: { },
                onSave: { _ in },
                onDelete: { }
            )
            .frame(width: 800)
            .background(Theme.Colors.background)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
