---
title: Juju Architecture
audience: [developer, AI assistant]
status: current
last_verified: 2026-09-18
---

# Juju Architecture

## Purpose

This is the concise architecture reference for Juju. Read it when changing models, persistence, managers, data flow, or feature boundaries.

For contributor workflow, read [AGENTS.md](AGENTS.md). For Swift conventions, read [SWIFT_PATTERNS.md](SWIFT_PATTERNS.md).

## System at a glance

| Concern | Current decision |
| --- | --- |
| Platform | macOS menu-bar app built with SwiftUI |
| Structure | MVVM with feature Views, ViewModels, and Managers |
| Storage | Local CSV and JSON files; no Core Data or cloud sync |
| Session source of truth | `SessionManager.allSessions` after loading |
| UI threading | Main actor for ViewModels and UI-bound state |
| Background work | Prefer async/await; file operations are isolated in `SessionFileManager` |
| Cross-component updates | `@Published` state plus `NotificationCenter` |
| Tests | `JujuTests` macOS unit-test target; no UI-test target |

## Project structure

```text
Juju/
├── App/                  # Lifecycle, window, menu, and shortcut glue
├── Core/
│   ├── Models/           # Business and query models
│   ├── Managers/         # Business logic, validation, persistence, narratives
│   ├── ViewModels/       # Shared UI state and read-only derivation
│   └── Extensions/       # Focused collection, date, and session helpers
├── Features/             # Dashboard, sessions, projects, activity types, notes
├── Shared/               # Theme, tooltips, ambience, reusable extensions
└── Resources/            # Local assets and colors

JujuTests/                # XCTest unit tests
```

## Component map

| Area | Responsibility | Main types |
| --- | --- | --- |
| App | Lifecycle and window/menu integration | `AppDelegate`, `DashboardWindowController`, `ShortcutManager` |
| Sessions | Lifecycle, cached state, CSV persistence, migration | `SessionManager`, `SessionCSVManager`, `SessionFileManager`, `SessionDataParser`, `SessionMigrationManager` |
| Projects | Project/phase CRUD, JSON persistence, statistics | `ProjectManager`, `ProjectStatisticsCache`, `ProjectsViewModel` |
| Activity types | Local CRUD and symbol lookup | `ActivityType`, `ActivityTypeManager`, `ActivityTypesViewModel` |
| Validation | Referential integrity and repair decisions | `DataValidator`, `SessionPhaseIntegrity` |
| Dashboard | Filtering, aggregation, narrative data | `ChartDataPreparer`, `NarrativeEngine`, `NarrativeWeekSummary` |
| ProjectStory | Read-only timeline derivation | `ProjectStoryViewModel`, `PhaseLane`, `Chapter`, `DensityBucket` |
| Shared UI | Visual language and interaction primitives | `Theme`, `TooltipViews`, `JujuAmbience` |
| Errors | Central error context and logging | `JujuError`, `ErrorHandler` |

## Data models

### SessionRecord

A persisted work interval. `projectID` is the canonical reference.

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | `String` | Stable session identifier |
| `startDate` | `Date` | Start timestamp |
| `endDate` | `Date` | End timestamp |
| `projectID` | `String` | Project reference |
| `activityTypeID` | `String?` | Optional activity classification |
| `projectPhaseID` | `String?` | Optional project phase |
| `action` | `String?` | Short achievement or task description |
| `isMilestone` | `Bool` | Marks a significant session |
| `notes` | `String` | Session context |
| `mood` | `Int?` | Optional 0-10 mood rating |

`durationMinutes` is derived from the two dates. `SessionData` is the creation DTO and uses the same date-based fields, with a compatibility initializer for older `startTime`/`endTime` callers.

### Project and Phase

`Project` contains `id`, `name`, `color`, optional `about`, `order`, `emoji`, `archived`, and `phases`. `Phase` contains `id`, `name`, `order`, and `archived`.

Archived projects and phases remain valid for historical sessions. Active pickers show only non-archived values. Removing a phase clears its ID from affected sessions.

### ActivityType

`ActivityType` contains `id`, `name`, `sfSymbol`, `description`, and `archived`. The model uses SF Symbols rather than storing an emoji.

### Query and derived models

- `SessionQuery` expresses date, project, activity, phase, limit, and offset filters.
- `ChartDataPreparer` produces weekly, 90-day, and rolling trend models.
- `NarrativeEngine` produces headlines and rolling breakdowns.
- `ProjectStoryViewModel` produces chapters, milestones, density buckets, and phase lanes.

## Persistence and integrity

### Session files

Sessions live under `~/Library/Application Support/Juju/` in year-based files named `YYYY-data.csv`.

Canonical header:

```text
id,start_date,end_date,project_id,activity_type_id,project_phase_id,action,is_milestone,notes,mood
```

`SessionDataParser` reads columns by header name, so column order can vary. It supports legacy date/time layouts and marks files for rewrite when required. `SessionMigrationManager` moves legacy `data.csv` data into year-based files.

