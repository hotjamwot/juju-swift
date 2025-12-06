import SwiftUI

/// Sidebar view for editing activity type details with enhanced layout
struct ActivityTypeSidebarEditView: View {
    @EnvironmentObject var sidebarState: SidebarStateManager
    @EnvironmentObject var activityTypesViewModel: ActivityTypesViewModel
    
    @State private var activityType: ActivityType
    @State private var tempName: String
    @State private var tempEmoji: String
    @State private var tempDescription: String
    @State private var tempArchived: Bool
    
    // Form validation
    @State private var hasChanges = false
    @State private var isSaving = false
    @State private var showingEmojiPicker = false
    
    init(activityType: ActivityType) {
        self._activityType = State(initialValue: activityType)
        self._tempName = State(initialValue: activityType.name)
        self._tempEmoji = State(initialValue: activityType.emoji)
        self._tempDescription = State(initialValue: activityType.description)
        self._tempArchived = State(initialValue: activityType.archived)
    }
    
    var body: some View {
        VStack(spacing: Theme.spacingMedium) {
            // Live preview section
            livePreviewSection
            
            // Basic info section
            basicInfoSection
            
            // Description section
            descriptionSection
            
            // Archive toggle
            archiveSection
            
            // Action buttons
            actionButtons
        }
        .formStyle(.grouped)
        .onChange(of: tempName) { _ in validateChanges() }
        .onChange(of: tempEmoji) { _ in validateChanges() }
        .onChange(of: tempDescription) { _ in validateChanges() }
        .onChange(of: tempArchived) { _ in validateChanges() }
    }
    
    private var livePreviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Live Preview")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                HStack {
                    // Activity type preview
                    VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                        HStack {
                            Text(tempEmoji)
                                .font(.title2)
                            Text(tempName.isEmpty ? "Activity Type Name" : tempName)
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.Colors.divider, lineWidth: 1)
                            )
                    )
                    
                    Spacer()
                }
            }
            .padding()
        }
        .background(Theme.Colors.surface)
        .cornerRadius(8)
    }
    
    private var basicInfoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Basic Info")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                VStack(spacing: Theme.spacingMedium) {
                    // Name field
                    VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                        Text("Activity Type Name")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        TextField("Enter activity type name", text: $tempName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Emoji selection
                    HStack {
                        Text("Emoji")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Button(action: {
                            showingEmojiPicker = true
                        }) {
                            HStack {
                                Text(tempEmoji)
                                    .font(.title2)
                                Text("Change Emoji")
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showingEmojiPicker) {
                            EmojiPickerView(selectedEmoji: $tempEmoji)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Theme.Colors.surface)
        .cornerRadius(8)
    }
    
    private var descriptionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Description")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                TextEditor(text: $tempDescription)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Theme.Colors.background)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
            }
            .padding()
        }
        .background(Theme.Colors.surface)
        .cornerRadius(8)
    }
    
    private var archiveSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Archive Activity Type")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                HStack {
                    Toggle("Archive this activity type", isOn: $tempArchived)
                    Spacer()
                    Text(tempArchived ? "Archived" : "Active")
                        .font(.caption)
                        .foregroundColor(tempArchived ? .red : .green)
                }
            }
            .padding()
        }
        .background(Theme.Colors.surface)
        .cornerRadius(8)
    }
    
    private var actionButtons: some View {
        HStack {
            Button("Cancel") {
                sidebarState.hide()
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Spacer()
            
            Button(activityType.id.isEmpty ? "Create" : "Save") {
                saveActivityType()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!hasChanges || isSaving || tempName.isEmpty)
            .opacity((hasChanges && !tempName.isEmpty) ? 1.0 : 0.5)
        }
        .padding(.horizontal)
    }
    
    private func validateChanges() {
        hasChanges = (
            tempName != activityType.name ||
            tempEmoji != activityType.emoji ||
            tempDescription != activityType.description ||
            tempArchived != activityType.archived
        )
    }
    
    private func saveActivityType() {
        isSaving = true
        
        // Create updated activity type
        let updatedActivityType = ActivityType(
            id: activityType.id,
            name: tempName,
            emoji: tempEmoji,
            description: tempDescription,
            archived: tempArchived
        )
        
        // Save using ActivityTypesViewModel
        if activityType.id.isEmpty {
            // Creating new activity type
            activityTypesViewModel.addActivityType(
                name: tempName,
                emoji: tempEmoji,
                description: tempDescription
            )
        } else {
            // Updating existing activity type
            activityTypesViewModel.updateActivityType(updatedActivityType)
        }
        
        // Update local activity type copy
        activityType = updatedActivityType
        hasChanges = false
        
        // Close sidebar after successful save
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            sidebarState.hide()
        }
        
        isSaving = false
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct ActivityTypeSidebarEditView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleActivityType = ActivityType(
            id: UUID().uuidString,
            name: "Sample Activity Type",
            emoji: "⚡",
            description: "",
            archived: false
        )
        
        return ActivityTypeSidebarEditView(activityType: sampleActivityType)
            .environmentObject(SidebarStateManager())
            .environmentObject(ActivityTypesViewModel())
            .frame(width: 420)
            .padding()
    }
}
#endif
