# 💾 Phase 2: Migration Logic (One-Off, Scriptable)

This phase involves creating and running a Python script to transform existing `milestoneText` data into the new `action` and `isMilestone` fields in the CSV files. This is a critical step to ensure existing user data is correctly migrated.

## 🎯 Goals
- Create a Python script to migrate `milestoneText`.
- Safely transform existing CSV data.
- Verify the migration was successful.

## 🤖 AI Execution Guidelines

### Phase Completion Protocol
1. **Complete all checklist items** in this document
2. **Verify migration success** with manual inspection
3. **Backup all original data** before running script
4. **Mark phase complete** in master checklist
5. **Document migration results** for future reference

### Tool Usage Recommendations
- Use `write_to_file` to create the Python migration script
- Use `execute_command` to run the Python script
- Use `read_file` to verify CSV files before/after migration

### Error Handling Strategy
- **Script errors**: Test on backup data first
- **Data corruption**: Verify CSV format before and after
- **Missing data**: Check that all milestoneText values were migrated

## 📋 Detailed Checklist

### 2.1. Create Python Migration Script

#### 🎯 Objective: Create robust script to transform milestoneText → action + isMilestone

- [ ] **2.1.1.** Write a Python script (e.g., `migrate_sessions.py`).
    - **Script Location**: Place this script in a dedicated directory, perhaps `Refactor Plans/ActionMilestoneBoolean_Restructured/migration_script/` or a temporary location for execution.
    - **Libraries**: Likely needs `csv` and `os`. `pathlib` could also be useful.

- [ ] **2.1.2.** **Script Logic**:
    - **File Discovery**:
        - [ ] The script needs to find all relevant session CSV files (e.g., `2024-data.csv`, `2025-data.csv`, `2026-data.csv`).
        - [ ] It should be configurable or able to search a specific directory (e.g., `~/Library/Application Support/Juju/sessions/`).
        - [ ] Add robust error handling for file not found, permission issues, or unexpected file structures.
    - **Iteration and Transformation**:
        - [ ] For each CSV file:
            - [ ] Read the existing CSV data. It's safer to read the entire file into memory, process it, and then write it back, rather than streaming and modifying in place if the number of rows isn't excessively large.
            - [ ] **CRITICAL**: Read the *header* first to determine if `action` and `is_milestone` columns already exist.
                - [ ] If they exist, the script should ideally do nothing or offer a confirmation/skip, as it might mean the migration was already run or a partial state exists.
                - [ ] If they *don't* exist, the script needs to add them to the header.
            - [ ] For each session row (data line):
                - [ ] Read the value from the `milestone_text` column (case-insensitive handling for header name might be good).
                - [ ] If `milestoneText` is non-empty (and not just whitespace):
                    - [ ] Set the new `action` column value to `milestoneText`.
                    - [ ] Set the new `is_milestone` column value to `1` (or `True` if the CSV library handles boolean-like strings well, but `1`/`0` is more standard for CSV).
                - [ ] Else:
                    - [ ] Set the new `action` column value to an empty string `""`.
                    - [ ] Set the new `is_milestone` column value to `0`.
            - [ ] **SAFETY**: Do NOT delete the `milestoneText` column in the script yet. Keep it for historical safety and potential rollback. The script *only* adds new columns.
            - [ ] Write the modified data (including the new columns in the header) back to the CSV file. Ensure proper CSV quoting (e.g., for fields that might contain commas, quotes, or newlines).
    - **Logging/Progress Output**:
        - [ ] The script should print its progress (e.g., "Processing file: X", "Transformed Y sessions in Z").
        - [ ] It should clearly report any errors encountered (e.g., file permissions, malformed CSV rows).
        - [ ] A summary of actions taken at the end would be beneficial.

- [ ] **2.1.3.** Test the script on a *copy* of data files first.
    - [ ] Create a backup of the original session data CSV files.
    - [ ] Create a *separate* test directory and copy a few representative CSV files (including one with `milestoneText` and one without).
    - [ ] Run the script on this test data.
    - [ ] Manually inspect the output CSV files to ensure the transformation is correct.
        - [ ] `milestoneText` values are correctly moved to `action`.
        -   `is_milestone` is correctly set to `1` or `0`.
        -   Original `milestoneText` column is still there.
        -   Header is updated.
    - [ ] Fix any logic bugs in the script.

### 2.2. Locate Data Files

#### 🎯 Objective: Identify exact location of session data for migration

- [ ] **2.2.1.** Confirm the exact path to Juju's session data CSV files.
    - This is typically `~/Library/Application Support/Juju/sessions/` but can vary based on installation or user settings.
    - The script should be configurable for this path, or the path should be hardcoded if it's truly fixed and known.
    - **Documentation Note**: Jot down this confirmed path for clarity when running the script.

### 2.3. Run the Migration Script

#### 🎯 Objective: Execute migration on live data with proper safeguards

- [ ] **2.3.1.** Ensure all original data CSV files are backed up.
- [ ] **2.3.2.** Execute the Python script on the identified data files.
    - Example command: `python migrate_sessions.py --data-path /Users/haydenjweal/Library/Application\ Support/Juju/sessions/`
    - The script should handle multiple files in the directory or be pointed to specific files.
- [ ] **2.3.3.** Monitor the console output for any errors, warnings, or progress messages.
    - If errors occur, the script should ideally pause or report which file/row caused the issue.

### 2.4. Verify Migration

#### 🎯 Objective: Confirm data integrity after migration

