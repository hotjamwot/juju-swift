---
title: Juju Development Guide
audience: [developer, AI assistant]
status: current
last_verified: 2026-09-18
---

# Juju Development Guide

Use this file first when adding a feature, fixing a bug, or changing an existing flow.

## Read order

1. Read this guide for the workflow and non-negotiable rules.
2. Read [ARCHITECTURE.md](ARCHITECTURE.md) when changing models, persistence, managers, or data flow.
3. Read [SWIFT_PATTERNS.md](SWIFT_PATTERNS.md) when writing or reviewing Swift.
4. Read [CHANGELOG.md](CHANGELOG.md) only when you need recent history.

Do not read every document for every task. Follow the links that apply to the change.

## Non-negotiable rules

- Use `projectID` as the canonical project reference. `projectName` is legacy display/compatibility data only.
- Treat `SessionManager.allSessions` as the session source of truth after `loadAllSessions()` has run.
- Keep views presentation-only. Put state in ViewModels and business/persistence logic in Managers.
- Keep UI-bound state and updates on the main actor. Use async/await for new asynchronous work and file I/O.
- Validate data before persistence. Use `DataValidator` and `JujuError` for domain failures.
- Do not use `try!`. Do not use `try?` for business or file operations; it is acceptable only for explicitly best-effort cleanup.
- Post the relevant notification after a successful cross-component state change so caches and views can refresh.
- Use `chartOverlay` for SwiftUI Charts hover detection. Reuse `TooltipContainer`, `TooltipRow`, and `TooltipDivider`.
- Do not add SwiftUI previews. This project intentionally has no `#Preview` or `PreviewProvider` blocks.

## Change workflow

1. Identify the layer: UI, ViewModel, Manager, model, persistence, or tests.
2. Reproduce the behavior or define the expected result.
3. Read the relevant architecture and pattern sections.
4. Make the smallest change at the correct layer.
5. Add or update focused unit tests when changing parsing, validation, migration, derivation, or public behavior.
6. Run the relevant tests, then the full `JujuTests` suite.
7. Update documentation only when the architecture, reusable pattern, or user-facing behavior changes.

## Session work

- Start and end sessions through `SessionManager`.
- Use `SessionRecord` for persisted sessions. Its canonical fields are `id`, `startDate`, `endDate`, `projectID`, optional activity/phase IDs, optional action, `isMilestone`, notes, and optional mood.
- Session CSV files are year-based. The parser reads headers by name, so column order may vary.
- Live session metadata stays in memory until `endSession()`; it is not written midway through a session.
- Phase removal clears affected session `projectPhaseID` values through `SessionManager.clearProjectPhaseForSessions`.

## Dashboard work

- `DashboardRootView` loads the complete session history into `SessionManager` on appearance.
- Dashboard views receive the cached session array and pass it to `ChartDataPreparer`.
- The preparer owns date filtering and aggregation. Do not pre-filter data for rolling 90-day or 360-day trend calculations.
- The 90-day chart lifts `hoveredDay` to `OverviewDashboardView`; `DaySessionInfoPanel` swaps into the fixed-height Trends container.
- Use the shared tooltip components for floating tooltips and lift shared hover state to a parent for cross-highlighting.

## Project and ProjectStory work

- `ProjectManager` owns project JSON persistence and phase operations.
- `ProjectsViewModel` is the main-actor UI state layer for projects.
- Archived projects and phases remain valid for historical sessions but are excluded from active pickers.
- `ProjectStoryViewModel` derives chapters, milestones, density, gaps, and non-contiguous phase lanes from sessions and project data. It is a read-only derivation layer.

## Testing

`JujuTests` is a macOS unit-test target hosted by `Juju.app`; it is not a UI-test target.

Run the full suite:

```bash
xcodebuild -scheme Juju -destination 'platform=macOS' test
```

Run one class:

```bash
xcodebuild -scheme Juju -destination 'platform=macOS' test -only-testing:JujuTests/SessionDataParserTests
```

Current test areas:

- `SessionDataParserTests.swift`: CSV parsing, legacy layouts, and duration handling.
- `PhaseDataIntegrityTests.swift`: phase reference clearing and validation.
- `ProjectStoryDerivationTests.swift`: timeline, density, and phase-lane derivation.
- `JujuAmbienceTests.swift`: ambience topology, walks, and scene output.
- `SessionRecordFilteringTests.swift` and `ArraySessionExtensionsTests.swift`: query and filtering behavior.

Use small fixtures and `@testable import Juju` for internal types. Extend the relevant test file when changing a parser, validator, migration, model, or derivation function.

## Documentation maintenance

- Keep `ARCHITECTURE.md` focused on structure, models, flows, and decisions. Do not duplicate method bodies or large code listings.
- Keep `SWIFT_PATTERNS.md` focused on reusable rules and patterns.
- Keep `CHANGELOG.md` chronological and concise.
- There is no separate roadmap file. Current behavior belongs in code and tests; recent history belongs in the changelog.
