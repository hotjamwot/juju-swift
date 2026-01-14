# 💾 New Fields in Session Data Model: Implementation Roadmap

## 📋 Overview
This document provides a detailed, step-by-step implementation plan for adding `action: String?` and `isMilestone: Bool` fields to the `SessionRecord` data model, migrating existing data, updating the UI, and deprecating the `milestoneText` field.

## 🎯 Core Changes
*   **New Fields**:
    *   `action: String?` (optional)
    *   `isMilestone: Bool` (defaults to `false`)
*   **Deprecated Field**:
    *   `milestoneText: String?` (functionally replaced by `action + isMilestone`)

---

## Phase 1: Extend Session Model (UI Invisible)

This phase focuses on updating data structures, persistence, and parsing logic to include the new fields without altering user-facing behavior.

### [ ] 1.1. Modify `SessionRecord` in `Juju/Core/Models/SessionModels.swift`
- [ ] Add `action: String? = nil` and `isMilestone: Bool = false` properties to `public struct SessionRecord: Identifiable, Codable`.
- [ ] Ensure new properties are `Codable`.
- [ ] **Keep `milestoneText: String?` property in the struct for now.**
- [ ] Update all `SessionRecord` initializers to accept `action` and `isMilestone` parameters with default values for backward compatibility.
- [ ] **Documentation Update**: Update `Documentation/ARCHITECTURE.md` to reflect these new fields in the `SessionRecord` definition and related sections.

### [ ] 1.2. Update CSV Schema and Parsing in `Juju/Core/Managers/Data/SessionDataParser.swift`
- [ ] **CSV Header (`convertSessionsToCSV`)**:
    - [ ] Add `action` and `is_milestone` columns to the CSV header string.
    - [ ] Example: `id,start_date,end_date,project_id,activity_type_id,project_phase_id,milestone_text,action,is_milestone,notes,mood`
- [ ] **CSV Parsing (`parseSessionsFromCSV...` methods)**:
    - [ ] Map new `action` and `is_milestone` CSV columns to `SessionRecord` properties.
    - [ ] Handle missing new columns in older CSV files by providing default values (`action = nil`, `isMilestone = false`).
- [ ] Ensure parsing logic remains robust for older files containing only `milestoneText`.
- [ ] **Documentation Update**: Update `Documentation/ARCHITECTURE.md` (data persistence/CSV flow) and `Documentation/DATA_FLOW.yaml` (if `data_packet` definitions need adjustment).

### [ ] 1.3. Update Export Logic in `Juju/Core/Managers/Data/SessionDataParser.swift`
- [ ] Ensure CSV exports use the updated header including `action` and `is_milestone`.
- [ ] Decide on representation for `action` and `isMilestone` in TXT/Markdown exports (e.g., include in session details).

### [ ] 1.4. Update Session Creation Logic in `Juju/Core/Managers/SessionManager.swift`
- [ ] Modify methods creating new `SessionRecord` instances (e.g., `startSession`, `activeSession` property) to include new fields with default values (`action: nil`, `isMilestone: false`).

### [ ] 1.5. Update Session Updating Logic in `Juju/Core/Managers/SessionManager.swift`
- [ ] Review `updateSessionField` and related methods. Prepare for future extension to handle `action` and `isMilestone` updates if needed. For now, focus on existing fields.

