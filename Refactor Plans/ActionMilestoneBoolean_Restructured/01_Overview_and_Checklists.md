# 💾 Action & Milestone Refactor: Overview & Master Checklists

## 📋 Overview
This document outlines the refactoring to add `action: String?` and `isMilestone: Bool` fields to the `SessionRecord` data model, migrate existing data, update the UI, and deprecate the `milestoneText` field.

## 📁 Phase Documentation Structure
*   [Phase 1: Session Model Extension](./Phase1_Session_Model_Extension.md) (UI Invisible) - [COMPLETED]
*   [Phase 2: Migration Logic](./Phase2_Migration_Logic.md) (One-Off Script) - [COMPLETED]
*   [Phase 3: UI - Introduce Action](./Phase3_UI_Introduce_Action.md) (UI Visible) - [COMPLETED]
*   [Phase 4: UI - Milestone Toggle](./Phase4_UI_Milestone_Toggle.md) (UI Visible) - [COMPLETED]
*   [Phase 5: Deprecate `milestoneText`](./Phase5_Deprecate_milestoneText.md) (UI Cleanup)
*   [Phase 6: Remove `milestoneText` Completely](./Phase6_Remove_milestoneText_Completely.md) (Final Cleanup)

## 🎯 Core Changes
*   **New Fields**:
    *   `action: String?` (optional)
    *   `isMilestone: Bool` (defaults to `false`)
*   **Deprecated Field**:
    *   `milestoneText: String?` (functionally replaced by `action + isMilestone`)

---

## 🧩 Master Comprehensive Checklist

This checklist consolidates all required steps from all phases. Progress here should be tracked against the more detailed phase-specific checklists.

### Phase 1: Extend Session Model (UI Invisible) - [COMPLETED]

- [x] **1.1.** Modify `SessionRecord` in `Juju/Core/Models/SessionModels.swift`
  - [x] Added `action: String?` property
  - [x] Added `isMilestone: Bool` property
  - [x] Updated initializers with new parameters
  - [x] Updated `SessionData` struct to include new fields

- [x] **1.2.** Update CSV Schema and Parsing in `Juju/Core/Managers/Data/SessionDataParser.swift`
  - [x] Updated CSV header: `id,start_date,end_date,project_id,activity_type_id,project_phase_id,action,is_milestone,milestone_text,notes,mood`
  - [x] Added parsing logic for `action` and `is_milestone` columns
  - [x] Implemented `parseBool()` helper method
  - [x] Backward compatibility for old CSV files without new columns

- [x] **1.3.** Update Export Logic in `Juju/Core/Managers/Data/SessionDataParser.swift`
  - [x] CSV exports include new fields with correct formatting

- [x] **1.4.** Update Session Creation Logic in `Juju/Core/Managers/SessionManager.swift`
  - [x] Modified `activeSession` property
  - [x] All new sessions include defaults: `action: nil`, `isMilestone: false`

- [x] **1.5.** Update Session Updating Logic in `Juju/Core/Managers/SessionManager.swift`
  - [x] `updateSession` method preserves new fields
  - [x] `editSession` method preserves new fields

- [x] **1.6.** Update Usage in Extensions and Other Managers
  - [x] Extensions reviewed; no changes needed
  - [ ] ChartDataPreparer: Deferred to Phase 5-6 cleanup
  - [ ] NarrativeEngine: Deferred to Phase 5-6 cleanup
  - [ ] DataValidator: Optional validation rules for future phases

- [x] **1.7.** Compile and Test Phase 1
  - [x] Build succeeded with all updates
  - [x] Documentation updated (ARCHITECTURE.md)
  - [ ] Runtime testing: Create/save/load sessions (deferred to Phase 1.7.3)

### Phase 2: Migration Logic (One-Off, Scriptable) - [COMPLETED]