### Project and activity files

Projects and activity types are stored as JSON in the same Application Support directory. `ProjectManager` and `ActivityTypeManager` own their persistence and caches.

### Validation and caching

- `DataValidator` checks required fields, date order, project references, phase ownership, and activity references.
- Archived entities remain valid historical references.
- `ProjectStatisticsCache` caches project duration, last-session date, and current phase for 30 seconds.
- Session changes invalidate dependent cache entries through notifications.

## Data flows

### Session lifecycle

```text
UI/Menu action
  -> SessionManager
  -> DataValidator
  -> SessionCSVManager
  -> SessionFileManager
  -> year-based CSV
  -> .sessionDidEnd
  -> cached UI and statistics refresh
```

Starting a session changes in-memory state only. Live notes, action, mood, activity, and phase remain in `SessionManager` until the session ends. Ending a session validates and persists the complete record, clears live state, and notifies observers.

### Dashboard

1. `DashboardRootView` calls `SessionManager.loadAllSessions()` on appearance.
2. `OverviewDashboardView` passes the complete cached array to `ChartDataPreparer`.
3. The preparer filters and aggregates by the needs of each chart.
4. Rolling 90-day and 360-day trend calculations receive all sessions and filter internally.
5. `NarrativeEngine` generates the current headline and breakdowns.
6. Session, project, and count changes trigger a dashboard refresh.

The 90-day chart lifts `hoveredDay` to `OverviewDashboardView`. `DaySessionInfoPanel` replaces the Trends content inside a fixed-height container, avoiding layout movement.

### Project and phase changes

```text
Feature View
  -> ProjectsViewModel
  -> ProjectManager
  -> DataValidator
  -> projects.json
  -> .projectsDidChange
  -> UI/cache refresh
```

Project deletion migrates affected sessions to another project when possible. Phase removal clears affected `projectPhaseID` values before saving the project.

### ProjectStory

`ProjectStoryViewModel` is a read-only derivation layer. On reload it filters sessions by project, sorts them by date, and derives:

- chapters grouped by phase;
- weekly density and mood;
- milestone sessions;
- non-contiguous phase lanes for the Braid.

It listens for `.sessionDidEnd` and `.projectsDidChange`, then rebuilds its published output.

## Key decisions

1. **Date-based sessions**: `startDate` and `endDate` are the source of truth; legacy CSV formats are migrated during load.
2. **Project IDs**: New code uses UUIDs. Names are display data and must not be used as keys.
3. **Local flat files**: CSV and JSON keep data inspectable and portable.
4. **Rolling trend windows**: The dashboard compares the last 90 days with the yearly average per 90-day period from a rolling 360-day window.
5. **Non-contiguous phase lanes**: A phase lane represents a facet whose sessions may be scattered across a project's timeline.
6. **Live capture**: Active-session metadata is held in memory and written once when the session ends.
7. **Idle-safe ambience**: `JujuAmbience` uses two asymmetric 10-node meshes that overflow their containers into an edge fade, quiet gaps, and a 60 Hz burst only while a cascade is active. Cascades lengthen and dim hop by hop, decelerate on arrival, and end in seeded aftershocks. `frame(at:)` is a pure function of elapsed time; Reduce Motion disables the recurring animation.
8. **Chart coordinates**: Hover detection uses `chartOverlay` and `ChartProxy`; sibling overlays with manual coordinate math are not used.

## Feature boundaries

| Feature | Entry points |
| --- | --- |
| Dashboard | `DashboardRootView`, `OverviewDashboardView`, `ChartDataPreparer` |
| Sessions | `SessionsView`, `SessionsRowView`, `BottomFilterBar`, `SessionManager` |
| Projects | `ProjectsView`, `ProjectsViewModel`, `ProjectManager` |
| ProjectStory | `ProjectStoryContainerView`, `ProjectStoryView`, `ProjectStoryViewModel` |
| Activity types | `ActivityTypeView`, `ActivityTypesViewModel`, `ActivityTypeManager` |
| Notes | `NotesManager`, `NotesViewModel`, `NotesModalView` |
| Sidebar | `SidebarView`, `SidebarEditView`, `SidebarStateManager` |

## Tests

| Area | Test file |
| --- | --- |
| CSV parsing and legacy formats | `SessionDataParserTests.swift` |
| Phase integrity and validation | `PhaseDataIntegrityTests.swift` |
| ProjectStory derivation | `ProjectStoryDerivationTests.swift` |
| Ambience topology and frames | `JujuAmbienceTests.swift` |
| Session filtering and extensions | `SessionRecordFilteringTests.swift`, `ArraySessionExtensionsTests.swift` |

Run:

```bash
xcodebuild -scheme Juju -destination 'platform=macOS' test
```

Keep this file focused on architecture. Put reusable Swift rules in `SWIFT_PATTERNS.md` and change history in `CHANGELOG.md`.
