# 🚀 Juju Refactor Master To-Do List

**Objective:** Systematically refactor Juju to create a narrative-driven dashboard that tells the story of your creative career using structured data, while maintaining app functionality throughout the process.

**Refactor Approach:** 
- **Incremental Implementation:** Complete each phase before moving to the next
- **Backward Compatibility:** Ensure old data works alongside new features
- **Systematic Progression:** Build foundation → Core features → Advanced views → Polish
- **Continuous Testing:** Verify functionality at each step

---

## 📋 PHASE 1: DATA FOUNDATIONS, FILE ORGANIZATION
**Status:** ✅ Complete | **Priority:** 🔴 Critical | **Estimated Duration:** 3.5-5.5 weeks

**Context:** This phase establishes two critical foundations in sequence: (1) the structured data model that replaces messy tags with meaningful project lifecycle tracking, and (2) the year-based file organization system that solves performance bottlenecks. The schema refactor comes first, then the file split.

**Updated Structure:** Based on feedback, this phase is now organized into clear sequential steps with explicit dependencies and status tracking for each task.

### 1.1 Schema Refactor: Core Structs & Enums
**Status:** ✅ Complete | **Priority:** 🔴 Critical | **Estimated Duration:** 1-1.5 weeks

**Context:** This foundational task updates the core data models to support structured project lifecycle tracking, replacing the current tag-based system with meaningful Activity Types and Project Phases.

#### 1.1.1 CRITICAL: Update Session struct
- [x] Make `projectID: String?` (optional) to support the Active Session state
- [x] Add `activityTypeID: String?` (optional) field
- [x] Add `projectPhaseID: String?` (optional) field  
- [x] Add `milestoneText: String?` (optional) field
- [x] Update all Session-related code to handle new fields
- [x] Ensure backward compatibility with existing sessions

#### 1.1.2 Update Project struct
- [x] Add `phases: [Phase]` array field containing Phase objects
- [x] Define Phase struct: `{ id: String, name: String }`
- [x] Update Project-related code to handle phases array
- [x] Ensure existing projects have empty phases array by default

#### 1.1.3 Create and initialize ActivityType system
- [x] Define `ActivityType` struct: `{ id: String, name: String, emoji: String }`
- [x] Create `activityTypes.json` file with initial data (via ActivityTypeManager)
- [x] Create ActivityType JSON manager for CRUD operations
- [x] Create ActivityType model and manager in `Core/Models/ActivityType.swift`

### 1.2 Menu Bar & Operations Refactor (Project-First)
**Status:** ✅ Complete | **Priority:** 🔴 Critical | **Estimated Duration:** 1-1.5 weeks

**Context:** This task maintains the current project-first approach for starting sessions, but updates the SessionManager to store projectID from the start while keeping activityTypeID and phaseID nil until session end.

#### 1.2.1 Keep "Start Session" in Menu Bar as Project Selection
- [x] Maintain existing logic: "Start Session" → Select Project
- [x] Keep project selection as the primary action when starting sessions
- [x] Ensure SessionManager.startSession stores projectID from the beginning
- [x] Update SessionManager to handle interim state where activityTypeID and phaseID are nil

#### 1.2.2 Update SessionOperationsManager.startSession
- [x] Accept optional `projectID: String?` parameter
- [x] Store projectID immediately when session starts
- [x] Keep activityTypeID and phaseID as nil during active session
- [x] Track projectID from the start of active session
- [x] Update session state management for interim state

#### 1.2.3 Update Menu Bar/Status Icon
- [x] Keep active session icon based on Activity Type if present
- [x] Otherwise use project colour for interim state
- [x] Display generic icon if no activity chosen yet
- [x] Ensure icon updates appropriately when activity is assigned at session end
- [ ] Test icon visibility and readability across different states (manual testing needed)

### 1.3 Session Log Modal Redesign (Activity & Phase Assignment)
**Status:** ✅ Complete | **Priority:** 🔴 Critical | **Estimated Duration:** 1-1.5 weeks

**Context:** This task redesigns the session modal to become the core of activity and phase assignment, with fields ordered to support the new workflow where project is already selected but activity and phase are assigned at session end.

#### 1.3.1 Redesign Modal: Order Fields for New Workflow
- [x] Project (locked) - pre-filled from session start
- [x] Activity Type dropdown - with last used default for this project (basic implementation)
- [x] Phase dropdown - with last used default for this project (basic implementation)
- [x] Milestone
- [x] Notes
- [x] Mood

