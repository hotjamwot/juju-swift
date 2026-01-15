# 💾 Phase 4: UI - Milestone Toggle (Only After Action Exists)

This phase adds the "Milestone" checkbox/toggle to the session creation/editing UI, linked to the `isMilestone` field. This toggle should only be enabled if an "Action" has been specified.

## 🎯 Goals
- Add a "Milestone" `Toggle` (checkbox) to the session form.
- Link the toggle to the `session.isMilestone` property.
- Conditionally enable the toggle based on whether an "Action" is provided.
- Save the `isMilestone` state when the session is saved.

## 🤖 AI Execution Guidelines

### Phase Completion Protocol
1. **Complete all checklist items** in this document
2. **Test toggle functionality** thoroughly
3. **Verify conditional logic** works correctly
4. **Mark phase complete** in master checklist
5. **Document milestone functionality** for future reference

### Tool Usage Recommendations
- Use `replace_in_file` for targeted changes to SwiftUI views
- Use `read_file` to examine existing UI structure
- Use `execute_command` to build and test the application

### Error Handling Strategy
- **Binding errors**: Verify toggle properly binds to isMilestone state
- **Conditional logic**: Ensure toggle enables/disables based on action presence
- **State synchronization**: Check that isMilestone persists correctly

## 📋 Detailed Checklist

### 4.1. Add Milestone Toggle to the UI

#### 🎯 Objective: Add milestone toggle with proper labeling and placement

- [ ] **4.1.1.** In the same session form UI as Phase 3 (e.g., `Juju/Features/Sessions/SessionsRowView.swift` or its editing modal/popover), add a `Toggle` for "Milestone".
    - **Example Snippet**:
      ```swift
      Toggle("Milestone", isOn: $sessionIsMilestone)
        .padding(.top, Theme.spacingSmall)
      ```
    - Ensure it's placed logically near the "Action" field.
- [ ] **4.1.2.** Label it clearly (e.g., "Milestone"). The `Toggle` view itself takes the label string.
- [ ] **4.1.3.** Use SwiftUI's `Toggle` view. It will render as a switch on iOS/macOS.

### 4.2. Link Toggle to `isMilestone` State

#### 🎯 Objective: Ensure toggle properly binds to milestone state

- [ ] **4.2.1.** Connect the `Toggle`'s `isOn` binding to the `isMilestone` property of the session's state/ViewModel.
    - If using a ViewModel:
      - Add a property: `@Published var sessionIsMilestone: Bool = false`
      - Initialize it based on the session being edited: `sessionIsMilestone = session.isMilestone` (for existing sessions) or `false` (for new sessions).
      - Bind: `Toggle("Milestone", isOn: $viewModel.sessionIsMilestone)`
    - If state is in the View:
      - Add a property: `@State private var sessionIsMilestone: Bool = false`
      - Initialize it similarly.
      - Bind: `Toggle("Milestone", isOn: $sessionIsMilestone)`
- [ ] **4.2.2.** Ensure the state variable is properly initialized when the editing view appears or a new session is started.
- [ ] **4.2.3.** The binding should be two-way so that toggling the switch updates the state variable.

### 4.3. Implement Conditional Enablement of Milestone Toggle

#### 🎯 Objective: Ensure toggle only works when action is present

- [ ] **4.3.1.** Make the "Milestone" `Toggle` enabled/disabled based on "Action" field content.
    - This is a key UX rule: a session cannot be a milestone without an action.
    - Use the `.disabled()` modifier on the `Toggle`.
    - **Example Snippet**:
      ```swift
      Toggle("Milestone", isOn: $viewModel.sessionIsMilestone)
        .disabled(viewModel.sessionAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .padding(.top, Theme.spacingSmall)
      ```
    - If using View state: `.disabled(sessionAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)`
- [ ] **4.3.2.** Provide a visual cue for the disabled state.
    - SwiftUI's `Toggle` is usually visually distinct when disabled (e.g., greyed out).
    - Consider adding a `Text` view with a `font(.caption)` and `foregroundColor(.secondary)` to explain why it's disabled, e.g., `"*Requires an Action to be set as a Milestone"`. This text could also be disabled when the action is present.
- [ ] **4.3.3.** This prevents marking a session as a milestone if no action is specified.

### 4.4. Update Session Saving Logic to Include `isMilestone`

#### 🎯 Objective: Save milestone state to SessionRecord