### [ ] 1.6. Update Usage in Extensions and Other Managers
- [ ] **`Juju/Core/Extensions/Array+SessionExtensions.swift`**: No changes unless new session objects are constructed by these extensions.
- [ ] **`Juju/Core/Extensions/SessionRecord+Filtering.swift`**: No changes for now. Future filtering logic based on `action` or `isMilestone` can be added here.
- [ ] **`Juju/Core/Managers/ChartDataPreparer.swift`**: Ensure compatibility with updated `SessionRecord` structure. Data aggregation logic may need adjustments if it previously used `milestoneText`.
- [ ] **`Juju/Core/Managers/NarrativeEngine.swift`**: Milestone detection logic will be significantly impacted in a later step, but ensure current handling of `SessionRecord` is compatible.
- [ ] **`Juju/Core/Managers/DataValidator.swift`**: Consider if validation rules are needed for `action` or `isMilestone` (e.g., `isMilestone` can't be true if `action` is empty - this is also a UI rule).

### [ ] 1.7. Compile and Test
- [ ] Build the application.
- [ ] Fix any compilation errors.
- [ ] Run the app to ensure no crashes or unexpected behavior. The app should function as before, with the new fields added but not yet visible or utilized in the UI.

---

## Phase 2: Migration Logic (One-Off, Scriptable)

This phase involves creating and running a Python script to transform existing `milestoneText` data into the new `action` and `isMilestone` fields in the CSV files.

### [ ] 2.1. Create Python Migration Script
- [ ] Write a Python script (e.g., `migrate_sessions.py`).
- [ ] **Script Logic**:
    - [ ] Iterate through session data files (e.g., `2024-data.csv`, `2025-data.csv`, `2026-data.csv`).
    - [ ] For each session:
        - [ ] If `milestoneText` is non-empty:
            - [ ] Set `action = milestoneText`
            - [ ] Set `isMilestone = true` (represent as `1` or `True` in CSV).
        - [ ] Else:
            - [ ] Set `action = ""` (empty string representation)
            - [ ] Set `isMilestone = false` (represent as `0` or `False` in CSV).
    - [ ] **Do NOT delete the `milestoneText` column in the script yet.** Keep it for historical safety.
    - [ ] Handle CSV reading/writing with proper quoting.
    - [ ] Include logging/progress output.
- [ ] **Recommendation**: Test the script on a *copy* of data files first. Back up original data files before running.

### [ ] 2.2. Locate Data Files
- [ ] Confirm the exact path to Juju's session data CSV files (typically `~/Library/Application Support/Juju/sessions/` or `AppSupport/juju`).

### [ ] 2.3. Run the Migration Script
- [ ] Execute the Python script on the identified data files.
- [ ] Monitor for errors.

### [ ] 2.4. Verify Migration
- [ ] Manually inspect a few entries in the CSV files after migration.
- [ ] Check that sessions with old `milestoneText` now have corresponding `action` and `is_milestone` values.
- [ ] Check that sessions without `milestoneText` have appropriate defaults.

---

## Phase 3: UI – Introduce Action (Quietly)

This phase adds the "Action" text field to the session creation/editing UI.

### [ ] 3.1. Identify UI Files for Session Input
- [ ] Locate SwiftUI views where session details are entered/edited (e.g., a modal, `SessionsRowView` for inline editing, or a dedicated session creation form).
- [ ] Likely candidates within `Juju/Features/Sessions/`.

### [ ] 3.2. Add Action Text Field to the UI
- [ ] In the identified view, add a new `TextField` for "Action".
- [ ] Make it **single-line**.
- [ ] Give it a **clear label** (e.g., "Action:", "Session Action:").
- [ ] Ensure it's **required (compulsory)** input (e.g., validation to ensure it's not empty on save).
- [ ] Place it logically within the form, near "Notes".
- [ ] **Do not remove the "Notes" field.**

### [ ] 3.3. Update ViewModel/State to Capture Action
- [ ] If a ViewModel is used for the session form, update it to store the "Action" value.
- [ ] Add a property (e.g., `@State private var sessionAction: String = ""` in View, or corresponding in ViewModel).
- [ ] Bind the new `TextField` to this state/ViewModel property.

### [ ] 3.4. Update Session Saving Logic to Include Action
- [ ] Modify the function that saves a session to include the `action` value from the UI state/ViewModel.
- [ ] The `isMilestone` field should be set to its default `false` at this stage.

### [ ] 3.5. Test UI for Action Field
- [ ] Run the app and test the new "Action" field.
- [ ] Create new sessions and ensure the "Action" is saved and displayed.
- [ ] Check that existing migrated sessions display their `action` correctly (if UI also shows existing actions - see 3.6).

### [ ] 3.6. (Optional but Recommended) Display Existing Actions
- [ ] Update `SessionsRowView` or other session display components to show the `session.action` value for existing sessions.
- [ ] Decide on concise formatting if action text is long.

