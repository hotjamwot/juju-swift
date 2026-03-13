# Phase ID Data Integrity Issue

## Overview

This document outlines the data integrity concerns when modifying or deleting phases in the Juju app, and the implications for existing session data.

---

## Current Architecture

### How Phase Data is Stored

1. **Session Records** store a `projectPhaseID` (String) - this is a reference to a Phase entity
2. **Project Records** contain an array of `Phase` objects, each with a unique `id`
3. At **display time**, the UI resolves the phase name by looking up the phase ID in the project's phases array

### Data Flow Diagram

```
CSV Session File
       │
       ▼
SessionRecord { projectPhaseID: "phase-123" }
       │
       ▼ (at display time)
Project.phases.first { $0.id == "phase-123" }?.name
       │
       ▼ (if phase deleted)
Returns nil → displays nothing
```

---

## Operations and Their Impact

### 1. Renaming a Phase

| Aspect | Status |
|--------|--------|
| **Current Behavior** | ✅ Safe |
| **Impact on Sessions** | None - ID remains, name resolved dynamically |
| **Risk Level** | None |

**Code Reference:** Phase name is looked up at display time in `SessionsRowView.swift:771-774`

---

### 2. Deleting a Phase

| Aspect | Status |
|--------|--------|
| **Current Behavior** | ⚠️ Leaves orphaned IDs |
| **Impact on Sessions** | Sessions retain the `projectPhaseID` but it resolves to nothing |
| **Risk Level** | Medium - Data integrity issue |

**Code Reference:** `ProjectManager.deletePhase()` at `ProjectManager.swift:517-529`

```swift
// [GOTCHA] Deleting a phase does NOT affect existing sessions using that phase
// [GOTCHA] Sessions may still reference this phaseID; they will show "Unknown Phase"
project.phases.removeAll { $0.id == phaseID }
```

**What Happens:**
- The phase is removed from the project's phases array
- Existing sessions still have `projectPhaseID = "deleted-phase-id"`
- UI checks: `project.phases.first { $0.id == projectPhaseID }` → returns `nil`
- Result: Phase display is empty (not "Unknown Phase" or any warning)

---

### 3. Archiving a Phase

| Aspect | Status |
|--------|--------|
| **Current Behavior** | ⚠️ Orphaned in UI |
| **Impact on Sessions** | Sessions retain the `projectPhaseID` |
| **Risk Level** | Low - Can be unarchived to restore |

**Code Reference:** Phase is filtered out in `SessionsRowView.swift:772`

```swift
// Check if the phase exists and is not archived
guard let phase = project.phases.first(where: { $0.id == projectPhaseID && !$0.archived }) else {
    return nil
}
```

---

### 4. Deleting a Project

| Aspect | Status |
|--------|--------|
| **Current Behavior** | ⚠️ Orphaned projectIDs |
| **Impact on Sessions** | Sessions retain the `projectID` but project no longer exists |
| **Risk Level** | High - No recovery possible |

**What Happens:**
- Project is removed entirely
- Sessions still have `projectID = "deleted-project-id"`
- UI checks: `projects.first { $0.id == projectID }` → returns `nil`
- Result: Session shows no project (empty)

---

## Bulk Operations Concern

When performing bulk data changes (e.g., renaming projects, migrating large datasets):

### ✅ Safe Operations
- Renaming projects (ID-based, name resolved dynamically)
- Changing phase names (ID-based)
- Reordering phases/activities

### ⚠️ Risky Operations
- Deleting phases (orphans session references)
- Deleting projects (orphans session references)
- Bulk import that creates orphaned IDs

---

## Recommendations

### Option 1: Soft Delete with Migration (Recommended)

When deleting a phase/project:
1. Archive instead of delete (reversible)
2. If must delete, run a migration to clear orphaned IDs:

```swift
func deletePhaseWithMigration(from projectID: String, phaseID: String) {
    // 1. Find all sessions using this phase
    let affectedSessions = SessionManager.shared.allSessions.filter { 
        $0.projectID == projectID && $0.projectPhaseID == phaseID 
    }
    
    // 2. Option A: Clear the phaseID (loses history)
    // Option B: Mark with special "deleted" marker
    // Option C: Ask user what to do
    
    // 3. Update sessions
    for session in affectedSessions {
        // update session to clear projectPhaseID
    }
    
    // 4. Then delete the phase
    deletePhase(from: projectID, phaseID: phaseID)
}
```

### Option 2: Display "Unknown" Instead of Nothing

In `SessionsRowView`, show a fallback when phase is orphaned:

```swift
guard let phase = project.phases.first(where: { $0.id == projectPhaseID && !$0.archived }) else {
    return "Unknown Phase"  // Instead of returning nil
}
```

### Option 3: Data Integrity Checker

Add a periodic check that:
1. Scans all sessions for orphaned IDs
2. Reports them to the user
3. Offers cleanup options

---

## Related Code Files

| File | Purpose |
|------|---------|
| `ProjectManager.swift:517-529` | deletePhase() method |
| `SessionsRowView.swift:759-777` | Phase display resolution |
| `SessionModels.swift:10` | SessionRecord.projectPhaseID |
| `Project.swift:5-17` | Phase model definition |

---

## Open Questions for Development Team

1. Should we implement a "soft delete" pattern (archive-first, delete second)?
2. Should deleted phases/projects be stored in a "deleted references" table for display as "Unknown"?
3. Should we add a data integrity validation tool?
4. How should we handle bulk imports that might create orphaned IDs?

---

**Last Updated:** March 2026
**Status:** Awaiting developer review
