# 💾 Phase 3: UI - Introduce Action (Quietly)

This phase adds the "Action" text field to the session creation/editing UI. The goal is to make the new `action` field usable by the user, while `isMilestone` remains defaulted to `false` in the background for now.

## 🎯 Goals
- Add a "Action" text field to session input UI.
- Capture the entered action and save it to the `SessionRecord.action` field.
- Ensure the new field is a compulsory input.

## 🤖 AI Execution Guidelines

### Phase Completion Protocol
1. **Complete all checklist items** in this document
2. **Test UI functionality** thoroughly
3. **Verify data binding** works correctly
4. **Mark phase complete** in master checklist
5. **Document UI changes** for future reference

### Tool Usage Recommendations
- Use `replace_in_file` for targeted changes to SwiftUI views
- Use `read_file` to examine existing UI structure
- Use `execute_command` to build and test the application

### Error Handling Strategy
- **UI binding errors**: Verify ViewModel properties match SessionRecord fields
- **Validation failures**: Ensure required fields are properly validated
- **Layout issues**: Check theme application and spacing

## 📋 Detailed Checklist

### 3.1. Identify UI Files for Session Input

#### 🎯 Objective: Locate the correct SwiftUI views for session editing

- [ ] **3.1.1.** Locate SwiftUI views where session details are entered/edited.
    - **Primary Candidates**:
        - `Juju/Features/Sessions/SessionsRowView.swift`: This likely handles inline editing of sessions, possibly via a popover or modal triggered by a tap on a session row.
        - Any dedicated session creation modal or view. This might be part of `SessionsView.swift` or a separate file.
    - **Investigation**: Read `SessionsRowView.swift` and `SessionsView.swift` to understand how session editing and creation are currently handled. Look for `TextField` for notes, `Picker` for project/phase, etc.
- [ ] **3.1.2.** Note the exact View(s) that need modification. It might be a single view or multiple depending on where session editing occurs (e.g., one for creating a new session, one for editing an existing one).

### 3.2. Add Action Text Field to the UI

#### 🎯 Objective: Add compulsory Action field to session form

- [ ] **3.2.1.** In the identified view(s), add a new `TextField` for "Action".
    - **Example Snippet**:
      ```swift
      TextField("Action *", text: $sessionAction)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .padding(.top, Theme.spacingSmall)
      ```
    - **Single-line**: Ensure it's a single-line `TextField`. If it becomes multi-line by default, limit its height or use a different approach.
- [ ] **3.2.2.** Give it a **clear label**.
    - Use a `Text` view as a label, e.g., `Text("Action *")`. The `*` can indicate it's required.
    - Ensure the label is distinct from "Notes".
- [ ] **3.2.3.** Ensure it's **required (compulsory)** input.
    - This will be primarily enforced in the ViewModel or save logic (see 3.4), but the UI can hint at it (e.g., label with `*`).
    - Consider adding validation feedback if the field is empty when trying to save (e.g., show an error message or highlight the field).
- [ ] **3.2.4.** Place it logically within the form.
    - A good place might be just below the "Notes" `TextField` or above it, depending on the existing flow.
    - Follow the existing UI layout patterns and spacing (use `Theme.spacing...`).
- [ ] **3.2.5.** Do not remove the "Notes" field.

### 3.3. Update ViewModel/State to Capture Action

#### 🎯 Objective: Ensure UI state properly captures action input

- [ ] **3.3.1.** If a ViewModel is used for the session form (e.g., an `EditSessionViewModel` or similar, or perhaps `SessionsViewModel` if it handles state for editing rows):
    - Add a property to store the "Action" value.
      - Example in ViewModel: `@Published var sessionAction: String = ""`
    - If editing an existing session, this property should be initialized with `session.action ?? ""`.
    - If creating a new session, it should default to an empty string.
- [ ] **3.3.2.** If there's no dedicated ViewModel and state is managed directly in the View:
    - Add a `@State private var sessionAction: String = ""` property to the View.
    - Initialize it based on whether an existing session is being edited or a new one is being created.
- [ ] **3.3.3.** Bind the new `TextField` to this state/ViewModel property.
    - Example: `TextField("Action *", text: $viewModel.sessionAction)` (if in ViewModel) or `TextField("Action *", text: $sessionAction)` (if in View).
    - Ensure the binding is two-way.

### 3.4. Update Session Saving Logic to Include Action

#### 🎯 Objective: Validate and save action data to SessionRecord

- [ ] **3.4.1.** Locate the function in the View or ViewModel that handles saving the session.
    - This could be a method like `saveSession()`, `doneEditing()`, or a button action that triggers the save.
