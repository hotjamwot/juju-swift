# Juju Project Roadmap

**Purpose**: Log of project status, completed features, ongoing work, and known issues. Use this to get up to speed on what's been done and what's being worked on. Updated as work progresses.

---

## Project Status

| Aspect | Status |
|--------|--------|
| **App** | Fully working and functional |
| **Data Storage** | CSV/JSON files, no Core Data or cloud |
| **Platform** | macOS (SwiftUI) |
| **Tests** | Unit tests for CSV parsing and phase data integrity |

---

## Completed Features

### Core Session Tracking
- Session start/end recording via menu bar
- Session persistence to CSV files (year-based file routing)
- Session editing (inline popovers for project, phase, activity type, mood, time, notes)
- Action and milestone fields on sessions
- Midnight-crossing session handling
- CSV format with dynamic column index mapping (supports any column order)

### Dashboard
- Overview dashboard (weekly summary + 30-day heat map)
- Yearly dashboard (project bar chart, activity type bar chart, monthly grouped view)
- Narrative engine for editorial headlines
- `ChartDataPreparer` for data aggregation

### Project Management
- Project CRUD with JSON persistence
- Phase management with archive/remove
- Phase ID integrity on remove (clears session `projectPhaseID`)
- Project statistics cache (30s TTL)

### Activity Types
- Activity type CRUD with JSON persistence
- Archive support

### Project Story
- Read-only narrative timeline for individual projects
- Phase-based chapter grouping
- Density/mood charts
- Milestone extraction
- Working but UI is ongoing

### UI/UX
- Sidebar with project/activity type management
- Sessions list with filtering (filter bar, toggle, date range)
- Inline session editing throughout
- Theming system (colors, spacing, fonts)

### Data Integrity
- Phase archiving keeps session history readable
- Phase removal clears references on affected sessions with confirmation
- Session data validation on load
- Legacy CSV migration support

### Bulk Session Editing
- Bulk selection mode entered via double-click on any session row (which also opens the filter bar in bulk edit mode)
- When bulk edit mode is active, the filter bar transforms to show bulk action controls (Project, Phase, Mood) plus Save & Exit / Cancel buttons
- Click-to-select (toggle individual selection) and shift-click range selection across day-grouped sessions
- Visual selection highlighting (accent-coloured left border bar on selected rows)
- Bulk update saves by iterating over selected sessions and calling `updateSessionFull()` for each
- Phase editing greyed out when sessions from multiple projects are selected, or when a bulk project hasn't been chosen yet
- Mood editing uses the existing 0-10 grid `MoodSelectionPopover`
- On save, the current filtered view is refreshed automatically

---

## Ongoing Work

### Project Story UI
- **Status**: Working, but UI refinements still in progress
- **Scope**: Visual polish, layout improvements, edge case handling
- **What works**: Timeline derivation, phase segments, milestone extraction, density calculation

#### Dashboard changes
1. In the Weekly Calendar view, the bubbles don't appear if a session goes past midnight. Ideally, we'd be able to see the session reflected in the view. Can we look at how this works and how we could implement this simply?
2. In the HeatMap view, let's add Weekly Total Duration labels to the right hand side of the graph, after the Sunday squares. The labels for the Dates on the left axis and the days of the week on the top axis can be larger, too.
3. For the HeatMap view, let's look at our comparison calculation to the previous week. It would be ideal if it calculated last week's hours up to the same time as today, instead of doing the total hours of the week up to the end of the same day as today. For example, if today is Wednesday at 3pm, it should compare last week’s hours up to Wednesday at 3pm, instead of the total hours of the week up to Wednesday .
4. Let's add tool tips to the weekly calendar chart view. The tooltips can be in the same style as the tooltips on the heat map view. They can say what the duration of the session was and the line of action. 
5. Let's make the buttons for each of the dashboard views on the left hand side more pressed together. I think the whole sidebar should have a slight change up so it's a little bit more clear what things are, and we could add tool tips when you hover for a second that show what they are. Right now the four buttons we have are Charts, Sessions, Projects, and Activity Types. 
6. When we finish a sessions, the Dashboard doesn't update. It should automatically update to show the new session, as well as the Sessions dashboard should update, too.

#### Sessions
1. ~~Add the ability to bulk edit sessions.~~ (Completed — see above)
2. Add the year next to the pretty date headings in the sessions list.
3. Do we get rid of the date headings and just have it as a list like a csv is shown in Sheets or Excel? Right now the demarcations between days separates the list a lot and takes up space. The Sessions tab should be a place to view and edit sessions, and that's all. It doesn't have to be anything pretty.

#### Notes Modal
1. Ensure that our Smart Defaults are working for phases. It should always default to the most recently logged phase for that project.

---

## Known Issues / To-Do Items

### Bulk Edit (May 2026)
- Add a "Bulk Edit" toggle button inside the filter bar so users can also enter bulk edit mode from the filter UI (currently only enterable via double-clicking a session row)
- Phase dropdown currently relies on a simplified `resolveBulkPhaseProject()` that needs the actual session data wired through for the mixed-projects check

---

## Deferred / Future Considerations

### Phase ID Data Integrity
- **Priority**: Handled (phase deletion clears `projectPhaseID` to nil; project deletion migrates sessions to another project)
- **What's in place**: Phase removal clears references via `SessionPhaseIntegrity.clearingPhaseReferences()`. Project deletion migrates sessions via `ProjectsViewModel.deleteProjectWithMigration()`. Both tested.
- **Remaining edge case**: Bulk-imported CSV rows can reference unknown phase IDs (`DataValidator` reports this on load)

### Testing
- **Priority**: Medium
- **Coverage**: Session CSV parsing + phase data integrity have test coverage
- **Gaps**: Manager-level tests, dashboard/ProjectStory unit tests, UI tests
- **Pattern**: See AI_DEVELOPMENT_GUIDE.md → Testing section

---

## Change Log

| Date | Change |
|------|--------|
| May 2026 | Bulk session editing implemented (double-click mode, filter bar integration, shift-click selection) |
| May 2026 | Documentation cleanup: removed DATA_FLOW.yaml (redundant with ARCHITECTURE.md), added purpose statements to all docs, created ROADMAP.md |
| May 2026 | Project Story feature implemented (working, UI ongoing) |
| Mar 2026 | Phase ID integrity implemented (archive + remove-with-clear + display rules) |
| Jan 2026 | Date-based session migration completed (startDate/endDate transition) |
| Feb 2026 | Action and milestone fields added to sessions |
| Nov 2025 | Dashboard with overview/yearly views implemented |

---

*This file is updated as significant features land, docs change, or priorities shift.*