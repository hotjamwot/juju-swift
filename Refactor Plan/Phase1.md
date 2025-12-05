# 📋 Phase 1: Data Foundations, File Organization & Input Friction Removal

**Status:** ⏳ Not Started | **Priority:** 🔴 Critical | **Estimated Duration:** 3.5-5.5 weeks

**Context:** This phase establishes two critical foundations in sequence: (1) the structured data model that replaces messy tags with meaningful project lifecycle tracking, and (2) the year-based file organization system that solves performance bottlenecks. The schema refactor comes first, then the file split.

**Updated Structure:** Based on feedback, this phase is now organized into clear sequential steps with explicit dependencies and status tracking for each task.

---

## 🎯 Phase Objectives

### Core Goals
- Update data models to support structured project lifecycle tracking
- Replace generic tags with meaningful Activity Types and Project Phases
- Redesign session logging UI for better user experience
- Ensure backward compatibility with existing data

### Success Criteria
- [ ] All new data fields are properly integrated
- [ ] Session modal supports Activity Types and Phases
- [ ] Project Cards allow phase management
- [ ] Legacy data migration works without data loss
- [ ] All existing functionality remains intact

---

## 📝 Detailed Tasks

### 1.1 Schema Refactor: Core Structs & Enums

**Status:** ⏳ Not Started | **Priority:** 🔴 Critical | **Estimated Duration:** 1-1.5 weeks

**Context:** This foundational task updates the core data models to support structured project lifecycle tracking, replacing the current tag-based system with meaningful Activity Types and Project Phases.

#### 1.1.1 CRITICAL: Update Session struct
- [ ] Make `projectID: String?` (optional) to support the Active Session state
- [ ] Add `activityTypeID: String` (required) field
- [ ] Add `projectPhaseID: String?` (optional) field  
- [ ] Add `milestoneText: String?` (optional) field
- [ ] Update all Session-related code to handle new fields
- [ ] Ensure backward compatibility with existing sessions

#### 1.1.2 Update Project struct
- [ ] Add `phases: [Phase]` array field containing Phase objects
- [ ] Define Phase struct: `{ id: String, name: String }`
- [ ] Update Project-related code to handle phases array
- [ ] Ensure existing projects have empty phases array by default

#### 1.1.3 Create and initialize ActivityType system
- [ ] Define `ActivityType` struct: `{ id: String, name: String, emoji: String }`
- [ ] Create `activityTypes.json` file with initial data:
  ```json
  [
    { "id": "writing", "name": "Writing", "emoji": "✍️" },
    { "id": "outlining", "name": "Outlining / Brainstorming", "emoji": "🧠" },
    { "id": "editing", "name": "Editing / Rewriting", "emoji": "✂️" },
    { "id": "collaborating", "name": "Collaborating", "emoji": "🤝" },
    { "id": "production", "name": "Production Prep / Organising", "emoji": "🎬" },
    { "id": "coding", "name": "Coding", "emoji": "💻" },
    { "id": "admin", "name": "Admin", "emoji": "🗂️" },
    { "id": "maintenance", "name": "Maintenance", "emoji": "🧽" }
  ]
  ```
- [ ] Create ActivityType JSON manager for CRUD operations
- [ ] Create `Core/Data/activityTypes.json` file location

### 1.2 Menu Bar & Operations Refactor (Project-First)

**Status:** ⏳ Not Started | **Priority:** 🔴 Critical | **Estimated Duration:** 1-1.5 weeks

**Context:** This task maintains the current project-first approach for starting sessions, but updates the SessionManager to store projectID from the start while keeping activityTypeID and phaseID nil until session end.

#### 1.2.1 Keep "Start Session" in Menu Bar as Project Selection
- [ ] Maintain existing logic: "Start Session" → Select Project
- [ ] Keep project selection as the primary action when starting sessions
- [ ] Ensure SessionManager.startSession stores projectID from the beginning
- [ ] Update SessionManager to handle interim state where activityTypeID and phaseID are nil

#### 1.2.2 Update SessionOperationsManager.startSession
- [ ] Accept required `projectID: String` parameter
- [ ] Store projectID immediately when session starts
- [ ] Keep activityTypeID and phaseID as nil during active session
- [ ] Track projectID from the start of active session
- [ ] Update session state management for interim state

#### 1.2.3 Update Menu Bar/Status Icon
- [ ] Keep active session icon based on Activity Type if present
- [ ] Otherwise use project colour for interim state
- [ ] Display generic icon if no activity chosen yet
- [ ] Ensure icon updates appropriately when activity is assigned at session end
- [ ] Test icon visibility and readability across different states

### 1.3 Session Log Modal Redesign (Activity & Phase Assignment)

**Status:** ⏳ Not Started | **Priority:** 🔴 Critical | **Estimated Duration:** 1-1.5 weeks

**Context:** This task redesigns the session modal to become the core of activity and phase assignment, with fields ordered to support the new workflow where project is already selected but activity and phase are assigned at session end.

