# Juju Project Roadmap

**Purpose**: Log of project status, completed features, ongoing work, and known issues. Use this to get up to speed on what's been done and what's being worked on. Updated as work progresses.

---

## Project Status

| Aspect | Status |
| -------- | -------- |
| **App** | Fully working and functional |
| **Data Storage** | CSV/JSON files, no Core Data or cloud |
| **Platform** | macOS (SwiftUI) |
| **Tests** | Unit tests for CSV parsing, phase data integrity, and ProjectStory derivation (phase lanes) |

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

- Overview dashboard (weekly calendar chart, 90-day timeline chart, yearly distribution charts)
- Yearly dashboard (project bar chart, activity type bar chart, monthly grouped view)
- Narrative engine for editorial headlines with comparative analytics
- `ChartDataPreparer` for data aggregation
- 90-day timeline chart showing when sessions happened (time-of-day slivers) with day-column hover → `DaySessionInfoPanel`
- Narrative metric cards (THIS WEEK / FOCUS / PROJECT) with JapaScandi styling

### Project Management

- Project CRUD with JSON persistence
- Phase management with archive/remove
- Phase ID integrity on remove (clears session `projectPhaseID`)
- Project statistics cache (30s TTL)

### Activity Types

- Activity type CRUD with JSON persistence
- Archive support
- SF Symbols for activity type icons (replaced emoji with native system icons)

### Project Story ("The Braid")

- Read-only narrative timeline for individual projects
- **The Braid** dual-track timeline: a chronological session spine on top, with one lane per phase beneath (marks positioned by date — honest about non-chronological phases)
- Phase-based chapter grouping
- Pinned `PhaseDetailPanel` on phase hover showing date range, total time, avg mood, milestone count, and recent non-milestone action lines
- Notable Moments cross-highlight phases in the Braid
- Milestone extraction
- Phase lane derivation (`derivePhaseLanes`) + `PhaseLane` model

### UI/UX

- Sidebar with project/activity type management
- Sessions list with filtering (filter bar, toggle, date range)
- Inline session editing throughout
- Theming system (colors, spacing, fonts)
- Dynamic Cmd+Tab visibility: app appears in app switcher only when a window (dashboard, notes modal) is open; invisible when all windows are closed

### Data Integrity

- Phase archiving keeps session history readable
- Phase removal clears references on affected sessions with confirmation
- Session data validation on load
- Legacy CSV migration support

### Bulk Session Editing

- Bulk selection mode entered via double-click on any session row (which also opens the filter bar in bulk edit mode)
- When bulk edit mode is active, the filter bar transforms to show bulk action controls (Project, Phase, Mood) plus Save & Exit / Cancel buttons
- Click-to-select (toggle individual selection) and shift-click range selection across day-grouped sessions
- Visual selection highlighting (accent-coloured outline around selected rows)
- Bulk update saves by iterating over selected sessions and calling `updateSessionFull()` for each
- Phase editing enabled when all selected sessions belong to the same project (or a bulk project has been chosen)
- Mood editing uses the existing 0-10 grid `MoodSelectionPopover`
- On save, the current filtered view is refreshed automatically
- "Bulk Edit" toggle button inside the filter bar
- Bulk edit mode can be exited via Cancel button or Escape key
- Bulk edit dropdowns visually persist the selected value so users know what will be applied

---

## Ongoing Work

### Project Story UI

- **Status**: The Braid overhaul is complete (Aug 2026). Known minor bugs under review.
- **Scope**: Visual polish, layout improvements, edge case handling
- **What works**: The Braid timeline (spine + phase lanes + detail panel), phase lane derivation, milestone extraction, density calculation, Notable Moments cross-highlight

#### Dashboard changes

1. When we finish a session, the Dashboard doesn't update. It should automatically update to show the new session, as well as the Sessions dashboard should update, too.
2. Tooltip change needed. For the Calendar Chart view, Let's change the toolti to say the one line action from that specific session and let's make sure the start and end time is being pulled accurately and not approximated. 

#### Sessions

1. Unable to use Bulk Edit more than once. Once you've made a change or even if you haven't made a change once you've entered bulk edit mode and then exited it, you have to navigate out of the sessions tab to a different tab and then back into the sessions tab to be able to enable bulk edit mode again. I'm not sure why this happens. This happens whether you cancel or save a bulk edit. 

---

## Deferred / Future Considerations

### Testing

- **Priority**: Medium
- **Coverage**: Session CSV parsing + phase data integrity have test coverage
- **Gaps**: Manager-level tests, dashboard/ProjectStory unit tests, UI tests
- **Pattern**: See AGENT.md → Testing section

---

## Change Log

The chronological change history has moved to **[CHANGELOG.md](./CHANGELOG.md)**. This document now focuses on project status, completed features, ongoing work, and priorities.

---

*This file is updated as significant features land, docs change, or priorities shift.*