#### 2.1. Create Python Migration Script
- [x] **2.1.1.** Write a Python script (`migrate_sessions.py`).
- [x] **2.1.2.** **Script Logic**:
    - [x] Iterate through session data files (`2024-data.csv`, `2025-data.csv`, `2026-data.csv`).
    - [x] For each session:
        - [x] If `milestoneText` is non-empty:
            - [x] Set `action = milestoneText`
            - [x] Set `isMilestone = true` (represented as `1` in CSV).
        - [x] Else:
            - [x] Set `action = ""` (empty string representation)
            - [x] Set `isMilestone = false` (represented as `0` in CSV).
    - [x] Do NOT delete the `milestoneText` column (kept for historical safety).
    - [x] Handle CSV reading/writing with proper quoting.
    - [x] Include logging/progress output.
- [x] **2.1.3.** Test the script on a copy of data files first. Backed up original data files (user handled).

#### 2.2. Locate Data Files
- [x] **2.2.1.** Confirmed the exact path to Juju's session data CSV files (`~/Library/Application Support/Juju/`).

#### 2.3. Run the Migration Script
- [x] **2.3.1.** Executed the Python script on the identified data files.
- [x] **2.3.2.** Monitored for errors (none encountered, all files processed successfully).

#### 2.4. Verify Migration
- [x] **2.4.1.** Script processed files: `2026-data.csv` (7 sessions), `2025-data.csv` (711 sessions), `2024-data.csv` (439 sessions).
- [x] **2.4.2.** Script output indicates sessions with old `milestoneText` now have corresponding `action` and `is_milestone` values.
- [x] **2.4.3.** Script indicates sessions without `milestoneText` have appropriate defaults (action: "", is_milestone: 0).

### Phase 3: UI – Introduce Action (Quietly) - [COMPLETED]

#### 3.1. Identify UI Files for Session Input
- [x] **3.1.1.** Locate SwiftUI views where session details are entered/edited (e.g., a modal, `SessionsRowView` for inline editing, or a dedicated session creation form).
- [x] **3.1.2.** Likely candidates within `Juju/Features/Sessions/`.

#### 3.2. Add Action Text Field to the UI
- [x] **3.2.1.** In the identified view, add a new `TextField` for "Action".
- [x] **3.2.2.** Make it **single-line**.
- [x] **3.2.3.** Give it a **clear label** (e.g., "Action:", "Session Action:").
- [x] **3.2.4.** Ensure it's **required (compulsory)** input (e.g., validation to ensure it's not empty on save).
- [x] **3.2.5.** Place it logically within the form, near "Notes".
- [x] **3.2.6.** Do not remove the "Notes" field.

#### 3.3. Update ViewModel/State to Capture Action
- [x] **3.3.1.** If a ViewModel is used for the session form, update it to store the "Action" value.
- [x] **3.3.2.** Add a property (e.g., `@State private var sessionAction: String = ""` in View, or corresponding in ViewModel).
- [x] **3.3.3.** Bind the new `TextField` to this state/ViewModel property.

#### 3.4. Update Session Saving Logic to Include Action
- [x] **3.4.1.** Modify the function that saves a session to include the `action` value from the UI state/ViewModel.
- [x] **3.4.2.** The `isMilestone` field should be set to its default `false` at this stage.

#### 3.5. Test UI for Action Field
- [x] **3.5.1.** Run the app and test the new "Action" field.
- [x] **3.5.2.** Create new sessions and ensure the "Action" is saved and displayed.
- [x] **3.5.3.** Check that existing migrated sessions display their `action` correctly (if UI also shows existing actions - see 3.6).

#### 3.6. (Optional but Recommended) Display Existing Actions
- [x] **3.6.1.** Update `SessionsRowView` or other session display components to show the `session.action` value for existing sessions.
- [x] **3.6.2.** Decide on concise formatting if action text is long.

#### 3.7. Fix CSV Parsing for Column Order Flexibility
- [x] **3.7.1.** Updated `SessionDataParser` to build column index map from header instead of assuming fixed positions.
- [x] **3.7.2.** Parser now handles CSV files with action/is_milestone columns in any position.
- [x] **3.7.3.** Tested with migrated data files - all sessions load correctly.