#### 1.3.1 Redesign Modal: Order Fields for New Workflow
- [ ] Project (locked) - pre-filled from session start
- [ ] Activity Type dropdown - with last used default for this project
- [ ] Phase dropdown - with last used default for this project
- [ ] Milestone
- [ ] Notes
- [ ] Mood

#### 1.3.2 Implement Smart Defaults for Activity Type and Phase
- [ ] Activity Type defaults to last used on this project
- [ ] Phase defaults to last used on this project
- [ ] Ensure defaults work correctly when no previous sessions exist
- [ ] Test default behavior across different user scenarios

#### 1.3.3 Crucial Dependency: Phase Dropdown filtering
- [ ] Make Phase Dropdown dependent on selected Project
- [ ] When Project is selected, refresh Phase Dropdown with phases from selected Project's `projects.json`
- [ ] Keep smart default for Phase: last-used phase for the selected project
- [ ] Add "Add New Phase..." option within dropdown
- [ ] Ensure new phases are added to project's phases array
- [ ] Test phase filtering and reloading logic thoroughly

#### 1.3.4 Update SessionOperationsManager.endSession
- [ ] Store activityTypeID and phaseID from modal selections
- [ ] Ensure milestoneText is included in final record
- [ ] Validate data integrity before logging final record
- [ ] Handle validation errors gracefully
- [ ] Ensure all fields are validated before saving

### 1.4 Data Organization: Year-Based CSV & I/O

**Status:** ⏳ Not Started | **Priority:** 🟡 High | **Estimated Duration:** 1.5-2.5 weeks

**Context:** After establishing the new data model, we must implement the year-based file organization system to solve performance bottlenecks and enable efficient data management.

#### 1.4.1 Implement path resolution and file logic
- [ ] **Year-based file path resolution:**
  ```swift
  func getDataFileURL(for year: Int) -> URL {
      let fileName = "\(year)-data.csv"
      return jujuPath.appendingPathComponent(fileName)
  }
  ```
- [ ] **Header-once logic:** Prevents duplicate headers in append-only files
- [ ] **Available years detection:** List year files and return sorted years
- [ ] **Extend SessionFileManager:** Add year-based file paths + append-only writes

#### 1.4.2 Implement append-only write function
- [ ] **Append-only write implementation:** 80% performance improvement
- [ ] **Update SessionManager:** File selection logic + single-year caching
- [ ] **Test write path:** Basic validation

#### 1.4.3 Update SessionDataParser for new column structure
- [ ] Update parser to handle reading/writing the new, final column structure
- [ ] Ensure compatibility with new Session struct fields
- [ ] Test parsing with sample data in new format
- [ ] **Simplify SessionDataManager:** Load sessions for specific years only

### 1.5 Data Migration & Final Cleanup

**Status:** ⏳ Not Started | **Priority:** 🟡 High | **Estimated Duration:** 1-1.5 weeks

**Context:** This final task implements the one-time data migration and removes all legacy code paths, completing the transition to the new data organization system.

#### 1.5.1 Implement migrateIfNecessary() function
- [ ] **Migration function implementation:**
  ```swift
  func migrateIfNecessary() async {
      guard legacyFileExists(), !yearFilesExist() else { return }
      
      // 1. Parse entire legacy file into memory
      // 2. Group by session start_date.year (not end_date)
      // 3. For each year: write year file with header + sessions
      // 4. Sanity check: re-parse one year file
      // 5. If OK → delete legacy file, if NOT → keep legacy and abort
      
      // Edge case: sessions crossing midnight → use start_date.year only
  }
  ```
- [ ] **Data integrity validation:** Ensure no data loss during migration
- [ ] **Rollback capability:** Ability to revert if migration fails
- [ ] **Performance testing:** Validate the 80% I/O improvement

#### 1.5.2 Logic: Run migration once, splitting legacy data.csv
- [ ] Parse entire legacy file into memory
- [ ] Group by session start_date.year (not end_date)
- [ ] For each year: write year file with header + sessions
- [ ] Sanity check: re-parse one year file
- [ ] If OK → delete legacy file, if NOT → keep legacy and abort
- [ ] Edge case: sessions crossing midnight → use start_date.year only

#### 1.5.3 Update all read paths to exclusively query new YYYY-data.csv files
- [ ] Update SessionManager to use year-based file paths
- [ ] Update SessionDataManager to load sessions for specific years only
- [ ] Update all chart and dashboard components to use new file structure
- [ ] Test data loading across multiple years

#### 1.5.4 Final Legacy Check: Remove all code paths and logic related to single data.csv file
- [ ] Remove all references to legacy `data.csv` file
- [ ] Clean up old file management code
- [ ] Remove legacy data parsing logic
- [ ] Update documentation and comments
- [ ] Run comprehensive tests to ensure no broken references

### 1.6 Legacy Data Handling & Compatibility

**Status:** ⏳ Not Started | **Priority:** 🟡 High | **Estimated Duration:** 0.5-1 weeks

**Context:** This task ensures backward compatibility with existing data and provides a smooth migration path for users with legacy sessions.

