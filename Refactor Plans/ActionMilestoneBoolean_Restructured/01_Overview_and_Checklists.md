# 💾 Action & Milestone Refactor: Overview & Master Checklists

## 📋 Overview
This document outlines the refactoring to add `action: String?` and `isMilestone: Bool` fields to the `SessionRecord` data model, migrate existing data, update the UI, and deprecate the `milestoneText` field.

## 📁 Phase Documentation Structure
*   [Phase 1: Session Model Extension](./Phase1_Session_Model_Extension.md) (UI Invisible)
*   [Phase 2: Migration Logic](./Phase2_Migration_Logic.md) (One-Off Script)
*   [Phase 3: UI - Introduce Action](./Phase3_UI_Introduce_Action.md) (UI Visible)
*   [Phase 4: UI - Milestone Toggle](./Phase4_UI_Milestone_Toggle.md) (UI Visible)
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

### Phase 1: Extend Session Model (UI Invisible)

#### 1.1. Modify `SessionRecord` in `Juju/Core/Models/SessionModels.swift`
- [ ] **1.1.1.** Add `action: String? = nil` property to `public struct SessionRecord: Identifiable, Codable`.
- [ ] **1.1.2.** Add `isMilestone: Bool = false` property to `public struct SessionRecord: Identifiable, Codable`.
- [ ] **1.1.3.** Ensure new `action` and `isMilestone` properties are `Codable`.
- [ ] **1.1.4.** Keep `milestoneText: String?` property in the struct for now.
- [ ] **1.1.5.** Update all `SessionRecord` initializers to accept `action` and `isMilestone` parameters with default values for backward compatibility.
- [ ] **1.1.6.** Update `Documentation/ARCHITECTURE.md` to reflect these new fields in the `SessionRecord` definition and related sections.

#### 1.2. Update CSV Schema and Parsing in `Juju/Core/Managers/Data/SessionDataParser.swift`
- [ ] **1.2.1.** **CSV Header (`convertSessionsToCSV`)**: Add `action` and `is_milestone` columns to the CSV header string. Example: `id,start_date,end_date,project_id,activity_type_id,project_phase_id,milestone_text,action,is_milestone,notes,mood`
- [ ] **1.2.2.** **CSV Parsing (`parseSessionsFromCSV...` methods)**: Map new `action` and `is_milestone` CSV columns to `SessionRecord` properties.
- [ ] **1.2.3.** Handle missing new columns in older CSV files by providing default values (`action = nil`, `isMilestone = false`).
- [ ] **1.2.4.** Ensure parsing logic remains robust for older files containing only `milestoneText`.
- [ ] **1.2.5.** Update `Documentation/ARCHITECTURE.md` (data persistence/CSV flow).
- [ ] **1.2.6.** Update `Documentation/DATA_FLOW.yaml` if `data_packet` definitions need adjustment.

#### 1.3. Update Export Logic in `Juju/Core/Managers/Data/SessionDataParser.swift`
- [ ] **1.3.1.** Ensure CSV exports use the updated header including `action` and `is_milestone`.
- [ ] **1.3.2.** Decide on representation for `action` and `isMilestone` in TXT/Markdown exports (e.g., include in session details).

#### 1.4. Update Session Creation Logic in `Juju/Core/Managers/SessionManager.swift`
- [ ] **1.4.1.** Modify methods creating new `SessionRecord` instances (e.g., `startSession`, `activeSession` property) to include new fields with default values (`action: nil`, `isMilestone: false`).

#### 1.5. Update Session Updating Logic in `Juju/Core/Managers/SessionManager.swift`
- [ ] **1.5.1.** Review `updateSessionField` and related methods. Prepare for future extension to handle `action` and `isMilestone` updates if needed. For now, focus on existing fields.