- [ ] **2.4.1.** Manually inspect a few entries in the CSV files after migration.
    - Open a couple of the CSV files (e.g., one with a known milestone session, one without).
    - Check the `action` and `is_milestone` columns.
    - Verify that sessions with old `milestoneText` now have corresponding `action` (same text) and `is_milestone` (1) values.
    - Verify that sessions without `milestoneText` have empty string for `action` and 0 for `is_milestone`.
- [ ] **2.4.2.** Check that sessions with old `milestoneText` now have corresponding `action` and `is_milestone` values.
- [ ] **2.4.3.** Check that sessions without `milestoneText` have appropriate defaults (action: "", is_milestone: 0).
- [ ] **2.4.4.** (Optional but Recommended) Try to load the data into the Juju app (after Phase 1 changes are in place) to see if it parses without errors and displays the migrated `action` fields (once Phase 3 UI is in place).

## 📚 Key Considerations for This Phase

*   **BACKUP BACKUP BACKUP**: This is the most destructive phase if something goes wrong. Multiple backups are non-negotiable.
*   **Test Script Thoroughly**: Never run an untested migration script on live data.
*   **Script Safety**: The script should be designed to be safe (adds columns, doesn't delete crucial data initially). It should also be idempotent or check if migration is already done.
*   **User Communication**: While not part of the AI's task, the user should be informed about this migration step and its importance.
*   **Error Handling**: The script must be robust to handle various CSV edge cases (missing columns, extra columns, malformed data).

## 🚨 Error Handling and Troubleshooting

### Common Issues and Solutions

**Script Execution Errors:**
- **File not found**: Verify data path is correct
- **Permission issues**: Run script with appropriate permissions
- **Malformed CSV**: Add robust error handling for CSV parsing

**Data Migration Problems:**
- **Missing milestoneText values**: Verify script logic handles all cases
- **Incorrect mapping**: Check that action and is_milestone are set correctly
- **Data corruption**: Verify CSV format before and after migration

**Verification Issues:**
- **Manual inspection errors**: Use tools to compare before/after files
- **App loading failures**: Check CSV format compatibility
- **Missing data**: Verify all files were processed

## 📊 Testing Strategy

### Script Testing Recommendations
- Create test CSV files with various scenarios:
  - Files with milestoneText values
  - Files without milestoneText values
  - Files with malformed data
  - Files with missing columns
- Test script on backup data first
- Verify output format and data integrity

### Migration Verification
- Compare before/after CSV files
- Check that all milestoneText values were migrated
- Verify that new columns are present and correct
- Test loading migrated data in Juju app

## 🎯 Phase Transition Checklist

### Before Proceeding to Phase 3
- [ ] Verify migration script completed successfully
- [ ] Confirm migrated data loads correctly in app
- [ ] Test that both old and new sessions display properly
- [ ] Backup migrated data files
- [ ] Document migration results and any issues
- [ ] Mark Phase 2 as complete in master checklist
- [ ] Update documentation with migration details

## 💡 Sample Python Script Structure

```python
#!/usr/bin/env python3
import csv
import os
import sys
from pathlib import Path

def migrate_sessions(data_path):
    """Migrate milestoneText to action + isMilestone in CSV files"""
    # Find all CSV files in the directory
    csv_files = list(Path(data_path).glob('*-data.csv'))
    if not csv_files:
        print(f"No CSV files found in {data_path}")
        return

    print(f"Found {len(csv_files)} CSV files to process")

    for csv_file in csv_files:
        print(f"\nProcessing {csv_file.name}...")

        try:
            # Read the CSV file
            with open(csv_file, 'r', newline='', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                rows = list(reader)

                if not rows:
                    print(f"No data in {csv_file.name}, skipping")
                    continue

                # Check if migration already done
                if 'action' in reader.fieldnames and 'is_milestone' in reader.fieldnames:
                    print(f"Migration already completed for {csv_file.name}, skipping")
                    continue

                # Add new columns to header
                fieldnames = reader.fieldnames.copy()
                if 'action' not in fieldnames:
                    fieldnames.append('action')
                if 'is_milestone' not in fieldnames:
                    fieldnames.append('is_milestone')

                # Process each row
                migrated_rows = []
                for row in rows:
                    # Get milestone_text value (case-insensitive)
                    milestone_text = None
                    for key in row.keys():
                        if key.lower() == 'milestone_text':
                            milestone_text = row[key]
                            break

                    # Create new row with migrated data
                    new_row = row.copy()
                    if milestone_text and milestone_text.strip():
                        new_row['action'] = milestone_text
                        new_row['is_milestone'] = '1'
                    else:
                        new_row['action'] = ''
                        new_row['is_milestone'] = '0'

                    migrated_rows.append(new_row)

                # Write back to file
                with open(csv_file, 'w', newline='', encoding='utf-8') as f:
                    writer = csv.DictWriter(f, fieldnames=fieldnames)
                    writer.writeheader()
                    writer.writerows(migrated_rows)

                print(f"Successfully migrated {len(migrated_rows)} sessions in {csv_file.name}")

        except Exception as e:
            print(f"Error processing {csv_file.name}: {str(e)}")
            continue

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python migrate_sessions.py <data_path>")
        sys.exit(1)

    data_path = sys.argv[1]
    if not os.path.isdir(data_path):
        print(f"Error: {data_path} is not a valid directory")
        sys.exit(1)

    migrate_sessions(data_path)
    print("\nMigration complete!")
```