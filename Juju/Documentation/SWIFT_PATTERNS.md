---
title: Juju Swift Development Patterns
audience: [developer, AI assistant]
status: current
last_verified: 2026-09-18
---

# Juju Swift Development Patterns

Use this file with [AGENTS.md](AGENTS.md) when writing or reviewing Swift. It contains the reusable rules and patterns that should stay consistent across the codebase.

## Core rules

| Rule | Required behavior |
| --- | --- |
| Project references | Use `projectID`; treat `projectName` as legacy display/compatibility data only |
| Session state | Load once, then use `SessionManager.allSessions` |
| UI state | Keep ViewModels main-actor bound and Views presentation-only |
| Business logic | Keep it in Managers or focused derivation types |
| Persistence | Validate before writing; use the existing file managers |
| Errors | Catch failures and route them through `JujuError` or `ErrorHandler` |
| Cross-component updates | Publish state and post the relevant notification after success |
| Charts | Use `chartOverlay` for hover coordinates |
| Previews | Do not add SwiftUI previews |

## Naming

- Types: `PascalCase` (`SessionManager`, `ProjectStoryViewModel`).
- Methods and variables: descriptive `camelCase`.
- IDs: end with `ID` (`projectID`, `activityTypeID`, `sessionID`).
- Booleans: use `is` or `has` (`isLoading`, `hasError`).
- Constants: group related values under a focused type, such as `Theme.Colors`.

## Threading and concurrency

```swift
@MainActor
final class ExampleViewModel: ObservableObject {
    @Published var items: [String] = []
}
```

- Keep SwiftUI state and view-model mutations on the main actor.
- Use async/await for new asynchronous work.
- Keep file operations behind `SessionFileManager`; it is an actor.
- Use `Task` or an async method for background work, then return to the main actor before mutating UI state.
- Do not introduce blocking file I/O on the main thread. Existing synchronous manager APIs should be used carefully and not expanded as a new pattern.

## State and data flow

```text
View
  -> ViewModel
  -> Manager
  -> Validator / persistence
  -> notification or @Published update
  -> View refresh
```

- Views should not own business rules or directly mutate persistence.
- Managers coordinate lifecycle, validation, storage, and notifications.
- `SessionManager.allSessions` is the shared session cache after `loadAllSessions()`.
- `ProjectsViewModel` and `ProjectStoryViewModel` are main-actor UI/derivation layers for project data.
- `ChartDataPreparer` receives the complete session array and owns chart-specific filtering and aggregation.

## Errors

```swift
do {
    let result = try await operation()
} catch {
    ErrorHandler.shared.handleError(
        error,
        context: "ClassName.methodName",
        severity: .error
    )
    return
}
```

- Use `JujuError` for domain-specific failures.
- Do not use `try!`.
- Do not use `try?` for business logic or file operations. It is acceptable only for explicitly best-effort cleanup where failure is intentionally ignored.
- Include the operation, entity, and useful context in errors.

## Persistence

- Sessions: `SessionManager` -> `SessionCSVManager` -> `SessionFileManager` -> `YYYY-data.csv`.
- Projects: `ProjectManager` -> `projects.json`.
- Activity types: `ActivityTypeManager` -> `activityTypes.json`.
- Legacy session migration: `SessionMigrationManager`.
- Validate project, phase, activity, and date references before persistence.
- Do not bypass notifications after a successful mutation; caches and views depend on them.

## UI and chart patterns

### View composition

- Keep feature Views focused on layout and presentation.
- Put reusable visual styling in `Theme` or shared components.
- Lift shared hover/selection state to the parent and pass values or bindings to children.
- Use `SidebarStateManager` for sidebar presentation state.

### Tooltips and hover

- Reuse `TooltipContainer`, `TooltipRow`, and `TooltipDivider` from `Shared/TooltipViews.swift`.
- Use `.chartOverlay { proxy in ... }` for chart coordinate conversion.
- Use `ChartProxy.value(atX:atY:)`; do not calculate chart coordinates from a sibling `ZStack`.
- Clamp floating tooltips to the available card bounds.
- For the 90-day chart, lift `DayStack?` to `OverviewDashboardView` and show `DaySessionInfoPanel` in the fixed-height Trends container.

### Sparse, idle-safe animation

`JujuAmbience` is the reference pattern:

- One `JujuAmbienceController` owns two asymmetric meshes and the greeting flash.
- Long quiet gaps have no timer and publish no state.
- A 60 Hz timer runs only while a cascade is active, then is invalidated.
- `JujuAmbienceStrike.frame(at:)` derives visual state from elapsed time, which keeps animation logic testable.
- `.onDisappear`, `stop()`, and `deinit` tear down timers.
- Respect `.accessibilityReduceMotion`.

Do not use a continuously firing `TimelineView` or repeating timer for motion that should be idle between events.

## Performance

- Use `SessionManager.allSessions` instead of rereading CSV for every view.
- Use `ProjectStatisticsCache` for expensive project statistics; its TTL is 30 seconds.
- Pass complete session arrays to `ChartDataPreparer` and let it filter internally.
- Keep dashboard derivations linear where possible.
- Use bounded `ScrollView` components when a chart or list can exceed its card height.

## Testing

- Add focused XCTest coverage for parsers, validators, migrations, filters, and derivation functions.
- Prefer a few broad tests over one per behaviour. Assert structure, invariants, and bounds — not tunable constants. A test that fails when you retune a visual value (an envelope, an easing, a spacing) is a change detector, not a bug catcher, and it taxes the iteration it should support. How a visual feature *feels* is verified by looking at it.
- Use small fixtures and `@testable import Juju` for internal types.
- Run the relevant test class while developing, then run the full suite.

```bash
xcodebuild -scheme Juju -destination 'platform=macOS' test
```

Current test files:

- `SessionDataParserTests.swift`
- `PhaseDataIntegrityTests.swift`
- `ProjectStoryDerivationTests.swift`
- `JujuAmbienceTests.swift`
- `SessionRecordFilteringTests.swift`
- `ArraySessionExtensionsTests.swift`

## Antipatterns

1. Using a project name as a key.
2. Reading session files directly from a View or ViewModel.
3. Putting business logic in a View.
4. Blocking the main thread with I/O.
5. Ignoring validation before persistence.
6. Forgetting notifications after a shared-state mutation.
7. Using sibling overlays for chart hover coordinates.
8. Reintroducing SwiftUI previews.
9. Duplicating shared tooltip or theme styling.
10. Adding a new manager when an existing focused component already owns the responsibility.

## Current component references

| Need | Read or use |
| --- | --- |
| Session lifecycle and CSV | `SessionManager`, `SessionCSVManager`, `SessionFileManager`, `SessionDataParser` |
| Migration and integrity | `SessionMigrationManager`, `DataValidator`, `SessionPhaseIntegrity` |
| Projects and phases | `ProjectManager`, `ProjectsViewModel`, `ProjectStatisticsCache` |
| Activity types | `ActivityType`, `ActivityTypeManager`, `ActivityTypesViewModel` |
| Dashboard derivation | `ChartDataPreparer`, `NarrativeEngine` |
| ProjectStory | `ProjectStoryViewModel` |
| Errors | `JujuError`, `ErrorHandler` |
| Sidebar and shortcuts | `SidebarStateManager`, `ShortcutManager`, `IconManager` |

Keep this file about reusable rules. Put system relationships in [ARCHITECTURE.md](ARCHITECTURE.md) and workflow details in [AGENTS.md](AGENTS.md).
