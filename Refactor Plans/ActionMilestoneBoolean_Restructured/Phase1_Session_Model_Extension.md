# 💾 Phase 1: Session Model Extension (UI Invisible)

This phase focuses on updating data structures, persistence, and parsing logic to include the new `action: String?` and `isMilestone: Bool` fields without altering user-facing behavior.

## 🎯 Goals
- Add `action` and `isMilestone` to `SessionRecord`.
- Update CSV handling for new fields.
- Ensure backward compatibility for existing data.
- Update managers and related components to work with new fields.

## 🤖 AI Execution Guidelines

### Phase Completion Protocol
1. **Complete all checklist items** in this document
2. **Update documentation** (ARCHITECTURE.md, DATA_FLOW.yaml)
3. **Build and test** the application
4. **Mark phase complete** in master checklist
5. **Create backup** before proceeding to Phase 2

### Tool Usage Recommendations
- Use `replace_in_file` for targeted changes to SessionModels.swift and SessionDataParser.swift
- Use `execute_command` to build and test the application
- Verify compilation after each major change

### Error Handling Strategy
- **Compilation errors**: Check all SessionRecord initializers and method signatures
- **CSV parsing errors**: Verify header format and backward compatibility
- **Manager integration**: Ensure all managers handle new fields correctly

## 📋 Detailed Checklist

### 1.1. Modify `SessionRecord` in `Juju/Core/Models/SessionModels.swift`

#### 🎯 Objective: Add new fields to SessionRecord struct while maintaining backward compatibility

- [ ] **1.1.1.** Add `action: String? = nil` property to `public struct SessionRecord: Identifiable, Codable`.
  ```swift
  // Add to SessionRecord struct
  public var action: String? = nil
  ```

- [ ] **1.1.2.** Add `isMilestone: Bool = false` property to `public struct SessionRecord: Identifiable, Codable`.
  ```swift
  // Add to SessionRecord struct
  public var isMilestone: Bool = false
  ```

- [ ] **1.1.3.** Ensure new `action` and `isMilestone` properties are `Codable`. (SwiftCodable conformance should be automatic if they are standard types).

- [ ] **1.1.4.** Keep `milestoneText: String?` property in the struct for now.

- [ ] **1.1.5.** Update all `SessionRecord` initializers to accept `action` and `isMilestone` parameters with default values for backward compatibility.
    - Primary initializer example:
      ```swift
      init(id: String = UUID().uuidString, startDate: Date, endDate: Date, projectName: String, projectID: String, activityTypeID: String? = nil, projectPhaseID: String? = nil, milestoneText: String? = nil, action: String? = nil, isMilestone: Bool = false, notes: String = "", mood: Int? = nil)
      ```
    - Ensure all other initializers (if any) also include these, possibly with defaults.

- [ ] **1.1.6.** Update `Documentation/ARCHITECTURE.md` to reflect these new fields in the `SessionRecord` definition and related sections. Update the table in "Session Model" / "SessionRecord Struct".

### 1.2. Update CSV Schema and Parsing in `Juju/Core/Managers/Data/SessionDataParser.swift`

#### 🎯 Objective: Update CSV format to include new fields while maintaining backward compatibility

- [ ] **1.2.1.** **CSV Header (`convertSessionsToCSV`)**:
    - Locate the function that generates the CSV header string.
    - Add `action` and `is_milestone` columns to the CSV header string.
    - Example new header: `id,start_date,end_date,project_id,activity_type_id,project_phase_id,milestone_text,action,is_milestone,notes,mood`
    - Ensure the order is logical.

- [ ] **1.2.2.** **CSV Parsing (`parseSessionsFromCSV...` methods)**:
    - Locate the functions that parse CSV data into `SessionRecord` objects (e.g., `parseSessionsFromCSVData...`).
    - Add logic to read the new `action` and `is_milestone` columns.
    - Map the `action` column to `SessionRecord.action`. Handle potential empty strings as `nil`.
    - Map the `is_milestone` column to `SessionRecord.isMilestone`. Handle potential string representations like "1", "0", "True", "False" and convert to `Bool`. Default to `false` if column is missing or unparsable.

- [ ] **1.2.3.** Handle missing new columns in older CSV files:
    - When parsing, if the `action` column is not present, default `SessionRecord.action` to `nil`.
    - When parsing, if the `is_milestone` column is not present, default `SessionRecord.isMilestone` to `false`.
    - Ensure this doesn't break if `milestoneText` is the only legacy field present.

- [ ] **1.2.4.** Ensure parsing logic remains robust for older files containing only `milestoneText`.
    - The parsing should continue to correctly import `milestoneText`. The new fields will just be defaulted.
    - No data loss should occur for existing `milestoneText` data.

- [ ] **1.2.5.** Update `Documentation/ARCHITECTURE.md` (data persistence/CSV flow) to reflect the new CSV columns.

- [ ] **1.2.6.** Check `Documentation/DATA_FLOW.yaml` if any `data_packet` definitions related to CSV parsing or SessionRecord creation need adjustment. It's likely the `SessionRecord` model itself is the primary change.

### 1.3. Update Export Logic in `Juju/Core/Managers/Data/SessionDataParser.swift`

#### 🎯 Objective: Ensure exports include new fields in correct format

- [ ] **1.3.1.** Locate CSV export functions (likely `convertSessionsToCSV`).
    - Ensure CSV exports use the updated header including `action` and `is_milestone`.
    - Ensure the `action` field is written correctly (e.g., as an empty string if `nil`).
    - Ensure the `is_milestone` field is written correctly (e.g., as "1" for true, "0" for false).

- [ ] **1.3.2.** Locate other export functions (e.g., for TXT or Markdown).
    - Decide on representation for `action` and `isMilestone` in these formats.
    - For example, include the `action` text in the session details. For `isMilestone`, perhaps add a label like "[Milestone]" before the action or notes if true.

