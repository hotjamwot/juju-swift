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
        VStack(spacing: Theme.spacingExtraLarge) {
            // Top section - name, emoji, and description
            VStack(spacing: Theme.spacingExtraLarge) {
                // Combined basic info section (name and emoji)
                basicInfoSection
                
                // Description section
                descriptionSection
            }
            
            Spacer()
            
            // Bottom section - archive toggle and action buttons
            VStack(spacing: Theme.spacingExtraLarge) {
                // Archive toggle (standalone)
                archiveSection
                
                // Action buttons
                actionButtons
            }
        }
        .padding(Theme.spacingLarge)
        .onChange(of: tempName) { _ in validateChanges() }
        .onChange(of: tempEmoji) { _ in validateChanges() }
        .onChange(of: tempDescription) { _ in validateChanges() }
        .onChange(of: tempArchived) { _ in validateChanges() }
    }
    
    private var basicInfoSection: some View {
        VStack(spacing: Theme.spacingLarge) {
            // Name field - label on left, field on right
            HStack {
                Text("Name")
                    .font(.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 80, alignment: .leading)
                TextField("", text: $tempName)
                    .textFieldStyle(.plain)
                    .padding(Theme.spacingSmall)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .frame(maxWidth: .infinity)
            }
            
            // Emoji selection
            HStack {
                Text("Emoji")
                    .font(.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                Spacer()
                Button(action: {
                    showingEmojiPicker = true
                }) {
                    HStack {
                        Text(tempEmoji)
                            .font(.title2)
                        Text("Change")
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
        .padding(Theme.spacingMedium)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            Text("Description")
                .font(.body)
                .foregroundColor(Theme.Colors.textSecondary)
            TextEditor(text: $tempDescription)
                .frame(minHeight: 120, maxHeight: 160)
                .textFieldStyle(.plain)
                .padding(Theme.spacingSmall)
                .background(Theme.Colors.surface)
                .cornerRadius(Theme.Design.cornerRadius)
                .frame(maxWidth: .infinity)
        }
        .padding(Theme.spacingMedium)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
    }
    
    private var archiveSection: some View {
        HStack {
            Toggle("", isOn: $tempArchived)
            Spacer()
            Text(tempArchived ? "Archived" : "Active")
                .font(.caption)
                .foregroundColor(tempArchived ? .red : .green)
        }
        .padding(Theme.spacingMedium)
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
        .padding(Theme.spacingMedium)
        .padding(.bottom, Theme.spacingLarge)
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
            .frame(width: 420, height: 900)
            .padding()
    }
}
#endif