#### 1.6. Update Usage in Extensions and Other Managers
- [ ] **1.6.1.** **`Juju/Core/Extensions/Array+SessionExtensions.swift`**: No changes unless new session objects are constructed by these extensions.
- [ ] **1.6.2.** **`Juju/Core/Extensions/SessionRecord+Filtering.swift`**: No changes for now. Future filtering logic based on `action` or `isMilestone` can be added here.
- [ ] **1.6.3.** **`Juju/Core/Managers/ChartDataPreparer.swift`**: Ensure compatibility with updated `SessionRecord` structure. Data aggregation logic may need adjustments if it previously used `milestoneText`.
- [ ] **1.6.4.** **`Juju/Core/Managers/NarrativeEngine.swift`**: Milestone detection logic will be significantly impacted in a later step, but ensure current handling of `SessionRecord` is compatible.
- [ ] **1.6.5.** **`Juju/Core/Managers/DataValidator.swift`**: Consider if validation rules are needed for `action` or `isMilestone` (e.g., `isMilestone` can't be true if `action` is empty - this is also a UI rule).

#### 1.7. Compile and Test Phase 1
- [ ] **1.7.1.** Build the application.
- [ ] **1.7.2.** Fix any compilation errors.
- [ ] **1.7.3.** Run the app to ensure no crashes or unexpected behavior. The app should function as before, with the new fields added but not yet visible or utilized in the UI.

### Phase 2: Migration Logic (One-Off, Scriptable)

#### 2.1. Create Python Migration Script
- [ ] **2.1.1.** Write a Python script (e.g., `migrate_sessions.py`).
- [ ] **2.1.2.** **Script Logic**:
    - [ ] Iterate through session data files (e.g., `2024-data.csv`, `2025-data.csv`, `2026-data.csv`).
    - [ ] For each session:
        - [ ] If `milestoneText` is non-empty:
            - [ ] Set `action = milestoneText`
            - [ ] Set `isMilestone = true` (represent as `1` or `True` in CSV).
        - [ ] Else:
            - [ ] Set `action = ""` (empty string representation)
            - [ ] Set `isMilestone = false` (represent as `0` or `False` in CSV).
    - [ ] Do NOT delete the `milestoneText` column in the script yet. Keep it for historical safety.
    - [ ] Handle CSV reading/writing with proper quoting.
    - [ ] Include logging/progress output.
- [ ] **2.1.3.** Test the script on a *copy* of data files first. Back up original data files before running.

#### 2.2. Locate Data Files
- [ ] **2.2.1.** Confirm the exact path to Juju's session data CSV files (typically `~/Library/Application Support/Juju/sessions/` or `AppSupport/juju`).

#### 2.3. Run the Migration Script
- [ ] **2.3.1.** Execute the Python script on the identified data files.
- [ ] **2.3.2.** Monitor for errors.

#### 2.4. Verify Migration
- [ ] **2.4.1.** Manually inspect a few entries in the CSV files after migration.
- [ ] **2.4.2.** Check that sessions with old `milestoneText` now have corresponding `action` and `is_milestone` values.
- [ ] **2.4.3.** Check that sessions without `milestoneText` have appropriate defaults.

### Phase 3: UI – Introduce Action (Quietly)

#### 3.1. Identify UI Files for Session Input
- [ ] **3.1.1.** Locate SwiftUI views where session details are entered/edited (e.g., a modal, `SessionsRowView` for inline editing, or a dedicated session creation form).
- [ ] **3.1.2.** Likely candidates within `Juju/Features/Sessions/`.

#### 3.2. Add Action Text Field to the UI
- [ ] **3.2.1.** In the identified view, add a new `TextField` for "Action".
- [ ] **3.2.2.** Make it **single-line**.
- [ ] **3.2.3.** Give it a **clear label** (e.g., "Action:", "Session Action:").
- [ ] **3.2.4.** Ensure it's **required (compulsory)** input (e.g., validation to ensure it's not empty on save).
- [ ] **3.2.5.** Place it logically within the form, near "Notes".
- [ ] **3.2.6.** Do not remove the "Notes" field.

#### 3.3. Update ViewModel/State to Capture Action
- [ ] **3.3.1.** If a ViewModel is used for the session form, update it to store the "Action" value.
- [ ] **3.3.2.** Add a property (e.g., `@State private var sessionAction: String = ""` in View, or corresponding in ViewModel).
- [ ] **3.3.3.** Bind the new `TextField` to this state/ViewModel property.

