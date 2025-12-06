# 🚀 Juju Refactor - Comprehensive Todo List

**Current Status:** Phase 2 Complete ✅ | **Next Phase:** Phase 2.5 (Metadata & Session Architecture Improvements)

This document provides a detailed, actionable todo list for implementing Phase 2.5 and beyond, based on the requirements in Phase2.5.md and aligned with the overall refactor plan.

---

## 📋 PHASE 2.5: Metadata & Session Architecture Improvements

### 🎯 Phase Purpose
Add immutable UUIDs to Activity Types and Phases, create Activity Types Manager View, and add Project Archiving Logic to make the system fully stable, editable, and future-proof.

---

### 1. 🚧 Add Immutable UUIDs to Activity Types and Phases

#### 1.1 Activity Types JSON Schema Update
- [x] **ActivityType model** includes `id` field ✅
- [ ] **Add `description` field** to ActivityType struct
- [ ] **Add `archived` field** to ActivityType struct
- [ ] **Update ActivityTypeManager** to handle new fields in CRUD operations
- [ ] **Update JSON encoding/decoding** to include new fields
- [ ] **Create migration logic** for existing Activity Types:
  - [ ] Generate stable IDs for legacy types (if needed)
  - [ ] Add default descriptions for existing types
  - [ ] Set `archived: false` for all existing types

#### 1.2 Project Phases Schema Update
- [x] **Phase model** includes `id` field ✅
- [ ] **Add `archived` field** to Phase struct
- [ ] **Update ProjectManager** to handle archived phases in CRUD operations
- [ ] **Update JSON encoding/decoding** to include new fields
- [ ] **Create migration logic** for existing Project Phases:
  - [ ] Set `archived: false` for all existing phases

#### 1.3 Retroactive Migration Rules
- [ ] **Create migration logic** for existing Activity Types:
  - [ ] Generate stable IDs for old types on first-run
  - [ ] Keep names stable until user edits
  - [ ] Add default descriptions for legacy types
  - [ ] Set `archived: false` for all existing types
- [ ] **Create migration logic** for existing Project Phases:
  - [ ] Generate stable IDs for existing phases
  - [ ] Maintain order and relationships
  - [ ] Set `archived: false` for all existing phases
- [ ] **Update Session model** to store `activityTypeId` and `phaseId` (already implemented ✅)
- [ ] **Update all referencing logic** to use IDs instead of names (already implemented ✅)

#### 1.4 Developer Brief Implementation
- [ ] **Add `id` fields** to Activity Types and Project Phases (partially done ✅)
- [ ] **Migrate existing entries**: generate stable IDs and rewrite JSON
- [ ] **Update Session model** to store IDs instead of names (done ✅)
- [ ] **Update all referencing logic** to use IDs (done ✅)

---

### 2. ✅ Update Sessions to Reference Metadata by ID

#### 2.1 Session Model Verification
- [ ] **Verify SessionRecord** includes:
  - [x] `activityTypeID: String?` ✅
  - [x] `projectPhaseID: String?` ✅
  - [ ] `projectID: String?` ✅
- [ ] **Verify backward compatibility** helpers are working correctly
- [ ] **Test migration** from name-based to ID-based references

#### 2.2 Session Data Integrity
- [ ] **Add validation** for ID references in sessions
- [ ] **Update SessionManager** to handle ID-based lookups
- [ ] **Ensure fallback behavior** for legacy sessions without IDs

---

### 3. 🚧 Add Activity Types Manager View

#### 3.1 Sidebar Integration
- [ ] **Add "Activity Types" item** to sidebar navigation
- [ ] **Position it after Projects** in sidebar order:
  - Dashboard
  - Sessions  
  - Projects
  - **Activity Types** ← New
- [ ] **Create ActivityTypesView** component
- [ ] **Integrate with existing navigation** system

#### 3.2 Activity Types Manager Features
- [ ] **List of all activity types** with:
  - [ ] Emoji display
  - [ ] Name display
  - [ ] Description preview
  - [ ] Archived status indicator
- [ ] **Add Activity Type** functionality:
  - [ ] Form with fields: name, emoji, description
  - [ ] Auto-generate ID
  - [ ] Set `archived: false` by default
- [ ] **Edit Activity Type** functionality:
  - [ ] Edit existing types
  - [ ] Preserve ID during edits
  - [ ] Allow name/description/emoji changes
- [ ] **Archive Activity Type** functionality:
  - [ ] Toggle archived status
  - [ ] Hide from dropdowns when archived
  - [ ] Keep in manager for reference
- [ ] **Emoji picker** integration
- [ ] **Sort order** (drag to reorder)
- [ ] **Description field** display and editing