### Phase 3: UI – Introduce Action (UI Visible) - [COMPLETED]

- [x] **3.1.** Identify UI Files for Session Input
  - [x] Located SwiftUI views in `Juju/Features/Sessions/SessionsRowView.swift`
  - [x] Found session editing components in `Juju/Features/Sessions/Components/InlineSelectionPopover.swift`

- [x] **3.2.** Add Action Text Field to the UI
  - [x] Created `ActionSelectionPopover` component (mirror of `MilestoneSelectionPopover`)
  - [x] Single-line text input with clear "Edit Action" label
  - [x] Integrated popover into `SessionsRowView` with bolt icon (⚡)

- [x] **3.3.** Update ViewModel/State to Capture Action
  - [x] Added `@State private var actionText: String = ""` in SessionsRowView
  - [x] Added `@State private var showingActionPopover = false` for popover state
  - [x] Added `@State private var isActionHovering = false` for hover effects

- [x] **3.4.** Update Session Saving Logic to Include Action
  - [x] Created `updateSessionAction()` method in SessionsRowView
  - [x] Updated `updateSessionFull()` method signature to accept `action` and `isMilestone` parameters
  - [x] All existing `updateSessionFull` calls updated to pass action and isMilestone

- [x] **3.5.** Test UI for Action Field
  - [x] App builds successfully
  - [x] Action field appears in SessionsView with editable text
  - [x] Existing migrated sessions display action text correctly
  - [x] New sessions can have action set and saved

- [x] **3.6.** Display Existing Actions
  - [x] `SessionsRowView` displays session.action value with bolt icon
  - [x] Shows empty icon when no action present

### Phase 4: UI – Milestone Toggle (Only After Action Exists) - [COMPLETED]

#### 4.1. Add Milestone Toggle to the UI
- [x] **4.1.1.** In the same session form UI as Phase 3, add a `Toggle` (checkbox) for "Milestone".
  - [x] Added milestone toggle to `ActionSelectionPopover` in `Juju/Features/Sessions/Components/InlineSelectionPopover.swift`
  - [x] Toggle is displayed with proper label "Milestone"
  - [x] Uses SwiftUI's `Toggle` view with correct binding
- [x] **4.1.2.** Label it clearly (e.g., "Milestone").
- [x] **4.1.3.** Use a `Toggle` view from SwiftUI.

#### 4.2. Link Toggle to `isMilestone` State
- [x] **4.2.1.** Connect the `Toggle` to the `isMilestone` property of the session's state/ViewModel.
  - [x] Added `@State private var sessionIsMilestone: Bool = false` to SessionsRowView
  - [x] Properly initialized from session in init method: `self._sessionIsMilestone = State(initialValue: session.isMilestone)`
- [x] **4.2.2.** Added state variable for milestone tracking.
- [x] **4.2.3.** Bind toggle correctly: implemented with proper binding in ActionSelectionPopover.

#### 4.3. Implement Conditional Enablement of Milestone Toggle
- [x] **4.3.1.** Make the "Milestone" `Toggle` enabled/disabled based on "Action" field content.
  - [x] Added `.disabled()` modifier to toggle in ActionSelectionPopover
  - [x] Condition: `.disabled(actionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)`
- [x] **4.3.2.** Proper conditional logic implemented.
- [x] **4.3.3.** Prevents marking a session as a milestone if no action is specified.

#### 4.4. Update Session Saving Logic to Include `isMilestone`
- [x] **4.4.1.** Modify session saving logic to also save the `sessionIsMilestone` value to `SessionRecord`.
  - [x] Updated `ActionSelectionPopover` to use single `onSaveAction` callback that passes both action and isMilestone
  - [x] Modified SessionsRowView to update `sessionIsMilestone` state before calling `updateSessionAction`
  - [x] `updateSessionAction` method updated to use `sessionIsMilestone` state when calling `SessionManager.shared.updateSessionFull`
  - [x] `refreshSessionData()` enhanced to reload session from SessionManager and sync `sessionIsMilestone` state
  - [x] CSV persistence confirmed working through `convertSessionsToCSV` method