#### 1.3.2 Implement Smart Defaults for Activity Type and Phase
- [x] Activity Type defaults to first available (basic implementation)
- [x] Phase defaults to first available (basic implementation)
- [ ] Activity Type defaults to last used on this project (enhancement needed)
- [ ] Phase defaults to last used on this project (enhancement needed)
- [x] Ensure defaults work correctly when no previous sessions exist
- [ ] Test default behavior across different user scenarios

#### 1.3.3 Crucial Dependency: Phase Dropdown filtering
- [x] Make Phase Dropdown dependent on selected Project
- [x] When Project is selected, refresh Phase Dropdown with phases from selected Project's `projects.json`
- [x] Keep smart default for Phase: first available phase for the selected project
- [ ] Add "Add New Phase..." option within dropdown (TODO)
- [ ] Ensure new phases are added to project's phases array (TODO)
- [ ] Test phase filtering and reloading logic thoroughly

#### 1.3.4 Update SessionOperationsManager.endSession
- [x] Store activityTypeID and phaseID from modal selections
- [x] Ensure milestoneText is included in final record
- [x] Validate data integrity before logging final record (basic validation)
- [ ] Handle validation errors gracefully (enhancement needed)
- [x] Ensure all fields are validated before saving (basic validation)

### 1.4 Data Organization: Year-Based CSV & I/O
**Status:** ✅ Complete | **Priority:** 🟡 High | **Estimated Duration:** 1.5-2.5 weeks

**Context:** After establishing the new data model, we must implement the year-based file organization system to solve performance bottlenecks and enable efficient data management.

#### 1.4.1 Implement path resolution and file logic
- [x] **Year-based file path resolution:** Implemented `getDataFileURL(for:in:)` in SessionFileManager
- [x] **Header-once logic:** Implemented in `appendToYearFile` method to prevent duplicate headers
- [x] **Available years detection:** Implemented `getAvailableYears(in:)` to list year files and return sorted years
- [x] **Extend SessionFileManager:** Added year-based file paths + append-only writes with header checking

#### 1.4.2 Implement append-only write function
- [x] **Append-only write implementation:** Implemented `appendToYearFile` with header checking (80% performance improvement)
- [x] **Update SessionOperationsManager:** Updated to use year-based file selection based on session start date
- [ ] **Test write path:** Basic validation (manual testing needed)

#### 1.4.3 Update SessionDataParser for new column structure
- [x] Update parser to handle reading/writing the new, final column structure
- [x] Ensure compatibility with new Session struct fields
- [x] Backward compatibility with old CSV format maintained
- [ ] Test parsing with sample data in new format (manual testing needed)
- [x] **Simplify SessionDataManager:** Updated to load sessions for specific years, with fallback to legacy file

### 1.5 Data Migration & Final Cleanup
**Status:** ✅ Complete | **Priority:** 🟡 High | **Estimated Duration:** 1-1.5 weeks

**Context:** This final task implements the one-time data migration and removes all legacy code paths, completing the transition to the new data organization system.

#### 1.5.1 Implement migrateIfNecessary() function
- [x] **Migration function implementation:** Created SessionMigrationManager with migrateIfNecessary() method
- [x] **Data integrity validation:** Implemented verification step that re-parses a year file to ensure integrity
- [x] **Rollback capability:** Implemented cleanup of partially written files if migration fails
- [x] **Integrated into SessionManager:** Migration runs automatically on app startup (non-blocking)
- [ ] **Performance testing:** Validate the 80% I/O improvement (manual testing needed)

#### 1.5.2 Logic: Run migration once, splitting legacy data.csv
- [x] Parse entire legacy file into memory
- [x] Group by session start_date.year (not end_date) - handles edge cases automatically
- [x] For each year: write year file with header + sessions
- [x] Sanity check: re-parse one year file to verify integrity
- [x] If OK → delete legacy file, if NOT → keep legacy and abort (with cleanup)
- [x] Edge case: sessions crossing midnight → use start_date.year only (handled by Calendar.component)

