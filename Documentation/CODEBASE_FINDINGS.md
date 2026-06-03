# Codebase Findings — SF Symbol Migration Review

**Purpose**: Observations, optimization opportunities, and code quality notes discovered during the activity type emoji → SF Symbol migration (Jun 2026). These are actionable insights, not a exhaustive audit.

---

## 1. Proliferation of Chart Data Models

**What I found**: There are **8 nearly-identical chart data structs** in `ChartDataModels.swift` that all follow the same pattern:

- `YearlyActivityTypeChartData` — `activityName`, `sfSymbol`, `totalHours`, `percentage`
- `YearlyActivityTypeDataPoint` — same fields
- `MonthlyActivityTypeDataPoint` — same fields
- `YearlyMonthlyActivityDataPoint` — same fields
- `ActivityChartData` — same fields
- `YearlyProjectChartData` — similar but with `color` and `projectName`
- `YearlyProjectDataPoint` — similar
- `ProjectChartData` — similar

**Opportunity**: Most of these could be consolidated into 2-3 generic structs (e.g., `ActivityDistributionItem`, `ProjectDistributionItem`) since the fields are identical. This would reduce the number of model changes needed when schema evolves — as this migration demonstrated.

**Risk**: Low. The structs are value types with no inheritance, so consolidation is straightforward.

---

## 2. Duplicated Emoji Fallback Defaults

**What I found**: The default emoji/SF Symbol values (e.g., `"📁"` for projects, `"📝"` for uncategorized) are hardcoded in **at least 6 separate locations**:

- `ActivityTypeManager.createDefaultActivityTypes()`
- `ActivityTypeManager.getUncategorizedActivityType()`
- `NarrativeEngine.determineTopActivity()`
- `ProjectManager` (project emoji defaults)
- `SessionsRowView.projectEmoji` computed property
- Multiple preview/mock data blocks

**Opportunity**: Define these as static constants on the model types:

```swift
extension ActivityType {
    static let defaultSFSymbol = "doc.plaintext"
}

extension Project {
    static let defaultEmoji = "📁"
}
```

This would prevent drift and make future migrations far easier.

**Risk**: Low. Pure refactoring with no behavioral change.

---

## 3. SelectionItem Protocol Coupling

**What I found**: The `SelectionItem` protocol in `InlineSelectionPopover.swift` was designed to be generic across Projects, Activity Types, and Phases. But the migration revealed a tension: Projects use `emoji` (a String rendered as `Text()`), while Activity Types now use `sfSymbol` (a String rendered as `Image(systemName:)`). The protocol needed a new `displaySFSymbol` property to handle both.

**Observation**: The protocol is doing two jobs — providing display data and determining rendering strategy. A cleaner approach might be to have the protocol return a `View` directly:

```swift
protocol SelectionItem {
    var displayName: String { get }
    var icon: AnyView { get }
    var displayColor: Color? { get }
}
```

Each conforming type could then render itself however it likes. This would avoid the `displayEmoji` / `displaySFSymbol` branching in the rendering code.

**Risk**: Medium. Requires changing all conforming types, but the changes are mechanical.

---

## 4. NarrativeEngine Tuple Anti-Pattern

**What I found**: `NarrativeEngine` uses named tuples extensively for activity/project data:

```swift
let topActivity: (name: String, sfSymbol: String)
let topProject: (name: String, emoji: String)
```

These tuples appear in `PeriodSessionData`, `NarrativeHeadline`, and as return types from private helper methods. They're not `Codable`, not `Hashable` (without custom conformance), and the `Equatable` conformance on `NarrativeHeadline` requires manual field-by-field comparison of tuple properties.

**Opportunity**: Replace with lightweight structs:

```swift
struct ActivitySummary: Equatable {
    let name: String
    let sfSymbol: String
}
```

This would make the code more readable, enable automatic `Equatable` synthesis, and make future schema changes (like adding a `color` field) trivial.

**Risk**: Low. Mechanical refactor with clear type safety benefits.

---

## 5. Session Data Refresh Pattern

**What I found**: `SessionsRowView` uses a triple-layered refresh pattern after data changes:

```swift
// First attempt: immediate refresh
DispatchQueue.main.async { ... }
// Second attempt: after 0.1s
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { ... }
// Third attempt: after 0.3s
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { ... }
```

This is repeated in `updateSessionProject`, `updateSessionPhase`, `updateSessionActivityType`, `updateSessionMood`, `updateSessionNotes`, `updateSessionAction`, and `updateSessionStartDateTime`/`updateSessionEndDateTime` — **8 methods** with nearly identical refresh logic.