#### 3.3 UI/UX Considerations
- [ ] **Separate sidebar item** (not nested under Projects)
- [ ] **Consistent design** with existing Projects Manager
- [ ] **Clear visual hierarchy** between active and archived types
- [ ] **Responsive layout** for different screen sizes

---

### 4. 🚧 Add Project Completion (Archiving Logic)

#### 4.1 Model Changes
- [ ] **Add `archived: Bool`** to Project model
- [ ] **Update ProjectManager** to handle archived status
- [ ] **Update JSON encoding/decoding** for archived field
- [ ] **Ensure default value** is `false` for new projects

#### 4.2 Behavior Implementation
- [ ] **Hide archived projects** from menu bar dropdown
- [ ] **Show archived projects** in Projects Manager
- [ ] **Add "Archived" section** in Projects Manager
- [ ] **Add "Archive" action** in Projects Manager
- [ ] **Maintain archived projects** in:
  - [ ] Dashboard charts
  - [ ] Annual Story View
  - [ ] Filters and reports

#### 4.3 Developer Brief Implementation
- [ ] **Add `archived` boolean** to Project model
- [ ] **Hide archived projects** in menu bar dropdown
- [ ] **Optionally grey them out** or separate in Projects Manager
- [ ] **Add "Archive" action** in Projects Manager
- [ ] **Ensure archived projects** still appear in historical views

---

## 📋 PHASE 3: Annual Project Story View (The "Killer Feature")

### 🎯 Phase Purpose
Create a visual annual timeline for each project that summarizes each week's creative "phase" using dominant activity type, tags, and milestones.

---

### 3.1 Aggregation Layer (Simple, Deterministic)

#### 3.1.1 Core Aggregation Logic
- [ ] **Create ProjectStoryAggregator** service
- [ ] **Divide year into 4 blocks per month** (≈ weekly)
- [ ] **For each block + each project**:
  - [ ] Collect all sessions in that block
  - [ ] Determine dominant activity type
  - [ ] Determine dominant tag
  - [ ] Detect highlight(s)
  - [ ] If highlight present → override text with highlightText
  - [ ] Form a `ProjectStoryCellSummary` model

#### 3.1.2 Model Implementation
- [ ] **Create ProjectStoryCellSummary** struct:
  ```swift
  struct ProjectStoryCellSummary {
      let projectID: String
      let periodIndex: Int  // 0-47
      let dominantActivity: ActivityType?
      let dominantTag: String?
      let highlight: Bool
      let highlightText: String?
      let totalDuration: TimeInterval
  }
  ```
- [ ] **Implement aggregation methods**:
  - [ ] `weeklyActivityTotals()`
  - [ ] `aggregateActivityTotals(from:)`
  - [ ] `determineDominantActivity(from:)`
  - [ ] `determineDominantTag(from:)`
  - [ ] `detectHighlights(from:)`

#### 3.1.3 Optional Polish
- [ ] **Cache results per year** for performance
- [ ] **Provide "Mixed" fallback** if ties occur
- [ ] **Handle edge cases** (empty blocks, missing data)

---

### 3.2 Grid Layout (Readable, Scrollable, Minimal)

#### 3.2.1 Structure
- [ ] **New tab: "Story"** in sidebar
- [ ] **Vertical scroll** (months → bottom)
- [ ] **Horizontal scroll** (projects → right)
- [ ] **Sticky header row** for project names
- [ ] **Sticky first column** for month labels ("Jan", "Feb", etc)

#### 3.2.2 Cell Rendering
- [ ] **Rounded rectangle** with subtle project-colour tint
- [ ] **Emoji for dominant activity**
- [ ] **Small text for dominant tag**
- [ ] **⭐ if highlight exists**
- [ ] **Tooltip on hover** with:
  - [ ] all tags in that block
  - [ ] total duration
  - [ ] highlight text

#### 3.2.3 Click Behavior
- [ ] **On click** → open SessionsView filtered to:
  - [ ] selected project
  - [ ] selected block date range

---

### 3.3 UX + Storytelling (Light, Elegant, Non-intrusive)

#### 3.3.1 Must-Have Features
- [ ] **Clean visual grid**
- [ ] **Emoji + tag text** represent the "phase"
- [ ] **Stars represent milestones**
- [ ] **Tooltips give context**
- [ ] **Clicking drills into real sessions**

#### 3.3.2 Optional Nice-to-Haves (De-prioritized)
- [ ] Subtle fade animations for highlights
- [ ] "Mixed" badge when tie
- [ ] Timeline export
- [ ] Filtering sidebar
- [ ] Year selector

---

## 📋 PHASE 4: Polish & Legacy Support