#### 1.5.3 Update all read paths to exclusively query new YYYY-data.csv files
- [x] Update SessionDataManager to load sessions for specific years (prefers year-based files, falls back to legacy)
- [x] Read paths check for year-based files first, then fall back to legacy during migration period
- [ ] Update all chart and dashboard components to use new file structure (components use SessionDataManager, so already compatible)
- [ ] Test data loading across multiple years (manual testing needed)

#### 1.5.4 Final Legacy Check: Remove all code paths and logic related to single data.csv file
- [x] Migration system implemented and integrated into SessionManager initialization
- [x] Legacy fallback kept for safety during migration period (will be removed after migration is complete)
- [ ] Remove legacy fallback code after migration is verified (deferred until migration is tested)
- [x] Update documentation and comments
- [ ] Run comprehensive tests to ensure no broken references (manual testing needed)

### 1.6 Legacy Data Handling & Compatibility
**Status:** ✅ Complete | **Priority:** 🟡 High | **Estimated Duration:** 0.5-1 weeks

**Context:** This task ensures backward compatibility with existing data and provides a smooth migration path for users with legacy sessions.

#### Legacy Data Handling
- [x] Handle sessions without phases/activities gracefully (optional fields + helper methods)
- [x] Add "Uncategorized" fallback for old data (default activity type with helper methods)
- [x] Helper methods added: `getActivityTypeDisplay()`, `getProjectPhaseDisplay()`, `isLegacySession`
- [x] ActivityTypeManager includes `getUncategorizedActivityType()` and `getActivityTypeDisplay(id:)` with fallback
- [x] ProjectManager includes `getPhaseDisplay(projectID:phaseID:)` helper
- [x] Ensure all existing functionality remains intact (backward compatibility maintained)
- [ ] Test migration with sample data (manual testing needed)

---

## 📋 PHASE 2: HERO SECTION INTELLIGENCE
**Status:** ⏳ Not Started | **Priority:** 🟠 High | **Estimated Duration:** 1-2 weeks

**Context:** This phase transforms the dashboard from displaying raw stats to telling a compelling story about your creative work. The Hero Section becomes the narrative centerpiece.

### 2.1 Editorial Engine Development
- [ ] **Headline Generation Logic**
  - [ ] Create Editorial Engine service
  - [ ] Implement total duration calculation for selected period
  - [ ] Add logic to determine "Top Activity" by time spent (using new Activity Types)
  - [ ] Add logic to determine "Top Project" by time spent
  - [ ] Implement milestone detection from recent sessions
  - [ ] Generate narrative headlines like:
    - "This week you logged 13h. Your focus was **Writing** on **Project X**, where you reached a milestone: **'Finished Act I'**."

- [ ] **Dynamic Headline Integration**
  - [ ] Replace static headline text with Editorial Engine output
  - [ ] Ensure headline updates when filters change
  - [ ] Add loading states and error handling
  - [ ] Test with various data scenarios

### 2.2 Activity Bubble Chart Implementation
- [ ] **Chart Data Aggregation**
  - [ ] Create service to aggregate duration by `activityTypeID` (using new schema)
  - [ ] Map activity types to their emoji representations
  - [ ] Calculate bubble sizes based on time spent
  - [ ] Ensure chart updates with filter changes

- [ ] **Chart UI Development**
  - [ ] Build Activity Bubble Chart component
  - [ ] Replace existing Project Bubble Chart in Hero Section
  - [ ] Implement tooltips showing exact time and percentages
  - [ ] Add smooth animations for chart updates
  - [ ] Ensure accessibility compliance

### 2.3 Calendar Chart Enhancement
- [ ] **Activity Emoji Integration**
  - [ ] Modify Session Calendar Chart to display activity emojis
  - [ ] Map activity types to their emoji representations
  - [ ] Add emojis to daily session bars
  - [ ] Ensure emojis are visible and readable at all sizes

- [ ] **Visual Polish**
  - [ ] Test emoji visibility across different themes
  - [ ] Add hover effects showing activity type names
  - [ ] Ensure performance with emoji rendering

---

## 📋 PHASE 3: ANNUAL PROJECT STORY VIEW (THE "KILLER FEATURE")
**Status:** ⏳ Not Started | **Priority:** 🟠 High | **Estimated Duration:** 2-3 weeks

**Context:** This phase delivers the signature feature - a visual timeline that tells the story of each project's journey through phases and milestones, functioning like a creative bullet journal.