### 1.4. Update Session Creation Logic in `Juju/Core/Managers/SessionManager.swift`

#### 🎯 Objective: Ensure new sessions include default values for new fields

- [ ] **1.4.1.** Identify methods in `SessionManager` that create new `SessionRecord` instances.
    - Key candidates: `startSession(projectID:activityTypeID:projectPhaseID:notes:mood:)`, `endSession(notes:mood:)`, `createSession(...)`, `activeSession` property if it creates a new record.
- [ ] **1.4.2.** Modify these methods to pass `action: nil` and `isMilestone: false` when creating new `SessionRecord` objects.
    - Example: `let newSession = SessionRecord(..., action: nil, isMilestone: false, ...)`
    - Ensure that the `activeSession` (if it's a temporary object before saving) also reflects these defaults.

### 1.5. Update Session Updating Logic in `Juju/Core/Managers/SessionManager.swift`

#### 🎯 Objective: Prepare for future updates to new fields

- [ ] **1.5.1.** Review `updateSessionField` and related methods that modify existing `SessionRecord` instances.
    - For this phase, these methods likely don't need to handle `action` or `isMilestone` yet, as the UI doesn't expose them for editing.
    - However, ensure the logic for updating other fields doesn't accidentally break or ignore the new fields if they are part of the `SessionRecord` being passed around.
    - Prepare for future extension (Phase 4) where these fields might need updating. The `updateSessionField` method might need to be generalized or new methods added.

### 1.6. Update Usage in Extensions and Other Managers

#### 🎯 Objective: Ensure all components work with updated SessionRecord structure

- [ ] **1.6.1.** **`Juju/Core/Extensions/Array+SessionExtensions.swift`**:
    - Review any methods that construct new `SessionRecord` objects. If they use initializers, ensure they now include the new parameters (likely with defaults).
    - If they manually create structs, ensure they include the new properties.

- [ ] **1.6.2.** **`Juju/Core/Extensions/SessionRecord+Filtering.swift`**:
    - No changes expected for now. This is for future filtering based on `action` or `isMilestone`.

- [ ] **1.6.3.** **`Juju/Core/Managers/ChartDataPreparer.swift`**:
    - This is a critical one. Review `ChartDataPreparer` methods that aggregate session data.
    - If any logic previously relied on `session.milestoneText` (e.g., to count milestones, or to distinguish them for charts), it needs to be updated.
    - Example: If there's a "milestone count" for a period, it should now be `sessions.filter { $0.isMilestone }.count`.
    - Ensure all `ChartDataPreparer` methods can correctly process `SessionRecord` objects with the new fields.

- [ ] **1.6.4.** **`Juju/Core/Managers/NarrativeEngine.swift`**:
    - Review `NarrativeEngine` methods, especially those that analyze sessions for milestones or key activities.
    - If `milestoneText` was used to identify significant sessions, the logic should now use `isMilestone` (and potentially `action`).
    - Ensure compatibility with the new `SessionRecord` structure.

- [ ] **1.6.5.** **`Juju/Core/Managers/DataValidator.swift`**:
    - Consider if new validation rules are needed.
    - Example: `isMilestone` should probably not be `true` if `action` is empty or `nil`. This can be a validation rule.
    - Add `action` and `isMilestone` to any relevant validation logic if necessary.

### 1.7. Compile and Test Phase 1

#### 🎯 Objective: Verify all changes work correctly before proceeding

- [ ] **1.7.1.** Build the application (e.g., `xcodebuild -project Juju.xcodeproj -scheme Juju build`).
- [ ] **1.7.2.** Fix any compilation errors. Pay attention to initializer mismatches or missing properties.
- [ ] **1.7.3.** Run the app.
    - [ ] Ensure no crashes occur.
    - [ ] Verify that existing sessions still load correctly from CSVs (old and new format if applicable).
    - [ ] Verify that new sessions can be created and saved (even if the new fields aren't visible or used in UI yet).
    - [ ] The app should function *exactly* as before from a user's perspective, but with the new fields in the data model.

## 📚 Key Considerations for This Phase

*   **Backward Compatibility**: The primary goal. Older CSVs must still parse correctly. New fields should have sensible defaults.
*   **No UI Changes**: Resist the temptation to change the UI during this phase. Focus on the backend.
*   **Test Data**: If possible, have a small set of test CSV files (one with old format, one with new format) to verify parsing and saving.
*   **Code Review**: After implementation, carefully review the changes in `SessionModels.swift`, `SessionDataParser.swift`, and `SessionManager.swift` for correctness.

## 🚨 Error Handling and Troubleshooting

### Common Issues and Solutions

**Compilation Errors:**
- **Missing initializers**: Ensure all SessionRecord initializers include new parameters
- **Method signature mismatches**: Update all manager methods to use new field names
- **CSV parsing errors**: Verify header format and column mapping

**Runtime Issues:**
- **Data loading failures**: Check CSV file permissions and format
- **Manager integration**: Ensure all managers handle new fields correctly

**Testing Recommendations:**
- Create test CSV files with both old and new formats
- Test parsing of files with missing columns
- Verify that new sessions can be created and saved
- Check that existing functionality remains unchanged

## 🎯 Phase Transition Checklist

### Before Proceeding to Phase 2
- [ ] Verify SessionRecord model updates are working
- [ ] Confirm CSV parsing handles both old and new formats
- [ ] Test that new sessions can be created and saved
- [ ] Backup all session data files
- [ ] Document current state before migration
- [ ] Mark Phase 1 as complete in master checklist
- [ ] Update ARCHITECTURE.md and DATA_FLOW.yaml with new field definitions