#### 4.5. Test UI for Milestone Toggle
- [x] **4.5.1.** Verify the toggle's enabled/disabled state based on action presence.
  - [x] Toggle disabled when "Action" field is empty
  - [x] Toggle enabled when "Action" has text
- [x] **4.5.2.** Test creating sessions with various combinations.
  - [x] New session with Action, Milestone ON - saves correctly
  - [x] New session with Action, Milestone OFF - saves correctly
  - [x] Toggle state persists and reflects in CSV data
- [x] **4.5.3.** Verify that `isMilestone` is correctly saved to CSV and loaded back.
  - [x] CSV data now contains `is_milestone` field with values `1` or `0`
  - [x] Sessions reload correctly with their milestone status preserved

#### 4.6. Display Milestone Status
- [x] **4.6.1.** Update `SessionsRowView` to visually indicate if `session.isMilestone` is true.
  - [x] Milestone indicator already implemented in action display section
  - [x] Shows visual indicator when `session.isMilestone` is true

### Phase 5: Deprecate `milestoneText` (UI Only)

#### 5.1. Hide `milestoneText` from Session Display UI
- [ ] **5.1.1.** Remove any UI elements that display `session.milestoneText` (e.g., from `SessionsRowView`).
- [ ] **5.1.2.** Replace/supplement with display of `session.action` and the milestone indicator.

#### 5.2. Stop Writing to `milestoneText` in UI Logic
- [ ] **5.2.1.** Ensure UI logic does not attempt to update or set the `session.milestoneText` field of a session. This should be handled by the shift to `action` and `isMilestone`.

#### 5.3. (Future Consideration) Remove `milestoneText` from Data Model and Persistence
- [ ] **5.3.1.** This is NOT part of Phase 5 but a future cleanup step.
- [ ] **5.3.2.** Once stable, consider removing `milestoneText` from:
    - `SessionRecord` struct.
    - CSV headers and parsing logic.
    - Any other references.
- [ ] **5.3.3.** Update `Documentation/ARCHITECTURE.md` and `Documentation/DATA_FLOW.yaml` when the field is fully removed.

#### 5.4. Final Testing
- [ ] **5.4.1.** Conduct thorough end-to-end testing.
- [ ] **5.4.2.** Create sessions with various combinations of action and milestone status.
- [ ] **5.4.3.** Edit existing sessions.
- [ ] **5.4.4.** Verify data integrity for `action` and `isMilestone`.
- [ ] **5.4.5.** Verify `milestoneText` is no longer visible/influencing UI.
- [ ] **5.4.6.** Check dashboard/chart displays for any adverse impacts.

---

## 📚 Key Principles & Best Practices

*   **Adhere to MVVM Religiously**:
    *   **Views (`Juju/Features/`)**: Only UI code. Use `@State` and `@StateObject`. No business logic.
    *   **ViewModels (`Juju/Core/ViewModels/`)**: State management, data transformation, commands. `@Published` properties. Call Managers.
    *   **Managers (`Juju/Core/Managers/`)**: Single source of truth for data. Business logic, validation, persistence.
*   **Leverage Managers for Data Operations**: All session operations through `SessionManager`.
*   **Incremental Changes and Thorough Testing**: Complete one phase at a time. Build and test frequently.
*   **Data Integrity and Migration**: Backups are crucial. Validate migration script on copies of data.
*   **Code and Documentation Sync**: Update `ARCHITECTURE.md` and `DATA_FLOW.yaml` as data models or flow change.
*   **Error Handling**: Use `ErrorHandler.shared` and `JujuError`.
*   **Concurrency**: `@MainActor` for UI, `async/await` for background operations.
*   **Checklist Usage**: Use phase-specific checklists for daily work and this master checklist for overall tracking. Be specific about file paths and code sections in checklists.

## 🤖 AI Execution Guidelines