### 🎯 Phase Purpose
Refine the user experience, ensure smooth performance, and provide comprehensive legacy data support.

---

### 4.1 Performance Optimization
- [ ] **Optimize aggregation algorithms** for large datasets
- [ ] **Implement lazy loading** for Story View
- [ ] **Add caching** for frequently accessed data
- [ ] **Profile and optimize** dashboard rendering

### 4.2 Legacy Data Support
- [ ] **Comprehensive migration testing** with real user data
- [ ] **Graceful degradation** for unsupported legacy formats
- [ ] **User education** about new features and benefits
- [ ] **Backup and restore** functionality for migrations

### 4.3 User Experience Polish
- [ ] **Refine animations** and transitions
- [ ] **Improve accessibility** features
- [ ] **Enhance error handling** and user feedback
- [ ] **Add keyboard shortcuts** for common actions

---

## 📋 PHASE 5: Testing & Quality Assurance

### 🎯 Phase Purpose
Ensure all features work correctly, perform well, and provide a reliable user experience.

---

### 5.1 Unit Testing
- [ ] **Test ActivityTypeManager** CRUD operations
- [ ] **Test ProjectManager** CRUD operations
- [ ] **Test SessionManager** operations
- [ ] **Test aggregation algorithms**
- [ ] **Test migration logic**

### 5.2 Integration Testing
- [ ] **Test Activity Types Manager UI**
- [ ] **Test Project Archiving workflow**
- [ ] **Test Story View functionality**
- [ ] **Test cross-component interactions**

### 5.3 Performance Testing
- [ ] **Test with large datasets** (years of data)
- [ ] **Test memory usage** under load
- [ ] **Test responsiveness** with many projects/sessions

---

## 📋 PHASE 6: Documentation & Release

### 🎯 Phase Purpose
Prepare comprehensive documentation and release notes for users and developers.

---

### 6.1 User Documentation
- [ ] **Update user guide** for new features
- [ ] **Create migration guide** for existing users
- [ ] **Add tooltips** and inline help
- [ ] **Create video tutorials** for key workflows

### 6.2 Developer Documentation
- [ ] **Update API documentation**
- [ ] **Document migration process**
- [ ] **Add code comments** for complex algorithms
- [ ] **Create architecture diagrams**

### 6.3 Release Preparation
- [ ] **Create release notes**
- [ ] **Prepare marketing materials**
- [ ] **Test on different macOS versions**
- [ ] **Finalize version numbering**

---

## 🎯 SUCCESS CRITERIA

### Phase 2.5 Must-Have
- [ ] Activity Types have immutable UUIDs and descriptions
- [ ] Project Phases have immutable UUIDs and archived status
- [ ] Activity Types Manager View is functional and user-friendly
- [ ] Project Archiving works correctly across all views
- [ ] All existing functionality remains intact

### Phase 3 Must-Have
- [ ] Annual Project Story View displays correctly
- [ ] Grid layout is readable and scrollable
- [ ] Aggregation logic produces accurate results
- [ ] Click-through functionality works
- [ ] Tooltips provide useful context

### Overall Success Metrics
- [ ] Narrative dashboard tells compelling stories
- [ ] Users can easily track project lifecycle progress
- [ ] Activity balance is clearly visible and actionable
- [ ] Migration preserves all existing data without loss
- [ ] Performance remains acceptable with large datasets
- [ ] User feedback is positive about new narrative features

---

## 📅 ESTIMATED TIMELINE

| Phase | Duration | Start | End |
|-------|----------|-------|-----|
| **Phase 2.5** | 2-3 weeks | Week 1 | Week 3 |
| **Phase 3** | 2-3 weeks | Week 4 | Week 6 |
| **Phase 4** | 1-2 weeks | Week 7 | Week 8 |
| **Phase 5** | 1 week | Week 9 | Week 9 |
| **Phase 6** | 3-5 days | Week 10 | Week 10 |

**Total Estimated Duration:** 8-11 weeks

---

## 🔄 DEPENDENCIES & PREREQUISITES

### Phase 2.5 Dependencies
- [x] Phase 1 Complete (Data Foundations) ✅
- [x] Phase 2 Complete (Hero Section Intelligence) ✅
- [ ] Stable ActivityType and Project models ✅
- [ ] Session model with ID references ✅

### Phase 3 Dependencies
- [ ] Phase 2.5 Complete
- [ ] Aggregation services implemented
- [ ] Activity Types Manager functional

### Phase 4 Dependencies
- [ ] All previous phases complete
- [ ] Performance testing infrastructure

---

**Next Steps:** Begin with Phase 2.5 implementation, starting with Activity Types schema updates and migration logic.
