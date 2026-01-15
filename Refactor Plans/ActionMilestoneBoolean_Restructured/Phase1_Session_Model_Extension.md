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

- [x] **1.1.1.** Add `action: String? = nil` property to `public struct SessionRecord: Identifiable, Codable`.
  ```swift
  // Add to SessionRecord struct
  public var action: String? = nil
  ```

- [x] **1.1.2.** Add `isMilestone: Bool = false` property to `public struct SessionRecord: Identifiable, Codable`.
  ```swift
  // Add to SessionRecord struct
  public var isMilestone: Bool = false
  ```

- [x] **1.1.3.** Ensure new `action` and `isMilestone` properties are `Codable`. (SwiftCodable conformance should be automatic if they are standard types).

- [x] **1.1.4.** Keep `milestoneText: String?` property in the struct for now.

- [x] **1.1.5.** Update all `SessionRecord` initializers to accept `action` and `isMilestone` parameters with default values for backward compatibility.
    - Primary initializer example:
      ```swift
      init(id: String = UUID().uuidString, startDate: Date, endDate: Date, projectName: String, projectID: String, activityTypeID: String? = nil, projectPhaseID: String? = nil, milestoneText: String? = nil, action: String? = nil, isMilestone: Bool = false, notes: String = "", mood: Int? = nil)
      ```
    - Ensure all other initializers (if any) also include these, possibly with defaults.

- [x] **1.1.6.** Update `Documentation/ARCHITECTURE.md` to reflect these new fields in the `SessionRecord` definition and related sections. Update the table in "Session Model" / "SessionRecord Struct".

### 1.2. Update CSV Schema and Parsing in `Juju/Core/Managers/Data/SessionDataParser.swift`

#### 🎯 Objective: Update CSV format to include new fields while maintaining backward compatibility

- [x] **1.2.1.** **CSV Header (`convertSessionsToCSV`)**:
    - Updated header to: `id,start_date,end_date,project_id,activity_type_id,project_phase_id,action,is_milestone,milestone_text,notes,mood`
    - Action and is_milestone columns now included in CSV output

- [x] **1.2.2.** **CSV Parsing (`parseSessionsFromCSV...` methods)**:
    - Added parsing logic for `action` (mapped to `SessionRecord.action`, empty strings become `nil`)
    - Added parsing logic for `is_milestone` (mapped to `SessionRecord.isMilestone` using `parseBool` helper)
    - Implemented `parseBool` helper method to handle various boolean representations

- [x] **1.2.3.** Handle missing new columns in older CSV files:
    - Old CSV files without `action` and `is_milestone` columns: `action` defaults to `nil`, `isMilestone` defaults to `false`
    - Backward compatibility maintained for legacy CSV formats

- [x] **1.2.4.** Ensure parsing logic remains robust for older files containing only `milestoneText`.
    - Existing `milestoneText` data is preserved and continues to parse correctly
    - No data loss for existing sessions

- [x] **1.2.5.** Update `Documentation/ARCHITECTURE.md` (data persistence/CSV flow) to reflect the new CSV columns.

- [x] **1.2.6.** Check `Documentation/DATA_FLOW.yaml` if any `data_packet` definitions need adjustment.
    - DATA_FLOW.yaml already references SessionRecord; ARCHITECTURE.md is source of truth for data types

### 1.3. Update Export Logic in `Juju/Core/Managers/Data/SessionDataParser.swift`

#### 🎯 Objective: Ensure exports include new fields in correct format

- [x] **1.3.1.** Locate CSV export functions (likely `convertSessionsToCSV`).
    - CSV exports now include updated header with `action` and `is_milestone`
    - `action` written as empty string if `nil`
    - `is_milestone` written as "1" for true, "0" for false

- [ ] **1.3.2.** Locate other export functions (e.g., for TXT or Markdown).
    - Decide on representation for `action` and `isMilestone` in these formats.
    - For example, include the `action` text in the session details. For `isMilestone`, perhaps add a label like "[Milestone]" before the action or notes if true.

### 1.4. Update Session Creation Logic in `Juju/Core/Managers/SessionManager.swift`

#### 🎯 Objective: Ensure new sessions include default values for new fields

- [x] **1.4.1.** Identify methods in `SessionManager` that create new `SessionRecord` instances.
    - Key candidates: `startSession(projectID:activityTypeID:projectPhaseID:notes:mood:)`, `endSession(notes:mood:)`, `createSession(...)`, `activeSession` property if it creates a new record.
- [x] **1.4.2.** Modified these methods to pass `action: nil` and `isMilestone: false` when creating new `SessionRecord` objects.
    - Updated `activeSession` property
    - All new SessionRecord creations include new fields with defaults

### 1.5. Update Session Updating Logic in `Juju/Core/Managers/SessionManager.swift`

#### 🎯 Objective: Prepare for future updates to new fields

- [x] **1.5.1.** Review `updateSessionField` and related methods that modify existing `SessionRecord` instances.
    - Updated `updateSession` method to preserve `action` and `isMilestone` when updating other fields
    - Updated `editSession` method to preserve new fields during edits

### 1.6. Update Usage in Extensions and Other Managers

#### 🎯 Objective: Ensure all components work with updated SessionRecord structure

- [x] **1.6.1.** **`Juju/Core/Extensions/Array+SessionExtensions.swift`**:
    - Reviewed; no changes needed. Extensions don't construct SessionRecord objects.

- [x] **1.6.2.** **`Juju/Core/Extensions/SessionRecord+Filtering.swift`**:
    - No changes needed at this phase. Ready for filtering based on `action` or `isMilestone` in future phases.

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

- [x] **1.7.1.** Build the application (e.g., `xcodebuild -project Juju.xcodeproj -scheme Juju build`).
    - Build completed successfully

- [x] **1.7.2.** Fix any compilation errors. Pay attention to initializer mismatches or missing properties.
    - All compilation errors resolved
    - All SessionRecord initializers updated
    - All manager methods handle new fields

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