---

## Phase 4: UI – Milestone Toggle (Only After Action Exists)

This phase adds the "Milestone" checkbox/toggle, linked to the `isMilestone` field.

### [ ] 4.1. Add Milestone Toggle to the UI
- [ ] In the same session form UI as Phase 3, add a `Toggle` (checkbox) for "Milestone".
- [ ] Label it clearly (e.g., "Milestone").
- [ ] Use a `Toggle` view from SwiftUI.

### [ ] 4.2. Link Toggle to `isMilestone` State
- [ ] Connect the `Toggle` to the `isMilestone` property of the session's state/ViewModel.
- [ ] Add `@State private var sessionIsMilestone: Bool = false` to the View (or corresponding in ViewModel).
- [ ] Bind: `Toggle("Milestone", isOn: $sessionIsMilestone)`.

### [ ] 4.3. Implement Conditional Enablement of Milestone Toggle
- [ ] Make the "Milestone" `Toggle` enabled/disabled based on "Action" field content.
- [ ] Use `.disabled()` modifier: `Toggle("Milestone", isOn: $sessionIsMilestone).disabled(sessionAction.isEmpty)`
- [ ] This prevents marking a session as a milestone if no action is specified.

### [ ] 4.4. Update Session Saving Logic to Include `isMilestone`
- [ ] Modify session saving logic to also save the `sessionIsMilestone` value to `SessionRecord`.

### [ ] 4.5. Test UI for Milestone Toggle
- [ ] Verify the toggle is disabled when "Action" is empty and enabled when "Action" has text.
- [ ] Create sessions with/without the milestone flag checked.
- [ ] Verify that `isMilestone` is correctly saved and loaded.

### [ ] 4.6. (Optional but Recommended) Display Milestone Status
- [ ] Update `SessionsRowView` or other display components to visually indicate if `session.isMilestone` is true (e.g., small icon, different text style).

---

## Phase 5: Deprecate `milestoneText` (UI Only)

This phase focuses on hiding `milestoneText` from the UI, as its functionality is now superseded by `action` and `isMilestone`.

### [ ] 5.1. Hide `milestoneText` from Session Display UI
- [ ] Remove any UI elements that display `session.milestoneText` (e.g., from `SessionsRowView`).
- [ ] Replace/supplement with display of `session.action` and the milestone indicator.

### [ ] 5.2. Stop Writing to `milestoneText` in UI Logic
- [ ] Ensure UI logic does not attempt to update or set the `milestoneText` field of a session. This should be handled by the shift to `action` and `isMilestone`.

### [ ] 5.3. (Future Consideration) Remove `milestoneText` from Data Model and Persistence
- [ ] **This is NOT part of Phase 5 but a future cleanup step.**
- [ ] Once stable, consider removing `milestoneText` from:
    - `SessionRecord` struct.
    - CSV headers and parsing logic.
    - Any other references.
- [ ] **Documentation Update**: Plan to remove `milestoneText` from `Documentation/ARCHITECTURE.md` and `Documentation/DATA_FLOW.yaml` when the field is fully removed.

### [ ] 5.4. Final Testing
- [ ] Conduct thorough end-to-end testing.
- [ ] Create sessions with various combinations of action and milestone status.
- [ ] Edit existing sessions.
- [ ] Verify data integrity for `action` and `isMilestone`.
- [ ] Verify `milestoneText` is no longer visible/influencing UI.
- [ ] Check dashboard/chart displays for any adverse impacts.

---

## 📚 Key Principles
*   **Backward Compatibility**: Maintain where possible, especially during model changes.
*   **Data Integrity**: Ensure no data loss during migration.
*   **Incremental Changes**: Break down the task into manageable phases.
*   **UI/UX**: Keep the user interface clear, consistent, and follow existing patterns (Theme, etc.).
*   **Testing**: Test each phase thoroughly before proceeding.
*   **Documentation**: Update architecture docs (`ARCHITECTURE.md`, `DATA_FLOW.yaml`) as changes occur.