#### Legacy Data Handling
- [ ] Map old tags to new activity types where possible
- [ ] Handle sessions without phases/activities gracefully
- [ ] Add "Uncategorized" fallback for old data
- [ ] Test migration with sample data
- [ ] Create migration script for existing sessions
- [ ] Ensure all existing functionality remains intact during transition

---

## 🔗 Dependencies & Integration Points

### Required Before Phase 2
- [ ] Session struct updates completed
- [ ] ActivityType system functional
- [ ] Phase management in Project Cards working
- [ ] Session modal redesigned and tested

### Integration with Existing Systems
- [ ] SessionManager must handle new fields
- [ ] Data persistence must support new structures
- [ ] UI components must display new data correctly
- [ ] Migration must preserve all existing data

---

## 🧪 Testing Strategy

### Unit Tests
- [ ] Test new Session struct with all fields
- [ ] Test Project struct with phases array
- [ ] Test ActivityType CRUD operations
- [ ] Test migration logic

### Integration Tests
- [ ] Test session creation with new fields
- [ ] Test phase management UI
- [ ] Test Activity Type selection
- [ ] Test data persistence and retrieval

### User Experience Tests
- [ ] Test session modal workflow
- [ ] Test phase management usability
- [ ] Test migration process
- [ ] Test backward compatibility

---

## ⚠️ Risk Mitigation

### Data Safety
- [ ] Create backup before migration testing
- [ ] Test migration on copy of real data
- [ ] Implement rollback capability
- [ ] Validate data integrity after migration

### Performance Considerations
- [ ] Monitor impact of new data structures
- [ ] Test with large datasets
- [ ] Optimize queries for new fields
- [ ] Ensure UI remains responsive

---

## 📊 Progress Tracking

### Week 1 Focus: Schema Refactor Foundation
- [x] 1.1.1 Update Session struct: Make projectID optional
- [x] 1.1.2 Update Session struct: Add activityTypeID, projectPhaseID, milestoneText
- [x] 1.1.3 Update Project struct: Add phases array
- [x] 1.1.4 Create and initialize activityTypes.json file

### Week 2 Focus: Menu Bar & Operations Refactor
- [ ] 1.2.1 Refactor "Start Session" in Menu Bar to prompt for Activity Type selection only
- [ ] 1.2.2 Update SessionOperationsManager.startSession to track only activityTypeID
- [ ] 1.2.3 Update Menu Bar/Status Icon to display Activity Type Emoji

### Week 3 Focus: Session Modal Redesign
- [ ] 1.3.1 Redesign Modal: Add Project Dropdown as first required field
- [ ] 1.3.2 Implement Smart Default for Project Dropdown
- [ ] 1.3.3 Implement Phase Dropdown filtering based on selected Project
- [ ] 1.3.4 Update SessionOperationsManager.endSession to require final projectID and projectPhaseID

### Week 4 Focus: Data Organization Implementation
- [ ] 1.4.1 Implement path resolution and logic for header-once files
- [ ] 1.4.2 Implement append-only write function for new sessions
- [ ] 1.4.3 Update SessionDataParser to handle new column structure

### Week 5 Focus: Data Migration & Cleanup
- [ ] 1.5.1 Implement migrateIfNecessary() function
- [ ] 1.5.2 Run migration once, splitting legacy data.csv into YYYY-data.csv
- [ ] 1.5.3 Update all read paths to exclusively query new YYYY-data.csv files
- [ ] 1.5.4 Remove all code paths related to single data.csv file

### Week 6 Focus (if needed): Legacy Compatibility & Polish
- [ ] 1.6 Legacy Data Handling & Compatibility
- [ ] Performance optimization
- [ ] Bug fixes and polish
- [ ] Documentation updates

---

## 🎯 Phase Completion Checklist

### Must Have (Critical)
- [ ] 1.1 Schema Refactor completed (Session, Project, ActivityType models)
- [ ] 1.2 Menu Bar & Operations Refactor completed
- [ ] 1.3 Session Log Modal Redesign completed
- [ ] 1.4 Data Organization implemented
- [ ] 1.5 Data Migration & Cleanup completed
- [ ] 1.6 Legacy Data Handling working
- [ ] All existing functionality preserved

### Nice to Have (Enhancements)
- [ ] Smart defaults working perfectly
- [ ] Smooth migration experience
- [ ] Comprehensive error handling
- [ ] Performance optimized

### Documentation
- [ ] Code documentation updated
- [ ] Migration guide created
- [ ] User guide for new features
- [ ] API documentation updated

---

## 🔄 Next Steps

**Upon Completion of Phase 1:**
1. Review all new data structures
2. Test migration thoroughly
3. Validate backward compatibility
4. Proceed to [Phase 2: Hero Section Intelligence](./Phase2.md)

**Key Success Factors:**
- Maintain data integrity throughout
- Ensure no disruption to existing workflows
- Create solid foundation for narrative features
- Keep users informed of changes

---

**Previous:** [Master Index](./master-index.md) | **Next:** [Phase 2: Hero Section Intelligence](./Phase2.md)