### Phase Completion Protocol
After completing each phase:
1.  **Mark phase as complete** in the master checklist
2.  **Update all documentation** (ARCHITECTURE.md, DATA_FLOW.yaml)
3.  **Run comprehensive tests** to ensure no regressions
4.  **Create backup** before proceeding to next phase
5.  **Document any issues** encountered for future reference

### Tool Usage Recommendations
- Use `replace_in_file` for targeted changes to existing files
- Use `write_to_file` for creating new files
- Use `execute_command` for building/testing the application
- Always compile and test after major changes

### Error Handling Strategy
1.  **Compilation Errors**: Check all SessionRecord initializers and method signatures
2.  **Runtime Errors**: Verify CSV parsing handles both old and new formats
3.  **UI Issues**: Ensure all views properly bind to updated data models
4.  **Data Integrity**: Validate that migration preserves all existing data

### Context Management
- Each phase should be completable within a single AI session
- If a phase is too large, break it into sub-phases (e.g., 1A, 1B, 1C)
- Use clear SEARCH/REPLACE blocks for file modifications
- Document the final state after each modification

## 🎯 Phase Transition Checklist

### Phase 1 → Phase 2 Transition
- [x] Verify SessionRecord model updates are working
- [x] Confirm CSV parsing handles both old and new formats
- [x] Test that new sessions can be created and saved
- [x] Backup all session data files
- [x] Document current state before migration

### Phase 2 → Phase 3 Transition
- [ ] Verify migration script completed successfully
- [ ] Confirm migrated data loads correctly in app
- [ ] Test that both old and new sessions display properly
- [ ] Backup migrated data files
- [ ] Document migration results and any issues

### Phase 3 → Phase 4 Transition
- [ ] Verify Action field is working in UI
- [ ] Confirm action data is saved and loaded correctly
- [ ] Test action validation (required field)
- [ ] Backup current state
- [ ] Document UI changes and testing results

### Phase 4 → Phase 5 Transition
- [ ] Verify milestone toggle is working correctly
- [ ] Confirm conditional enablement logic
- [ ] Test all combinations of action/milestone states
- [ ] Backup current state
- [ ] Document milestone functionality

### Phase 5 → Phase 6 Transition
- [ ] Verify milestoneText is completely hidden from UI
- [ ] Confirm all functionality works with new fields
- [ ] Test end-to-end session lifecycle
- [ ] Backup final state before cleanup
- [ ] Document deprecation completion

## 🚨 Error Handling and Troubleshooting

### Common Issues and Solutions

**Compilation Errors:**
- **Missing initializers**: Ensure all SessionRecord initializers include new parameters
- **Method signature mismatches**: Update all manager methods to use new field names
- **CSV parsing errors**: Verify header format and column mapping

**Runtime Issues:**
- **Data loading failures**: Check CSV file permissions and format
- **UI binding errors**: Verify ViewModel properties match SessionRecord fields
- **Validation failures**: Ensure required fields are properly validated

**Migration Problems:**
- **Script execution errors**: Test on backup data first
- **Data corruption**: Verify CSV format before and after migration
- **Missing data**: Check that all milestoneText values were migrated

**UI Display Issues:**
- **Missing action display**: Verify SessionsRowView updates
- **Toggle not working**: Check conditional enablement logic
- **Visual inconsistencies**: Review theme application and spacing

## 📊 Testing Strategy

### Unit Testing Recommendations
- Create test CSV files with various formats (old, new, mixed)
- Write unit tests for SessionDataParser with different scenarios
- Test SessionManager methods with new fields
- Verify ViewModel state management

### Integration Testing
- Test complete session lifecycle (create, edit, save, load)
- Verify dashboard displays work with new data structure
- Check that all managers handle new fields correctly
- Validate that notifications work with updated data

### User Acceptance Testing
- Create sessions with all field combinations
- Edit existing sessions (migrated and new)
- Test error conditions and validation
- Verify UI is intuitive and functional

This enhanced planning document provides comprehensive guidance for AI execution while maintaining the original structure and adding critical execution details, error handling strategies, and phase transition protocols.
