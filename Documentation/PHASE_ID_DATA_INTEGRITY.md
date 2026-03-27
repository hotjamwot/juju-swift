# Phase ID Data Integrity

## Overview

Sessions store a `projectPhaseID` that references a `Phase.id` on the owning project. This document describes how Juju keeps that reference consistent, how **archive** differs from **remove**, and what remains to watch for (e.g. project deletion).

---

## Architecture

1. **Session records** (CSV) store `projectPhaseID` (optional string).
2. **Projects** (`projects.json`) store phases with stable `id`, `name`, `order`, and `archived`.
3. **Display**: Session rows resolve the phase label from `Project.phases` by id (including **archived** phases so history stays readable).
4. **Assignment**: Phase pickers and similar UI only list **non-archived** phases for new choices.

---

## Behaviors (Implemented)

### Renaming a phase

| Aspect | Status |
|--------|--------|
| **Behavior** | Safe |
| **Sessions** | Unchanged; name is resolved from the project at display time |

### Archiving a phase (“Retired” in project editor)

| Aspect | Status |
|--------|--------|
| **Behavior** | Phase is hidden from phase **pickers**; past sessions **still show** the phase name (slightly muted in the sessions table) |
| **Sessions** | Still store the same `projectPhaseID` |
| **Recovery** | Unarchive in **Projects → edit project → phases** |

**UI**: Toggle **Retired** per phase in `ProjectSidebarEditView`.

### Removing a phase from a project

| Aspect | Status |
|--------|--------|
| **Behavior** | If any sessions use that phase, a confirmation explains that **saving** will clear their phase tag (`projectPhaseID` → empty / nil for those sessions). Removing a phase with zero sessions does not prompt. |
| **On Save** | `SessionManager.clearProjectPhaseForSessions(projectID:phaseIDs:)` clears all matching session rows, then `projects.json` is written without those phase definitions |

**Code**: `ProjectSidebarEditView.saveProject()`, `SessionManager.clearProjectPhaseForSessions`, `ProjectManager.deletePhase()` (also clears sessions if that API is used).

### `ProjectManager.deletePhase`

Removes the phase from the project **after** clearing `projectPhaseID` on affected sessions for that project.

### Validation

`DataValidator` treats a session’s `projectPhaseID` as valid if the phase **exists on the project**, whether archived or not—so archived phases do not invalidate existing session rows.

---

## Behaviors (Still Sharp Edges)

### Deleting a project

Sessions can still reference a `projectID` that no longer exists if a project is removed without migrating sessions. Existing flows may migrate or warn; treat full project delete as high-impact.

### Bulk import

Imported CSV rows can reference unknown phase IDs; a future integrity checker could report and repair these.

---

## Related Code

| Area | Location |
|------|----------|
| Clear phase IDs on many sessions | `SessionManager.clearProjectPhaseForSessions` |
| Delete phase + clear sessions | `ProjectManager.deletePhase` |
| Edit phases, retire toggle, remove confirm | `ProjectSidebarEditView` |
| Session row phase label (includes archived) | `SessionsRowView.getProjectPhaseDisplayInfo()` |
| Phase picker (active only) | `InlineSelectionPopover` / phase selection popovers |
| Session validation (phase exists on project) | `DataValidator.validateSession` |
| Bulk refresh after phase clear | `SessionsView.handleSessionUpdateNotification` (`sessionID == "bulkPhaseClear"`) |

---

## Historical Note

Earlier builds could orphan `projectPhaseID` when a phase was removed from the editor, and archived phases did not resolve in the sessions table. Both are addressed as of March 2026.

## Tests

- `JujuTests/PhaseDataIntegrityTests.swift` — `SessionPhaseIntegrity.clearingPhaseReferences` (no disk I/O) and `DataValidator.validateSession(_:projectList:)` with archived vs missing phases.
- Run: `xcodebuild -scheme Juju -destination 'platform=macOS' test -only-testing:JujuTests/PhaseDataIntegrityTests`

---

**Last Updated:** March 2026  
**Status:** Implemented (archive + remove-with-clear + display rules)