- [ ] **3.4.2.** Modify this function to:
    - **Validate**: Check if `sessionAction` is empty or just whitespace. If it is, prevent saving and provide user feedback (e.g., an alert, a visual indicator).
    - **Capture Action**: If valid, take the value from `sessionAction` (View) or `viewModel.sessionAction` (ViewModel).
    - **Pass to Manager**: Call the appropriate `SessionManager` method (e.g., `updateSessionFull` for edits, or a new method for creation if not using `startSession`/`endSession` flow) and pass the captured action string.
    - **Default `isMilestone`**: Ensure that when saving, `isMilestone` is passed as `false` (its default) for now, as the toggle isn't implemented yet. The `SessionRecord` initializer or the `SessionManager` method should handle this default.
    - **Example Call (Conceptual)**:
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
                                               action: sessionAction,
                                               isMilestone: false, // Default for now
                                               notes: sessionNotes)
      // Or for creating a new session via a different path
      ```

### 3.5. Test UI for Action Field

#### 🎯 Objective: Verify action field works correctly in all scenarios

- [ ] **3.5.1.** Run the app and test the new "Action" field thoroughly.
    - **Creation**: Create a new session. Ensure the Action field is present, required, and its content is saved.
    - **Editing**: Edit an existing session. If it's a migrated session, it might have an `action` already. If it's a new session, it should be empty. Ensure you can change the action and save it.
    - **Save Without Action**: Try to save a session (new or edited) without entering anything in the Action field. The app should prevent this and show a clear error.
- [ ] **3.5.2.** Create new sessions and ensure the "Action" is saved and can be retrieved.
    - After saving, close and reopen the session, or restart the app, to verify the action text persists.
- [ ] **3.5.3.** Check that existing migrated sessions display their `action` correctly if the UI now shows it.
    - This depends on whether you implement 3.6. If not, the action is saved but not yet visible in `SessionsRowView` for old sessions.

### 3.6. (Optional but Recommended) Display Existing Actions

#### 🎯 Objective: Show action text in session list views

- [ ] **3.6.1.** Update `Juju/Features/Sessions/SessionsRowView.swift` (or the main `SessionsView.swift` if it displays session summaries).
    - Modify the part of the UI that shows session details to include `session.action`.
    - **Formatting**: Since `action` might be long, decide on a concise way to display it.
      - Truncate with an ellipsis: `Text(session.action.prefix(30)) + (session.action.count > 30 ? "..." : "")`
      - Show it on a second line if space allows.
      - If it's very verbose, perhaps just show an indicator that an action exists and show the full text in a detail view (e.g., the editing popover).
    - **Example Snippet (Conceptual)**:
      ```swift
      VStack(alignment: .leading, spacing: Theme.spacingTiny) {
          Text(session.projectName) // Existing project name
          if let action = session.action, !action.isEmpty {
              Text(action)
                 .font(Theme.Fonts.caption)
                 .foregroundColor(Theme.Colors.textSecondary)
          }
          // ... other details like time, notes (truncated) ...
      }
      ```
- [ ] **3.6.2.** Decide on concise formatting if action text is long.
    - Ensure the display doesn't break the UI layout.

## 📚 Key Considerations for This Phase

*   **Required Field**: Enforce the "Action is required" rule strictly. Provide clear UI feedback.
*   **UI Consistency**: Follow existing UI patterns, theming (`Theme.swift`), and layout.
*   **State Management**: Be clear about whether state is in the View or a ViewModel.
*   **Testing**: Test both creating new sessions and editing existing ones. Test the validation.
*   **`isMilestone` Default**: Remember to pass `isMilestone: false` when saving, as the UI for setting it isn't here yet.

## 🚨 Error Handling and Troubleshooting

### Common Issues and Solutions

**UI Binding Errors:**
- **State not updating**: Verify two-way binding is correctly set up
- **ViewModel synchronization**: Ensure ViewModel properties are properly published
- **Initialization issues**: Check that state is properly initialized for new/edited sessions

**Validation Problems:**
- **Required field bypass**: Verify validation logic is comprehensive
- **Error feedback missing**: Ensure clear error messages are shown
- **Whitespace handling**: Check that trimming works correctly

**Layout Issues:**
- **Field placement**: Follow existing UI patterns and spacing
- **Theme application**: Use Theme.swift for consistent styling
- **Responsive design**: Ensure field works on different screen sizes

## 📊 Testing Strategy

### Unit Testing Recommendations
- Test ViewModel state management
- Verify validation logic for required fields
- Check that error messages are displayed correctly

### Integration Testing
- Test complete session creation flow
- Verify session editing functionality
- Check that action data persists across app restarts
- Validate that migrated sessions display correctly

### User Acceptance Testing
- Create sessions with various action texts
- Edit existing sessions with different action values
- Test error conditions (empty action, whitespace-only)
- Verify UI is intuitive and functional

## 🎯 Phase Transition Checklist

### Before Proceeding to Phase 4
- [ ] Verify Action field is working in UI
- [ ] Confirm action data is saved and loaded correctly
- [ ] Test action validation (required field)
- [ ] Backup current state
- [ ] Document UI changes and testing results
- [ ] Mark Phase 3 as complete in master checklist
- [ ] Update documentation with UI changes

## 💡 SwiftUI Code Examples

### Action TextField Implementation
```swift
// In session editing view
Text("Action *")
  .font(Theme.Fonts.subheadline)
  .foregroundColor(Theme.Colors.textPrimary)
  .padding(.top, Theme.spacingSmall)

TextField("Enter session action", text: $viewModel.sessionAction)
  .textFieldStyle(RoundedBorderTextFieldStyle())
  .padding(.bottom, Theme.spacingSmall)

// Validation error display
if viewModel.showActionError {
    Text("Action is required")
        .font(Theme.Fonts.caption)
        .foregroundColor(Theme.Colors.error)
        .padding(.bottom, Theme.spacingTiny)
}
```

### ViewModel Implementation
```swift
class SessionEditViewModel: ObservableObject {
    @Published var sessionAction: String = ""
    @Published var showActionError: Bool = false

    // Other properties...

    func validateAndSave() async throws {
        guard !sessionAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showActionError = true
            return
        }

        showActionError = false

        try await sessionManager.updateSessionFull(
            sessionID: session.id,
            action: sessionAction,
            isMilestone: false // Default for Phase 3
            // ... other parameters ...
        )
    }
}
```

### Session Display in Row
```swift
// In SessionsRowView
HStack(alignment: .top, spacing: Theme.spacingSmall) {
    VStack(alignment: .leading, spacing: Theme.spacingTiny) {
        Text(session.projectName)
            .font(Theme.Fonts.subheadline)
            .fontWeight(.semibold)

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

    // Existing session controls...
}
```
