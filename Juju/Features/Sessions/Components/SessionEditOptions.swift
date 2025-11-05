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
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 20, height: 20)
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
            }
            
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
                Theme.SimpleButtonStyle().makeSimpleButton(
                    label: { Text("Cancel") },
                    action: onCancel
                )
                Spacer()
                Button("Save") {
                    onSave() // The action now goes inside the closure
                }
                .buttonStyle(.primary) // Apply the new style
                .disabled(isProjectEmpty) // Use the standard disabled modifier

                Spacer()
            }
            .padding(.top)
        }
        .frame(minHeight: 500)
        .padding(Theme.spacingLarge)
        .background(Theme.Colors.background)
    }
}

// Simple button style for clean appearance
public extension Theme {
    struct SimpleButtonStyle {
        public let font: Font
        public let height: CGFloat
        public let padding: CGFloat
        public let animationDuration: Double
        
        public init(
            font: Font = Theme.Fonts.body.weight(.semibold),
            height: CGFloat = 36,
            padding: CGFloat = 16,
            animationDuration: Double = Theme.Design.animationDuration
        ) {
            self.font = font
            self.height = height
            self.padding = padding
            self.animationDuration = animationDuration
        }
        
        /// Creates a simple button without outline
        func makeSimpleButton<Content: View>(
            label: @escaping () -> Content,
            action: @escaping () -> Void,
            isDisabled: Bool = false
        ) -> some View {
            Button(action: action) {
                label()
            }
            .font(font)
            .frame(height: height)
            .padding(.horizontal, padding)
            .background(isDisabled ? Theme.Colors.surface.opacity(0.5) : Theme.Colors.surface)
            .cornerRadius(Theme.Design.cornerRadius)
            .disabled(isDisabled)
            .animation(.easeInOut(duration: animationDuration), value: isDisabled)
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
                editedDate: .constant("2024-01-15"),
                editedStartTime: .constant("09:00"),
                editedEndTime: .constant("10:30"),
                editedProject: .constant("Project Alpha"),
                selectedMood: .constant("7"),
                editedNotes: .constant("Meeting notes about the new features implementation."),
                projects: ["Project Alpha", "Project Beta", "Project Gamma"],
                onSave: { print("Save clicked") },
                onCancel: { print("Cancel clicked") },
                isProjectEmpty: false
            )
            .frame(width: 500, height: 450)
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            // Edit Session preview with longer notes
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
            .frame(width: 500, height: 450)
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            // Edit Session preview with empty project (disabled save button)
            SessionEditOptions(
                editedDate: .constant("2024-01-17"),
                editedStartTime: .constant("10:00"),
                editedEndTime: .constant("11:00"),
                editedProject: .constant(""),
                selectedMood: .constant("5"),
                editedNotes: .constant("Session with no project selected."),
                projects: ["Project Alpha", "Project Beta", "Project Gamma"],
                onSave: { print("Save clicked") },
                onCancel: { print("Cancel clicked") },
                isProjectEmpty: true
            )
            .frame(width: 500, height: 450)
            .background(Color(.windowBackgroundColor))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