- [ ] **4.4.1.** Modify the session saving logic (in the View or ViewModel, as updated in Phase 3) to also save the `sessionIsMilestone` value.
    - **Validation**: The validation for "Action is required" should still happen first.
    - **Capture `isMilestone`**: Take the value from `sessionIsMilestone` (View) or `viewModel.sessionIsMilestone` (ViewModel).
    - **Pass to Manager**: Update the call to the `SessionManager` method to include the `isMilestone` boolean.
    - **Example Call (Conceptual, modifying Phase 3's example)**:
      ```swift
      // In ViewModel or View action
      if sessionAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          // Show error: Action is required
          return
      }
      // For editing an existing session:
      try await sessionManager.updateSessionFull(sessionID: session.id,
                                               projectID: selectedProjectID,
                                               // ... other fields ...
                                               action: sessionAction, // From Phase 3
                                               isMilestone: sessionIsMilestone, // NEW: From this phase
                                               notes: sessionNotes)
      // For creating a new session, ensure the creation path also passes isMilestone.
      ```
    - Ensure the `SessionManager`'s method (e.g., `updateSessionFull` or a session creation method) and the underlying `SessionRecord` initializer correctly handle the `isMilestone` parameter.

### 4.5. Test UI for Milestone Toggle

#### 🎯 Objective: Verify toggle works correctly in all scenarios

- [ ] **4.5.1.** Verify the toggle's enabled/disabled state:
    - **Without Action**: Start a new session or edit an existing one, ensuring the "Action" field is empty. The "Milestone" toggle should be **disabled**.
    - **With Action**: Enter text into the "Action" field. The "Milestone" toggle should become **enabled**.
    - **Persist State**: Toggle the milestone on and off while enabled. Ensure the `Toggle` visually reflects the `isMilestone` state.
- [ ] **4.5.2.** Test creating sessions with various combinations:
    - New session with Action, Milestone ON. Save and verify.
    - New session with Action, Milestone OFF. Save and verify.
    - New session with Action, Milestone toggled ON then OFF before saving. Verify it saves as OFF.
- [ ] **4.5.3.** Test editing existing sessions:
    - Edit a migrated session (previously a milestone). Change its action and toggle the milestone state. Save and verify.
    - Edit a new session. Change its action and milestone state. Save and verify.
- [ ] **4.5.4.** Verify that `isMilestone` is correctly saved to the CSV and loaded back.
    - After saving such a session, restart the app and re-open the session to confirm the milestone setting is still there.
    - Check the corresponding CSV file to see if `is_milestone` is `1` or `0`.

### 4.6. (Optional but Recommended) Display Milestone Status

#### 🎯 Objective: Show milestone status visually in session lists

- [ ] **4.6.1.** Update `Juju/Features/Sessions/SessionsRowView.swift` (or the main `SessionsView.swift`) to visually indicate if `session.isMilestone` is true for existing sessions.
    - **Visual Indicator**: This could be:
        - A small icon (e.g., a star, a flag, a diamond) placed near the session's project name or time.
        - Different text styling (e.g., bolder font, different color) for the project name or a part of the action text.
        - A prefix like "[Milestone]" before the action text.
    - **Example Snippet (Conceptual, modifying Phase 3's display snippet)**:
      ```swift
      HStack(alignment: .top, spacing: Theme.spacingSmall) {
          if session.isMilestone {
              Image(systemName: "star.fill") // Or your chosen icon
                 .foregroundColor(Theme.Colors.accent) // Or a specific milestone color
                 .font(Theme.Fonts.body)
          }
          VStack(alignment: .leading, spacing: Theme.spacingTiny) {
              Text(session.projectName)
                 .font(Theme.Fonts.subheadline) // Adjust as needed
                 .fontWeight(session.isMilestone ? .semibold : .regular) // Example
              if let action = session.action, !action.isEmpty {
                  Text(action)
                     .font(Theme.Fonts.caption)
                     .foregroundColor(Theme.Colors.textSecondary)
              }
          }
      }
      ```
    - Ensure the chosen indicator is subtle but clear, and doesn't overly clutter the UI if many sessions are milestones.

## 📚 Key Considerations for This Phase

*   **UX Flow**: The conditional enabling of the toggle is crucial for a good user experience. It prevents invalid states.
*   **State Synchronization**: Ensure the `isMilestone` state in the UI/VM is correctly synchronized with the `SessionRecord` and ultimately the CSV file.
*   **Testing Combinations**: Test all combinations of Action (present/empty) and Milestone (on/off, enabled/disabled).
*   **Visual Feedback**: For both the disabled toggle state and the display of milestones in the list view.
*   **Data Integrity**: Double-check that `isMilestone` is correctly written to and read from the CSV (`1`/`0`).

## 🚨 Error Handling and Troubleshooting

### Common Issues and Solutions

**Toggle Binding Errors:**
- **State not updating**: Verify two-way binding is correctly set up
- **Initialization issues**: Check that isMilestone is properly initialized
- **Synchronization problems**: Ensure ViewModel state matches SessionRecord

**Conditional Logic Issues:**
- **Toggle not disabling**: Verify action presence check works correctly
- **Visual feedback missing**: Ensure disabled state is clearly visible
- **Logic timing**: Check that conditional updates on action changes

**State Persistence Issues:**
- **Milestone not saving**: Verify SessionManager receives correct isMilestone value
- **Data loading errors**: Check CSV parsing handles is_milestone correctly
- **UI synchronization**: Ensure toggle state matches loaded data

## 📊 Testing Strategy

### Unit Testing Recommendations
- Test ViewModel state management for isMilestone
- Verify conditional enablement logic
- Check that toggle state persists correctly

### Integration Testing
- Test complete session lifecycle with milestone combinations
- Verify that milestone state persists across app restarts
- Check that conditional logic works in all scenarios
- Validate that migrated sessions display milestone status correctly

### User Acceptance Testing
- Create sessions with all milestone/action combinations
- Edit existing sessions with different milestone states
- Test conditional enablement thoroughly
- Verify visual indicators are clear and intuitive

## 🎯 Phase Transition Checklist

### Before Proceeding to Phase 5
- [ ] Verify milestone toggle is working correctly
- [ ] Confirm conditional enablement logic
- [ ] Test all combinations of action/milestone states
- [ ] Backup current state
- [ ] Document milestone functionality
- [ ] Mark Phase 4 as complete in master checklist
- [ ] Update documentation with milestone UI changes

## 💡 SwiftUI Code Examples

### Milestone Toggle Implementation
```swift
// In session editing view, after Action field
HStack(alignment: .center, spacing: Theme.spacingSmall) {
    Toggle("Milestone", isOn: $viewModel.sessionIsMilestone)
        .disabled(viewModel.sessionAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

    if viewModel.sessionAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text("*Requires Action")
            .font(Theme.Fonts.caption)
            .foregroundColor(Theme.Colors.textSecondary)
    }
}
.padding(.top, Theme.spacingSmall)
```

### ViewModel Implementation
```swift
class SessionEditViewModel: ObservableObject {
    @Published var sessionAction: String = ""
    @Published var sessionIsMilestone: Bool = false

    // Initialize from existing session
    func loadSession(_ session: SessionRecord) {
        sessionAction = session.action ?? ""
        sessionIsMilestone = session.isMilestone
    }

    func validateAndSave() async throws {
        guard !sessionAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Show error: Action is required
            return
        }

        try await sessionManager.updateSessionFull(
            sessionID: session.id,
            action: sessionAction,
            isMilestone: sessionIsMilestone // Include milestone state
            // ... other parameters ...
        )
    }
}
```

### Milestone Display in Session Row
```swift
// Enhanced SessionsRowView with milestone indicator
HStack(alignment: .top, spacing: Theme.spacingSmall) {
    // Milestone indicator
    if session.isMilestone {
        Image(systemName: "star.fill")
            .foregroundColor(Theme.Colors.accent)
            .font(Theme.Fonts.caption)
            .padding(.trailing, Theme.spacingTiny)
    }

    // Session content
    VStack(alignment: .leading, spacing: Theme.spacingTiny) {
        HStack {
            Text(session.projectName)
                .font(Theme.Fonts.subheadline)
                .fontWeight(.semibold)

            if session.isMilestone {
                Text("🏆") // Additional visual indicator
                    .font(Theme.Fonts.caption)
            }
        }

        if let action = session.action, !action.isEmpty {
            Text(action)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary)
                .lineLimit(1)
        }

        Text(session.timeDescription)
            .font(Theme.Fonts.caption)
            .foregroundColor(Theme.Colors.textTertiary)
    }

    Spacer()
}
```

### Conditional Toggle Styling
```swift
// Enhanced toggle with better visual feedback
Toggle("Milestone", isOn: $viewModel.sessionIsMilestone)
    .disabled(viewModel.sessionAction.isEmpty)
    .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
    .padding(.top, Theme.spacingSmall)

// Helper for better disabled state visualization
if viewModel.sessionAction.isEmpty {
    Toggle("Milestone", isOn: .constant(false))
        .disabled(true)
        .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.disabled))
        .opacity(0.5)
        .overlay(
            Text("Requires Action")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.leading, Theme.spacingLarge)
        )
}
```