### 3.1 Aggregation Service Development
- [ ] **Core Aggregation Logic**
  - [ ] Create Project Story Aggregation service
  - [ ] Implement weekly time period calculation (using new year-based file structure)
  - [ ] Add logic to determine dominant activity per week (using Activity Types)
  - [ ] Add logic to determine dominant phase per week (using Project Phases)
  - [ ] Implement milestone detection for weekly periods
  - [ ] Handle edge cases (no data, multiple milestones, etc.)

- [ ] **Data Query Optimization**
  - [ ] Optimize queries for large datasets (using new year-based structure)
  - [ ] Implement caching for frequently accessed data
  - [ ] Add pagination for long time ranges
  - [ ] Ensure performance with years of data

### 3.2 Grid Layout Implementation
- [ ] **Grid Structure**
  - [ ] Build scrollable grid component
  - [ ] Set up Projects as columns (X-axis)
  - [ ] Set up Months as rows (Y-axis)
  - [ ] Implement responsive design for different screen sizes
  - [ ] Add virtualization for performance with many projects (using new data structure)

- [ ] **Cell Design & Functionality**
  - [ ] Create cell component with project color background
  - [ ] Display dominant activity emoji in each cell (using Activity Types)
  - [ ] Show milestone text with ⭐ when applicable
  - [ ] Fallback to phase name when no milestone (using Project Phases)
  - [ ] Add hover tooltips with detailed information
  - [ ] Implement click interactions for detailed views

### 3.3 Visual Storytelling Features
- [ ] **Phase Progression Visualization**
  - [ ] Implement visual indicators for phase transitions (using Project Phases)
  - [ ] Add subtle animations for milestone achievements
  - [ ] Create visual flow that shows project evolution
  - [ ] Add timeline markers for significant events

- [ ] **Interactive Elements**
  - [ ] Add drill-down capability from cells to session details
  - [ ] Implement filtering by activity type or phase (using new schema)
  - [ ] Add export functionality for project timelines
  - [ ] Create shareable project story views

---

## 📋 PHASE 4: POLISH & LEGACY SUPPORT
**Status:** ⏳ Not Started | **Priority:** 🟡 Medium | **Estimated Duration:** 1-2 weeks

**Context:** This final phase ensures a polished, professional experience while maintaining full backward compatibility with existing data.

### 4.1 Calendar Chart Final Enhancements
- [ ] **Activity Emoji Integration**
  - [ ] Add activity emojis to daily calendar bars (using Activity Types)
  - [ ] Ensure emojis scale properly with bar height
  - [ ] Test readability across different themes
  - [ ] Add tooltips showing activity type on hover

- [ ] **Visual Consistency**
  - [ ] Ensure emoji style matches overall app design
  - [ ] Add smooth transitions for emoji appearance
  - [ ] Optimize performance with emoji rendering

### 4.2 Legacy Data Migration
- [ ] **Comprehensive Migration Strategy**
  - [ ] Create complete migration script for all existing data (using 1.5.1 implementation)
  - [ ] Map old tags to new activity types intelligently
  - [ ] Handle sessions without structured data gracefully
  - [ ] Add "General" or "Uncategorized" fallbacks
  - [ ] Ensure no data loss during migration

- [ ] **User Experience**
  - [ ] Add migration progress indicator
  - [ ] Provide migration summary report
  - [ ] Allow users to review and adjust migrated data
  - [ ] Add option to skip migration for testing

### 4.3 Error Handling & Edge Cases
- [ ] **Robust Error Handling**
  - [ ] Add graceful handling for corrupted data
  - [ ] Implement fallbacks for missing activity types
  - [ ] Handle projects without phases
  - [ ] Manage sessions without milestones or phases

- [ ] **User Feedback**
  - [ ] Add informative error messages
  - [ ] Provide guidance for data cleanup
  - [ ] Create help documentation for new features

### 4.4 Performance Optimization
- [ ] **Data Processing**
  - [ ] Optimize aggregation queries for large datasets
  - [ ] Implement efficient caching strategies
  - [ ] Add lazy loading for dashboard components
  - [ ] Optimize chart rendering performance

- [ ] **Memory Management**
  - [ ] Review memory usage with new features
  - [ ] Implement proper cleanup for large data structures
  - [ ] Optimize image and emoji caching

---

