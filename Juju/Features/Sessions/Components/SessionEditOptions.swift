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
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            // Header
            HStack {
                Text("Edit Session")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.simpleIcon(size: 12))
                .pointingHandOnHover()
                
                // Form content
                VStack(alignment: .leading, spacing: Theme.spacingMedium) {
                    // First row: Date and Project
                    HStack(spacing: Theme.spacingLarge) {
                        // Date
                        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                            Text("Date")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                            TextField("YYYY-MM-DD", text: $editedDate)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, Theme.spacingMedium)
                                .padding(.vertical, Theme.spacingSmall)
                                .background(Theme.Colors.surface)
                                .cornerRadius(Theme.Design.cornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                        .stroke(Theme.Colors.divider, lineWidth: 1)
                                )
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Project
                        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                            Text("Project")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                            Picker("Project", selection: $editedProject) {
                                Text("-- Select Project --").tag("")
                                ForEach(projects, id: \.self) { name in
                                    Text(name).tag(name)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal, Theme.spacingMedium)
                            .padding(.vertical, Theme.spacingSmall)
                            .background(Theme.Colors.surface)
                            .cornerRadius(Theme.Design.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                    .stroke(Theme.Colors.divider, lineWidth: 1)
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Second row: Times
                    VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                        Text("Times")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        HStack(spacing: Theme.spacingLarge) {
                            VStack(spacing: 4) {
                                Text("Start")
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                TextField("HH:MM", text: $editedStartTime)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, Theme.spacingMedium)
                                    .padding(.vertical, Theme.spacingSmall)
                                    .background(Theme.Colors.surface)
                                    .cornerRadius(Theme.Design.cornerRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                            .stroke(Theme.Colors.divider, lineWidth: 1)
                                    )
                            }
                            .frame(maxWidth: .infinity)
                            
                            Text("—")
                                .font(Theme.Fonts.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                            
                            VStack(spacing: 4) {
                                Text("End")
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                TextField("HH:MM", text: $editedEndTime)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, Theme.spacingMedium)
                                    .padding(.vertical, Theme.spacingSmall)
                                    .background(Theme.Colors.surface)
                                    .cornerRadius(Theme.Design.cornerRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                            .stroke(Theme.Colors.divider, lineWidth: 1)
                                    )
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // Third row: Mood
                    VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                        Text("Mood (0-10)")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Picker("Mood", selection: $selectedMood) {
                            Text("-- No mood --").tag("")
                            ForEach(0...10, id: \.self) { mood in
                                Text("\(mood)").tag("\(mood)")
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, Theme.spacingMedium)
                        .padding(.vertical, Theme.spacingSmall)
                        .background(Theme.Colors.surface)
                        .cornerRadius(Theme.Design.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .stroke(Theme.Colors.divider, lineWidth: 1)
                        )
                    }
                    
                    // Fourth row: Notes (full width)
                    VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                        Text("Notes")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        TextEditor(text: $editedNotes)
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .frame(height: 120)
                            .padding(Theme.spacingLarge)
                            .background(Theme.Colors.surface)
                            .cornerRadius(Theme.Design.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                    .stroke(Theme.Colors.divider, lineWidth: 1)
                            )
                    }
                }
                
                // Buttons
                HStack {
                    Spacer()

                    Button("Cancel", role: .cancel, action: onCancel)
                        .buttonStyle(.secondary)
                        .pointingHandOnHover()
                    Spacer()
                    Button("Save", action: onSave)
                        .buttonStyle(.primary)
                        .disabled(isProjectEmpty)
                        .pointingHandOnHover()
                    Spacer()
                }
                .padding(.top)
                
            }
            .frame(minHeight: 500)
            .padding(Theme.spacingLarge)
            .background(Theme.Colors.background)
        }
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct SessionEditOptions_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            
            // Edit Session preview
            SessionEditOptions(
                editedDate: .constant("2024-01-16"),
                editedStartTime: .constant("14:00"),
                editedEndTime: .constant("16:00"),
                editedProject: .constant("Project Beta"),
                selectedMood: .constant(""),
                editedNotes: .constant("This is a much longer set of notes that should demonstrate how the notes field behaves with more content. This helps to see if the text editor properly handles longer text strings and if the layout adjusts appropriately to accommodate the content."),
                projects: ["Project Alpha", "Project Beta", "Project Gamma"],
                onSave: { print("Save clicked") },
                onCancel: { print("Cancel clicked") },
                isProjectEmpty: false
            )
            .frame(width: 800, height: 500)
            .background(Color(.windowBackgroundColor))
            
        }
    }
}
#endif