#### 3.4. Update Session Saving Logic to Include Action
- [ ] **3.4.1.** Modify the function that saves a session to include the `action` value from the UI state/ViewModel.
- [ ] **3.4.2.** The `isMilestone` field should be set to its default `false` at this stage.

#### 3.5. Test UI for Action Field
- [ ] **3.5.1.** Run the app and test the new "Action" field.
- [ ] **3.5.2.** Create new sessions and ensure the "Action" is saved and displayed.
- [ ] **3.5.3.** Check that existing migrated sessions display their `action` correctly (if UI also shows existing actions - see 3.6).

#### 3.6. (Optional but Recommended) Display Existing Actions
- [ ] **3.6.1.** Update `SessionsRowView` or other session display components to show the `session.action` value for existing sessions.
- [ ] **3.6.2.** Decide on concise formatting if action text is long.

### Phase 4: UI – Milestone Toggle (Only After Action Exists)

#### 4.1. Add Milestone Toggle to the UI
- [ ] **4.1.1.** In the same session form UI as Phase 3, add a `Toggle` (checkbox) for "Milestone".
- [ ] **4.1.2.** Label it clearly (e.g., "Milestone").
- [ ] **4.1.3.** Use a `Toggle` view from SwiftUI.

#### 4.2. Link Toggle to `isMilestone` State
- [ ] **4.2.1.** Connect the `Toggle` to the `isMilestone` property of the session's state/ViewModel.
- [ ] **4.2.2.** Add `@State private var sessionIsMilestone: Bool = false` to the View (or corresponding in ViewModel).
- [ ] **4.2.3.** Bind: `Toggle("Milestone", isOn: $sessionIsMilestone)`.

#### 4.3. Implement Conditional Enablement of Milestone Toggle
- [ ] **4.3.1.** Make the "Milestone" `Toggle` enabled/disabled based on "Action" field content.
- [ ] **4.3.2.** Use `.disabled()` modifier: `Toggle("Milestone", isOn: $sessionIsMilestone).disabled(sessionAction.isEmpty)`
- [ ] **4.3.3.** This prevents marking a session as a milestone if no action is specified.

#### 4.4. Update Session Saving Logic to Include `isMilestone`
- [ ] **4.4.1.** Modify session saving logic to also save the `sessionIsMilestone` value to `SessionRecord`.

#### 4.5. Test UI for Milestone Toggle
- [ ] **4.5.1.** Verify the toggle is disabled when "Action" is empty and enabled when "Action" has text.
- [ ] **4.5.2.** Create sessions with/without the milestone flag checked.
- [ ] **4.5.3.** Verify that `isMilestone` is correctly saved and loaded.

#### 4.6. (Optional but Recommended) Display Milestone Status
- [ ] **4.6.1.** Update `SessionsRowView` or other display components to visually indicate if `session.isMilestone` is true (e.g., small icon, different text style).

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
1. **Mark phase as complete** in the master checklist
2. **Update all documentation** (ARCHITECTURE.md, DATA_FLOW.yaml)
3. **Run comprehensive tests** to ensure no regressions
4. **Create backup** before proceeding to next phase
5. **Document any issues** encountered for future reference

### Tool Usage Recommendations
- Use `replace_in_file` for targeted changes to existing files
- Use `write_to_file` for creating new files
- Use `execute_command` for building/testing the application
- Always compile and test after major changes

### Error Handling Strategy
1. **Compilation Errors**: Check all SessionRecord initializers and method signatures
2. **Runtime Errors**: Verify CSV parsing handles both old and new formats
3. **UI Issues**: Ensure all views properly bind to updated data models
4. **Data Integrity**: Validate that migration preserves all existing data

### Context Management
- Each phase should be completable within a single AI session
- If a phase is too large, break it into sub-phases (e.g., 1A, 1B, 1C)
- Use clear SEARCH/REPLACE blocks for file modifications
- Document the final state after each modification

## 🎯 Phase Transition Checklist

### Phase 1 → Phase 2 Transition
- [ ] Verify SessionRecord model updates are working
- [ ] Confirm CSV parsing handles both old and new formats
- [ ] Test that new sessions can be created and saved
- [ ] Backup all session data files
- [ ] Document current state before migration

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