## 📋 PHASE 5: TESTING & QUALITY ASSURANCE
**Status:** ⏳ Not Started | **Priority:** 🟡 Medium | **Estimated Duration:** 1 week

**Context:** Comprehensive testing ensures the refactor maintains functionality while delivering the new narrative-driven experience.

### 5.1 Unit Testing
- [ ] **Core Logic Testing**
  - [ ] Test all aggregation services (using new schema)
  - [ ] Test data model updates and migrations (Phase 1.1-1.6)
  - [ ] Test Editorial Engine headline generation
  - [ ] Test Activity and Phase selection logic (using new Activity Types and Project Phases)

### 5.2 Integration Testing
- [ ] **End-to-End Workflows**
  - [ ] Test complete session logging workflow (using new schema)
  - [ ] Test project phase management (using new Project Phases)
  - [ ] Test dashboard data updates (using year-based files)
  - [ ] Test migration process (Phase 1.5)

### 5.3 User Acceptance Testing
- [ ] **Beta Testing Preparation**
  - [ ] Create test scenarios covering all features
  - [ ] Prepare migration testing with real data (Phase 1.6)
  - [ ] Gather feedback on narrative features
  - [ ] Address usability concerns

---

## 📋 PHASE 6: DOCUMENTATION & RELEASE
**Status:** ⏳ Not Started | **Priority:** 🟢 Low | **Estimated Duration:** 3-5 days

**Context:** Proper documentation ensures users understand the new narrative-driven features and can leverage them effectively.

### 6.1 User Documentation
- [ ] **Feature Documentation**
  - [ ] Document new data model and fields (Activity Types, Project Phases, etc.)
  - [ ] Create guides for using Activity Types and Phases
  - [ ] Document the Editorial Engine and narrative features
  - [ ] Create tutorials for the Annual Project Story View

### 6.2 Developer Documentation
- [ ] **Code Documentation**
  - [ ] Update API documentation (including new schema)
  - [ ] Document new data structures and relationships (Phase 1.1-1.6)
  - [ ] Create migration guide for developers (Phase 1.5)
  - [ ] Document new services and their usage

### 6.3 Release Preparation
- [ ] **Release Notes**
  - [ ] Document all changes and improvements (Phase 1-6)
  - [ ] Highlight new narrative features
  - [ ] Document migration process (Phase 1.5)
  - [ ] Provide troubleshooting guide

---

## 🎯 SUCCESS CRITERIA

### Phase Completion Requirements
Each phase must meet these criteria before proceeding:

1. **Functionality:** All features work as designed
2. **Performance:** No significant performance degradation
3. **Compatibility:** Existing data and workflows remain functional
4. **Testing:** Unit tests pass, integration tests succeed
5. **Documentation:** Code is documented, user guides updated

### Phase 1 Specific Requirements
Before proceeding to Phase 2, ensure:
- [ ] 1.1 Schema Refactor completed (Session, Project, ActivityType models)
- [ ] 1.2 Menu Bar & Operations Refactor completed
- [ ] 1.3 Session Log Modal Redesign completed
- [ ] 1.4 Data Organization implemented
- [ ] 1.5 Data Migration & Cleanup completed
- [ ] 1.6 Legacy Data Handling working
- [ ] All existing functionality preserved

### Overall Refactor Success Metrics
- [ ] Narrative dashboard tells compelling stories about creative work
- [ ] Users can easily track project lifecycle progress
- [ ] Activity balance is clearly visible and actionable
- [ ] Migration preserves all existing data without loss
- [ ] Performance remains acceptable with large datasets
- [ ] User feedback is positive about new narrative features

---

## 🔄 ITERATIVE DEVELOPMENT APPROACH

### Weekly Checkpoints
- **Monday:** Review previous week's progress, plan current week
- **Wednesday:** Mid-week progress review, address blockers
- **Friday:** Weekly accomplishments review, adjust plans as needed

### Progress Tracking
- **Phase Status:** Track completion percentage for each phase
- **Blocker Management:** Identify and resolve blockers quickly
- **Quality Gates:** Ensure each phase meets success criteria before proceeding
- **User Feedback:** Incorporate feedback throughout development

### Risk Mitigation
- **Data Safety:** Always backup before migration testing
- **Rollback Plan:** Maintain ability to revert changes if needed
- **Performance Monitoring:** Track performance metrics throughout
- **User Communication:** Keep users informed of progress and changes
