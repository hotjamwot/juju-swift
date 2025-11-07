import SwiftUI

/// Component for handling session editing options
struct SessionEditOptions: View {
    @Binding var editedDate: String
    @Binding var editedStartTime: String
    @Binding var editedEndTime: String
    @Binding var editedProject: String
    @Binding var selectedMood: String
    @Binding var editedNotes: String
    let projects: [String]
    let onSave: () -> Void
    let onCancel: () -> Void
    let isProjectEmpty: Bool
    
    public init(
        editedDate: Binding<String>,
        editedStartTime: Binding<String>,
        editedEndTime: Binding<String>,
        editedProject: Binding<String>,
        selectedMood: Binding<String>,
        editedNotes: Binding<String>,
        projects: [String],
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        isProjectEmpty: Bool
    ) {
        self._editedDate = editedDate
        self._editedStartTime = editedStartTime
        self._editedEndTime = editedEndTime
        self._editedProject = editedProject
        self._selectedMood = selectedMood
        self._editedNotes = editedNotes
        self.projects = projects
        self.onSave = onSave
        self.onCancel = onCancel
        self.isProjectEmpty = isProjectEmpty
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card content - matches SessionViewOptions structure
            VStack(alignment: .leading, spacing: Theme.spacingMedium) {
                /* ────── TOP ROW: Project + Mood ───────────── */
                HStack {
                    // Project name (left) - using picker
                    Picker("Project", selection: $editedProject) {
                        Text("-- Select Project --").tag("")
                        ForEach(projects, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    
                    Spacer()
                    
                    // Mood dropdown (right)
                    if let moodInt = Int(selectedMood) {
                        Picker("Mood", selection: $selectedMood) {
                            Text("-- No mood --").tag("")
                            ForEach(0...10, id: \.self) { mood in
                                Text("\(mood)").tag("\(mood)")
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    } else {
                        Picker("Mood", selection: $selectedMood) {
                            Text("-- No mood --").tag("")
                            ForEach(0...10, id: \.self) { mood in
                                Text("\(mood)").tag("\(mood)")
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                }
                
                /* ────── MIDDLE ROW: Time & Date ────── */
                HStack {
                    HStack(spacing: Theme.spacingSmall) {
                        Image(systemName: "calendar")
                        Text("Date:")
                        TextField("YYYY-MM-DD", text: $editedDate)
                            .textFieldStyle(.plain)
                            .frame(width: 110)
                    }
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    
                    Spacer()
                    
                    HStack(spacing: Theme.spacingSmall) {
                        Image(systemName: "clock")
                        // Start time with dropdowns
                        HStack(spacing: 2) {
                            Picker("", selection: Binding(
                                get: { startHour },
                                set: { newHour in
                                    editedStartTime = String(format: "%02d:%02d", newHour, startMinute)
                                }
                            )) {
                                ForEach(0...23, id: \.self) { hour in
                                    Text(String(format: "%02d", hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 60)
                            
                            Text(":")
                            
                            Picker("", selection: Binding(
                                get: { startMinute },
                                set: { newMinute in
                                    editedStartTime = String(format: "%02d:%02d", startHour, newMinute)
                                }
                            )) {
                                ForEach(0...59, id: \.self) { minute in
                                    Text(String(format: "%02d", minute)).tag(minute)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 60)
                        }
                        
                        Text("—")
                        
                        // End time with dropdowns
                        HStack(spacing: 2) {
                            Picker("", selection: Binding(
                                get: { endHour },
                                set: { newHour in
                                    editedEndTime = String(format: "%02d:%02d", newHour, endMinute)
                                }
                            )) {
                                ForEach(0...23, id: \.self) { hour in
                                    Text(String(format: "%02d", hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 60)
                            
                            Text(":")
                            
                            Picker("", selection: Binding(
                                get: { endMinute },
                                set: { newMinute in
                                    editedEndTime = String(format: "%02d:%02d", endHour, newMinute)
                                }
                            )) {
                                ForEach(0...59, id: \.self) { minute in
                                    Text(String(format: "%02d", minute)).tag(minute)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 60)
                        }
                    }
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                }
                
                /* ────── NOTES SECTION (always visible in edit mode) ────── */
                TextEditor(text: $editedNotes)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(height: 60)
                    .padding(Theme.spacingMedium)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
                
                /* ────── BOTTOM ROW: Save / Cancel ────── */
                HStack {
                    Spacer()
                    HStack(spacing: Theme.spacingExtraSmall) {
                        Button(action: onCancel) {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(SimpleIconButtonStyle(iconSize: 12))
                        
                        Button(action: onSave) {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(SimpleIconButtonStyle(iconSize: 12))
                        .disabled(isProjectEmpty)
                    }
                }
                
                // If no notes, add spacer to maintain consistent layout
                if editedNotes.isEmpty { Spacer() }
            }
            .padding(.vertical, Theme.spacingMedium)
            .padding(.horizontal, Theme.spacingMedium)
        }
        .background(Theme.Colors.surface)
    }
    
    // Helper computed properties for time parsing
    private var startHour: Int {
        let parts = editedStartTime.components(separatedBy: ":")
        return Int(parts[0]) ?? 0
    }
    
    private var startMinute: Int {
        let parts = editedStartTime.components(separatedBy: ":")
        return parts.count > 1 ? Int(parts[1]) ?? 0 : 0
    }
    
    private var endHour: Int {
        let parts = editedEndTime.components(separatedBy: ":")
        return Int(parts[0]) ?? 0
    }
    
    private var endMinute: Int {
        let parts = editedEndTime.components(separatedBy: ":")
        return parts.count > 1 ? Int(parts[1]) ?? 0 : 0
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct SessionEditOptions_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            
            // Edit Session preview with short notes
            SessionEditOptions(
                editedDate: .constant("2024-01-16"),
                editedStartTime: .constant("14:00"),
                editedEndTime: .constant("16:00"),
                editedProject: .constant("Project Beta"),
                selectedMood: .constant("7"),
                editedNotes: .constant("Short notes"),
                projects: ["Project Alpha", "Project Beta", "Project Gamma"],
                onSave: { print("Save clicked") },
                onCancel: { print("Cancel clicked") },
                isProjectEmpty: false
            )
            .frame(width: 400, height: 200)
            .background(Theme.Colors.surface)
            
            Divider()
            
            // Edit Session preview with long notes
            SessionEditOptions(
                editedDate: .constant("2024-01-16"),
                editedStartTime: .constant("09:30"),
                editedEndTime: .constant("11:45"),
                editedProject: .constant("Project Alpha"),
                selectedMood: .constant("9"),
                editedNotes: .constant("This is a much longer set of notes that should demonstrate how the notes field behaves with more content."),
                projects: ["Project Alpha", "Project Beta", "Project Gamma"],
                onSave: { print("Save clicked") },
                onCancel: { print("Cancel clicked") },
                isProjectEmpty: false
            )
            .frame(width: 400, height: 200)
            .background(Theme.Colors.surface)
            
            Divider()
            
            // Edit Session preview with no mood
            SessionEditOptions(
                editedDate: .constant("2024-01-17"),
                editedStartTime: .constant("10:00"),
                editedEndTime: .constant("11:00"),
                editedProject: .constant("Project Gamma"),
                selectedMood: .constant(""),
                editedNotes: .constant(""),
                projects: ["Project Alpha", "Project Beta", "Project Gamma"],
                onSave: { print("Save clicked") },
                onCancel: { print("Cancel clicked") },
                isProjectEmpty: false
            )
            .frame(width: 400, height: 200)
            .background(Theme.Colors.surface)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