**Opportunity**: Extract the refresh logic into a single method (which already exists as `refreshSessionData()` but is only used in some paths). All update handlers should call it. The triple-retry pattern itself could be replaced with a single `NotificationCenter.post(name: .sessionDataDidChange)` that all views observe, rather than relying on timing-based refreshes.

**Risk**: Medium. The current approach works but is fragile. A notification-based approach would be more robust but requires careful testing.

---

## 6. Mock Data Sprawl in Previews

**What I found**: Preview providers across the codebase create their own mock `ActivityType` and `Project` instances with hardcoded emoji values. During this migration, **12 separate preview/mock blocks** needed updating across 7 files.

**Opportunity**: Create shared preview data factories:

```swift
#if DEBUG
extension ActivityType {
    static let previewWriting = ActivityType(id: "writing", name: "Writing", sfSymbol: "pencil")
    static let previewCoding = ActivityType(id: "coding", name: "Coding", sfSymbol: "chevron.left.forwardslash.chevron.right")
}
#endif
```

This would centralize mock data and prevent the kind of drift we saw during this migration.

**Risk**: Low. No production impact.

---

## 7. JSON Schema Migration Gap

**What I found**: The app loads `activityTypes.json` from Application Support and decodes it with `JSONDecoder`. When we renamed `emoji` → `sfSymbol`, the old JSON file would fail to decode (missing `sfSymbol` key). The current code catches this error and falls back to defaults — which works but silently loses any user-customized activity types.

**Opportunity**: Implement explicit schema versioning and migration in the JSON loader:

```swift
struct ActivityTypeV1: Codable {
    let emoji: String
    // ... other fields
}

// Migration path
if let v1 = try? decoder.decode([ActivityTypeV1].self, from: data) {
    let migrated = v1.map { ActivityType(id: $0.id, name: $0.name, sfSymbol: mapEmojiToSFSymbol($0.emoji)) }
    saveActivityTypes(migrated)
    return migrated
}
```

This pattern exists informally (the `migrateActivityTypes` method checks for missing description/archived fields) but isn't used for field renames. Making it more robust would prevent data loss during schema evolution.

**Risk**: Low-Medium. Requires careful testing but prevents silent data loss.

---

## 8. Inconsistent Rendering Patterns

**What I found**: Activity type icons are rendered in at least 4 different ways across the codebase:

1. `Image(systemName: activityType.sfSymbol)` — direct SF Symbol rendering
2. `Text("\(activityType.emoji) \(activityType.name)")` — old concatenated text (now updated)
3. `Text(activity.emoji)` — standalone emoji text (now updated)
4. Inside the `ActivityTypePieSlice.label` computed property, which concatenates into a String

The `ActivityTypePieSlice.label` is particularly problematic because it returns a `String` that includes the icon text — but SF Symbols can't be meaningfully concatenated into strings.

**Opportunity**: Audit all icon rendering points and ensure consistent use of `Image(systemName:)`. For computed properties that return strings (like `label`), either remove the icon from the string or change the return type to a View.

**Risk**: Low. Already partially addressed in this migration.

---

## 9. Project Model Still Uses Emoji

**What I found**: Projects still use `emoji` (String, rendered as `Text()`). This works fine for projects since emoji are native to that use case. However, it means the `SelectionItem` protocol now has two different icon mechanisms (`displayEmoji` for Projects, `displaySFSymbol` for Activity Types).

**Future Consideration**: If Projects ever need SF Symbols too, the protocol would need further changes. Alternatively, if the team decides projects should keep emoji permanently, this is fine as-is — but it's worth documenting the design decision.

---

## Summary

| Finding | Priority | Effort | Impact |
|---------|----------|--------|--------|
| Consolidate chart data models | Medium | Medium | Reduces duplication, simplifies future migrations |
| Static default constants | High | Low | Prevents drift, simplifies migrations |
| Refactor SelectionItem protocol | Low | Medium | Cleaner rendering logic |
| Replace NarrativeEngine tuples | Medium | Low | Better type safety, readability |
| Simplify session refresh pattern | Medium | Medium | Reduces fragility, code duplication |
| Centralize mock data | Low | Low | Easier maintenance |
| JSON schema migration | High | Medium | Prevents silent data loss |
| Audit rendering consistency | Low | Low | Already partially done |

---

*Generated during the activity type SF Symbol migration, June 2026.*