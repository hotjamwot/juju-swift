import SwiftUI

struct ActivityTypeAddEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var emoji: String = "📝"
    @State private var description: String = ""
    @State private var showingEmojiPicker = false
    @State private var isArchived: Bool = false
    
    var activityType: ActivityType?
    var onSave: (ActivityType) -> Void
    var onDelete: ((ActivityType) -> Void)?
    
    init(activityType: ActivityType? = nil, onSave: @escaping (ActivityType) -> Void, onDelete: ((ActivityType) -> Void)? = nil) {
        self.activityType = activityType
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    var isEditing: Bool {
        activityType != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            // Header
            HStack {
                Text(isEditing ? "Edit Activity Type" : "New Activity Type")
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
            
            // Name Field
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Activity Type Name")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                TextField("Activity Type Name", text: $name)
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
            
            // Emoji Section
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Emoji")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Button(action: {
                    showingEmojiPicker = true
                }) {
                    HStack(spacing: Theme.spacingSmall) {
                        Text(emoji)
                            .font(.system(size: 24))
                            .frame(width: 32, height: 32)
                            .background(Theme.Colors.surface)
                            .cornerRadius(Theme.Design.cornerRadius / 1.5)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius / 1.5)
                                    .stroke(Theme.Colors.divider, lineWidth: 1)
                            )
                        
                        Text("Choose Emoji")
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(Theme.spacingMedium)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
                .sheet(isPresented: $showingEmojiPicker) {
                    EmojiPickerView(selectedEmoji: $emoji)
                }
            }
            
            // Description
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Description (optional)")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                TextEditor(text: $description)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(minHeight: 100)
                    .padding(Theme.spacingLarge)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
            }
            
            // Archive Checkbox (only for editing existing activity types)
            if isEditing, let activityType = activityType {
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    HStack {
                        Toggle("Archive Activity Type", isOn: $isArchived)
                            .toggleStyle(SwitchToggleStyle())
                            .onChange(of: isArchived) { newValue in
                                if newValue {
                                    ActivityTypesViewModel.shared.archiveActivityType(activityType)
                                } else {
                                    ActivityTypesViewModel.shared.unarchiveActivityType(activityType)
                                }
                                // Don't dismiss here - let user continue editing
                            }
                        Spacer()
                    }
                    Text("Archived activity types are hidden from dropdowns but remain in your data and historical views.")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(Theme.spacingMedium)
                .background(Theme.Colors.surface)
                .cornerRadius(Theme.Design.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .stroke(Theme.Colors.divider, lineWidth: 1)
                )
                .onAppear {
                    isArchived = activityType.archived
                }
            }
            
            Spacer()
            
            HStack {
                // Archive/Unarchive Button (only for editing)
                if isEditing, let activityType = activityType {
                    Button(activityType.archived ? "Unarchive" : "Archive") {
                        let updated = ActivityType(
                            id: activityType.id,
                            name: activityType.name,
                            emoji: activityType.emoji,
                            description: activityType.description,
                            archived: !activityType.archived
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(activityType.archived ? Theme.Colors.textPrimary : Theme.Colors.error)
                    .font(Theme.Fonts.caption)
                    .padding(.horizontal, Theme.spacingExtraSmall)
                    .pointingHandOnHover()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Delete Button (only for editing, prevent deletion of uncategorized)
                if isEditing, let onDelete = onDelete, let activityType = activityType, activityType.id != "uncategorized" {
                    Button("Delete Activity Type") {
                        onDelete(activityType)
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Theme.Colors.error)
                    .font(Theme.Fonts.caption)
                    .padding(.horizontal, Theme.spacingExtraSmall)
                    .pointingHandOnHover()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Save/Create Button
                Button(isEditing ? "Save Changes" : "Create Activity Type") {
                    if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalDescription = description.isEmpty ? "" : description
                        
                        if isEditing, let activityType = activityType {
                            // Update existing activity type with current form state
                            let updatedActivityType = ActivityType(
                                id: activityType.id,
                                name: finalName,
                                emoji: emoji,
                                description: finalDescription,
                                archived: isArchived  // Use current toggle state, not original
                            )
                            onSave(updatedActivityType)
                        } else {
                            // Create new activity type
                            let newActivityType = ActivityType(
                                id: UUID().uuidString,
                                name: finalName,
                                emoji: emoji,
                                description: finalDescription,
                                archived: false
                            )
                            onSave(newActivityType)
                        }
                        
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.primary)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .pointingHandOnHover()
            }
        }
        .padding(Theme.spacingLarge)
        .frame(minWidth: 400, minHeight: 520)
        .background(Theme.Colors.background)
        .onAppear {
            if let activityType = activityType {
                name = activityType.name
                emoji = activityType.emoji
                description = activityType.description
            }
        }
    }
}

// MARK: - Emoji Picker View (Shared with Projects)
// Note: EmojiPickerView is defined in ProjectAddEditView.swift and shared between both views

// MARK: - Preview
struct ActivityTypeAddEditView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Add Activity Type Preview
            ActivityTypeAddEditView(onSave: { _ in })
                .frame(minWidth: 250, minHeight: 600)
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Add Activity Type")
            
            // Edit Activity Type Preview
            let sampleActivityType = ActivityType(
                id: "writing",
                name: "Writing", 
                emoji: "✍️", 
                description: "Drafting and creating new content",
                archived: false
            )
            ActivityTypeAddEditView(activityType: sampleActivityType, onSave: { _ in }, onDelete: { _ in })
                .frame(minWidth: 250, minHeight: 600)
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Edit Activity Type")
        }
    }
}
